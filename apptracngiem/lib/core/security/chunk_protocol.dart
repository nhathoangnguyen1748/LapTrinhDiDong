import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../constants/ble_constants.dart';
import 'aes_encryption_service.dart';
import 'compression_service.dart';

/// Representation of a single BLE chunk packet
class ChunkPacket {
  final int chunkIndex;
  final int totalChunks;
  final int totalCrc32;
  final Uint8List payload;

  const ChunkPacket({
    required this.chunkIndex,
    required this.totalChunks,
    required this.totalCrc32,
    required this.payload,
  });

  /// Binary format:
  /// [0..1] uint16: chunkIndex
  /// [2..3] uint16: totalChunks
  /// [4..7] uint32: totalCrc32
  /// [8..N] payload bytes
  Uint8List toBytes() {
    final byteData = ByteData(8 + payload.length);
    byteData.setUint16(0, chunkIndex, Endian.big);
    byteData.setUint16(2, totalChunks, Endian.big);
    byteData.setUint32(4, totalCrc32, Endian.big);

    final result = byteData.buffer.asUint8List();
    result.setRange(8, 8 + payload.length, payload);
    return result;
  }

  factory ChunkPacket.fromBytes(Uint8List data) {
    if (data.length < 8) {
      throw FormatException('Packet too short for BLE header: ${data.length} bytes');
    }
    final byteData = ByteData.sublistView(data);
    final chunkIndex = byteData.getUint16(0, Endian.big);
    final totalChunks = byteData.getUint16(2, Endian.big);
    final totalCrc32 = byteData.getUint32(4, Endian.big);
    final payload = Uint8List.fromList(data.sublist(8));

    return ChunkPacket(
      chunkIndex: chunkIndex,
      totalChunks: totalChunks,
      totalCrc32: totalCrc32,
      payload: payload,
    );
  }
}

/// Helper for chunking and reassembly with GZip compression and AES-256 encryption
class ChunkProtocol {
  /// Packetize a JSON string or raw bytes:
  /// 1. GZip compress
  /// 2. AES-256 encrypt
  /// 3. Compute CRC32
  /// 4. Split into chunks
  static List<ChunkPacket> packetize(
    String jsonString, {
    int chunkSize = BleConstants.defaultChunkPayloadSize,
    String keyString = BleConstants.defaultExamSecretKey,
    String ivString = BleConstants.defaultExamIv,
  }) {
    final rawBytes = Uint8List.fromList(utf8.encode(jsonString));
    final compressedBytes = CompressionService.gzipCompress(rawBytes);
    final encryptedBytes = AesEncryptionService.encryptBytes(
      compressedBytes,
      keyString: keyString,
      ivString: ivString,
    );

    final crc32 = CompressionService.computeCrc32(encryptedBytes);
    final totalChunks = (encryptedBytes.length / chunkSize).ceil();
    final packets = <ChunkPacket>[];

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < encryptedBytes.length)
          ? start + chunkSize
          : encryptedBytes.length;
      final chunkPayload = Uint8List.fromList(encryptedBytes.sublist(start, end));

      packets.add(ChunkPacket(
        chunkIndex: i,
        totalChunks: totalChunks,
        totalCrc32: crc32,
        payload: chunkPayload,
      ));
    }

    return packets;
  }
}

/// Buffer for reassembling chunks at the Client side
class ReassemblyBuffer {
  final Map<int, Uint8List> _receivedChunks = {};
  int? _totalChunks;
  int? _expectedCrc32;

  int get receivedCount => _receivedChunks.length;
  int get totalCount => _totalChunks ?? 0;
  double get progress => (_totalChunks != null && _totalChunks! > 0)
      ? (_receivedChunks.length / _totalChunks!).clamp(0.0, 1.0)
      : 0.0;
  bool get isComplete =>
      _totalChunks != null && _receivedChunks.length == _totalChunks;

  void reset() {
    _receivedChunks.clear();
    _totalChunks = null;
    _expectedCrc32 = null;
  }

  /// Add received chunk packet. Returns true if packet was accepted.
  bool addPacket(ChunkPacket packet) {
    if (_totalChunks != null && packet.totalChunks != _totalChunks) {
      debugPrint('[Reassembly] Mismatched totalChunks in stream');
      return false;
    }

    _totalChunks = packet.totalChunks;
    _expectedCrc32 = packet.totalCrc32;
    _receivedChunks[packet.chunkIndex] = packet.payload;
    return true;
  }

  /// Assemble, verify CRC32, decrypt AES-256, and decompress GZip
  String assembleAndDecrypt({
    String keyString = BleConstants.defaultExamSecretKey,
    String ivString = BleConstants.defaultExamIv,
  }) {
    if (!isComplete) {
      throw StateError(
        'Cannot assemble incomplete buffer ($receivedCount / $totalCount chunks)',
      );
    }

    // 1. Rebuild full encrypted bytes in sequential order
    final builder = BytesBuilder();
    for (int i = 0; i < _totalChunks!; i++) {
      final chunk = _receivedChunks[i];
      if (chunk == null) {
        throw StateError('Missing chunk index $i during reassembly');
      }
      builder.add(chunk);
    }
    final fullEncryptedBytes = builder.toBytes();

    // 2. Verify CRC32
    final computedCrc32 = CompressionService.computeCrc32(fullEncryptedBytes);
    if (computedCrc32 != _expectedCrc32) {
      throw IntegrityException(
        'CRC32 checksum mismatch! Expected $_expectedCrc32, got $computedCrc32',
      );
    }

    // 3. Decrypt AES-256
    final compressedBytes = AesEncryptionService.decryptBytes(
      fullEncryptedBytes,
      keyString: keyString,
      ivString: ivString,
    );

    // 4. Decompress GZip
    final rawBytes = CompressionService.gzipDecompress(compressedBytes);
    return utf8.decode(rawBytes);
  }
}

class IntegrityException implements Exception {
  final String message;
  IntegrityException(this.message);
  @override
  String toString() => 'IntegrityException: $message';
}
