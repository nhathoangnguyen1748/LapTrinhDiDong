import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:apptracngiem/core/security/aes_encryption_service.dart';
import 'package:apptracngiem/core/security/compression_service.dart';
import 'package:apptracngiem/core/security/chunk_protocol.dart';
import 'package:apptracngiem/core/utils/ble_rssi_helper.dart';
import 'package:apptracngiem/models/exam_model.dart';
import 'package:apptracngiem/models/submission_model.dart';

void main() {
  group('1. AES-256 Encryption & Decryption Tests', () {
    test('Encrypt and decrypt string matches exactly', () {
      const plainText = '{"exam_id":"EXAM_TEST","duration_seconds":1800}';
      final cipherBase64 = AesEncryptionService.encryptString(plainText);
      expect(cipherBase64, isNotEmpty);
      expect(cipherBase64, isNot(equals(plainText)));

      final decrypted = AesEncryptionService.decryptString(cipherBase64);
      expect(decrypted, equals(plainText));
    });

    test('Encrypt and decrypt raw bytes matches exactly', () {
      final plainBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final cipherBytes = AesEncryptionService.encryptBytes(plainBytes);
      expect(cipherBytes, isNot(equals(plainBytes)));

      final decrypted = AesEncryptionService.decryptBytes(cipherBytes);
      expect(decrypted, equals(plainBytes));
    });
  });

  group('2. GZip Compression & CRC32 Integrity Tests', () {
    test('GZip compress and decompress recovers original payload', () {
      final sampleText = 'LocalQuiz BLE Offline Testing ' * 50;
      final rawBytes = Uint8List.fromList(utf8.encode(sampleText));

      final compressed = CompressionService.gzipCompress(rawBytes);
      expect(compressed.length, lessThan(rawBytes.length));

      final decompressed = CompressionService.gzipDecompress(compressed);
      expect(utf8.decode(decompressed), equals(sampleText));
    });

    test('CRC32 checksum changes when data is altered', () {
      final data1 = Uint8List.fromList([10, 20, 30, 40]);
      final data2 = Uint8List.fromList([10, 20, 30, 41]);

      final crc1 = CompressionService.computeCrc32(data1);
      final crc2 = CompressionService.computeCrc32(data2);
      expect(crc1, isNot(equals(crc2)));
    });
  });

  group('3. Chunk Binary Serialization Tests', () {
    test('ChunkPacket toBytes and fromBytes roundtrip', () {
      final payload = Uint8List.fromList([99, 100, 101, 102]);
      final packet = ChunkPacket(
        chunkIndex: 2,
        totalChunks: 10,
        totalCrc32: 3456789,
        payload: payload,
      );

      final bytes = packet.toBytes();
      expect(bytes.length, equals(8 + payload.length));

      final parsed = ChunkPacket.fromBytes(bytes);
      expect(parsed.chunkIndex, equals(2));
      expect(parsed.totalChunks, equals(10));
      expect(parsed.totalCrc32, equals(3456789));
      expect(parsed.payload, equals(payload));
    });
  });

  group('4. End-to-End Chunk Protocol & Reassembly Pipeline', () {
    test('Packetize Exam JSON into chunks and reassemble + decrypt', () {
      final sampleExam = ExamModel.sampleExam();
      final jsonStr = sampleExam.toRawJson();

      // Packetize with a small chunk size (100 bytes) to force multiple chunks
      final packets = ChunkProtocol.packetize(jsonStr, chunkSize: 100);
      expect(packets.length, greaterThan(1));

      final buffer = ReassemblyBuffer();
      expect(buffer.isComplete, isFalse);

      // Simulate receiving chunks (even in reverse order to test robustness)
      for (final packet in packets.reversed) {
        final accepted = buffer.addPacket(packet);
        expect(accepted, isTrue);
      }

      expect(buffer.isComplete, isTrue);
      expect(buffer.progress, equals(1.0));

      final decryptedJson = buffer.assembleAndDecrypt();
      expect(decryptedJson, equals(jsonStr));

      final restoredExam = ExamModel.fromRawJson(decryptedJson);
      expect(restoredExam.examId, equals(sampleExam.examId));
      expect(restoredExam.questions.length, equals(sampleExam.questions.length));
    });

    test('Corrupted chunk triggers CRC32 IntegrityException', () {
      final sampleExam = ExamModel.sampleExam();
      final jsonStr = sampleExam.toRawJson();
      final packets = ChunkProtocol.packetize(jsonStr, chunkSize: 100);

      final buffer = ReassemblyBuffer();
      for (int i = 0; i < packets.length; i++) {
        var p = packets[i];
        if (i == 0) {
          // Corrupt first packet payload
          final corruptedPayload = Uint8List.fromList(p.payload);
          corruptedPayload[0] = (corruptedPayload[0] + 1) % 256;
          p = ChunkPacket(
            chunkIndex: p.chunkIndex,
            totalChunks: p.totalChunks,
            totalCrc32: p.totalCrc32,
            payload: corruptedPayload,
          );
        }
        buffer.addPacket(p);
      }

      expect(
        () => buffer.assembleAndDecrypt(),
        throwsA(isA<IntegrityException>()),
      );
    });
  });

  group('5. RSSI Geofencing & Proximity Tests', () {
    test('RSSI status classification corresponds to thresholds', () {
      expect(BleRssiHelper.getStatus(-60), equals(RssiStatus.optimal));
      expect(BleRssiHelper.getStatus(-75), equals(RssiStatus.optimal));
      expect(BleRssiHelper.getStatus(-76), equals(RssiStatus.warning));
      expect(BleRssiHelper.getStatus(-85), equals(RssiStatus.warning));
      expect(BleRssiHelper.getStatus(-86), equals(RssiStatus.critical));
      expect(BleRssiHelper.getStatus(-95), equals(RssiStatus.critical));
      expect(BleRssiHelper.getStatus(null), equals(RssiStatus.disconnected));
    });

    test('Distance estimation scales with RSSI degradation', () {
      final d1 = BleRssiHelper.estimateDistance(-60); // Strong
      final d2 = BleRssiHelper.estimateDistance(-80); // Weaker
      expect(d2, greaterThan(d1));
    });
  });

  group('6. Submission Model Serialization Tests', () {
    test('Submission model serializes and deserializes accurately', () {
      final sub = SubmissionModel(
        examId: 'EXAM_TEST_1',
        studentId: 'TS-001',
        studentName: 'Lê Văn B',
        answers: {1: 'A', 2: 'C'},
        submittedAt: DateTime.parse('2026-09-22 10:00:00'),
        timeTakenSeconds: 650,
        score: 2,
        totalQuestions: 2,
        violationCount: 0,
      );

      final rawJson = sub.toRawJson();
      final parsed = SubmissionModel.fromRawJson(rawJson);

      expect(parsed.examId, equals('EXAM_TEST_1'));
      expect(parsed.studentName, equals('Lê Văn B'));
      expect(parsed.answers[1], equals('A'));
      expect(parsed.answers[2], equals('C'));
      expect(parsed.score, equals(2));
    });
  });
}
