import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/constants/ble_constants.dart';
import '../core/security/aes_encryption_service.dart';
import '../core/security/chunk_protocol.dart';
import '../models/exam_model.dart';
import '../models/submission_model.dart';
import '../models/ble_packet_model.dart';
import 'mock_ble_service.dart';

class DiscoveredExamRoom {
  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice? device;
  final bool isMock;

  const DiscoveredExamRoom({
    required this.id,
    required this.name,
    required this.rssi,
    this.device,
    this.isMock = false,
  });
}

class BleCentralService {
  static final BleCentralService instance = BleCentralService._internal();
  BleCentralService._internal();

  bool isMockMode = false;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _examDataChar;
  BluetoothCharacteristic? _submitResultChar;
  BluetoothCharacteristic? _candidateControlChar;
  Timer? _rssiHeartbeatTimer;

  final ReassemblyBuffer _reassemblyBuffer = ReassemblyBuffer();
  final _roomsController = StreamController<List<DiscoveredExamRoom>>.broadcast();
  final _rssiController = StreamController<int>.broadcast();
  final _downloadProgressController = StreamController<double>.broadcast();
  final _completedExamController = StreamController<ExamModel>.broadcast();
  final _masterStartController = StreamController<bool>.broadcast();
  final _forceSubmitController = StreamController<bool>.broadcast();
  final _autoSubmitPolicyController = StreamController<bool>.broadcast();

  Stream<List<DiscoveredExamRoom>> get roomsStream => _roomsController.stream;
  Stream<int> get rssiStream => _rssiController.stream;
  Stream<double> get downloadProgressStream => _downloadProgressController.stream;
  Stream<ExamModel> get completedExamStream => _completedExamController.stream;
  Stream<bool> get masterStartStream => _masterStartController.stream;
  Stream<bool> get forceSubmitStream => _forceSubmitController.stream;
  Stream<bool> get autoSubmitPolicyStream => _autoSubmitPolicyController.stream;

  bool get isConnected => isMockMode
      ? MockBleService.instance.isConnected
      : (_connectedDevice != null && _connectedDevice!.isConnected);

  ReassemblyBuffer get reassemblyBuffer => _reassemblyBuffer;

  /// Start scanning for exam rooms broadcasting SERVICE_UUID
  Future<void> startScan({bool useMock = false}) async {
    isMockMode = useMock;
    _roomsController.add([]);

    if (isMockMode) {
      MockBleService.instance.scanResults.listen((mockList) {
        final rooms = mockList.map((m) {
          return DiscoveredExamRoom(
            id: m.remoteId,
            name: m.platformName,
            rssi: m.rssi,
            isMock: true,
          );
        }).toList();
        _roomsController.add(rooms);
      });
      await MockBleService.instance.startScan();
      return;
    }

    try {
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('[BleCentral] BLE not supported on this device');
        return;
      }

      // Check Bluetooth adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('[BleCentral] Bluetooth is not turned on: $adapterState');
        return;
      }

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 15),
      );

      FlutterBluePlus.scanResults.listen((results) {
        final rooms = <DiscoveredExamRoom>[];
        for (final r in results) {
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : (r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : 'Phòng thi BLE (${r.device.remoteId.str.substring(0, 5)})');

          rooms.add(DiscoveredExamRoom(
            id: r.device.remoteId.str,
            name: name,
            rssi: r.rssi,
            device: r.device,
            isMock: false,
          ));
        }
        _roomsController.add(rooms);
      });
    } catch (e) {
      debugPrint('[BleCentral] Error during scan: $e');
    }
  }

  /// Stop scan
  Future<void> stopScan() async {
    if (isMockMode) {
      await MockBleService.instance.stopScan();
    } else {
      await FlutterBluePlus.stopScan();
    }
  }

  /// Connect to room, negotiate MTU, discover characteristics, and start RSSI heartbeat
  Future<bool> connectToRoom(DiscoveredExamRoom room) async {
    _reassemblyBuffer.reset();
    _downloadProgressController.add(0.0);

    if (room.isMock || isMockMode) {
      isMockMode = true;
      final connected = await MockBleService.instance.connect(room.id);
      if (!connected) return false;

      MockBleService.instance.rssiStream.listen((rssi) {
        _rssiController.add(rssi);
      });

      MockBleService.instance.chunkStream.listen((chunk) {
        _handleChunkReceived(chunk);
      });

      MockBleService.instance.masterStartStream.listen((started) {
        _masterStartController.add(started);
      });

      MockBleService.instance.forceSubmitStream.listen((force) {
        _forceSubmitController.add(force);
      });

      return true;
    }

    try {
      final device = room.device;
      if (device == null) return false;

      _connectedDevice = device;
      if (!device.isConnected) {
        await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      }

      await Future.delayed(const Duration(milliseconds: 300));

      // Request MTU negotiation to 512 bytes
      try {
        await device.requestMtu(BleConstants.requestedMtu);
        debugPrint('[BleCentral] MTU requested: ${BleConstants.requestedMtu}');
      } catch (e) {
        debugPrint('[BleCentral] MTU request error (normal on iOS): $e');
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Discover GATT services
      final services = await device.discoverServices();
      for (final s in services) {
        final sUuid = s.uuid.toString().toLowerCase();
        if (sUuid.contains('fef0')) {
          for (final c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase();
            if (cUuid.contains('fef1')) {
              _examDataChar = c;
            } else if (cUuid.contains('fef2')) {
              _submitResultChar = c;
            } else if (cUuid.contains('fef3')) {
              _candidateControlChar = c;
            }
          }
        }
      }

      if (_examDataChar != null) {
        // Subscribe to Notifications for Exam Chunks
        await _examDataChar!.setNotifyValue(true);
        _examDataChar!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            try {
              final packet = ChunkPacket.fromBytes(Uint8List.fromList(value));
              _handleChunkReceived(packet);
            } catch (e) {
              debugPrint('[BleCentral] Error parsing chunk packet: $e');
            }
          }
        });
      }

      if (_candidateControlChar != null) {
        await _candidateControlChar!.setNotifyValue(true);
        _candidateControlChar!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            if (value[0] == 0x01) {
              _masterStartController.add(true);
            } else if (value[0] == 0x02) {
              _forceSubmitController.add(true);
            } else if (value[0] == 0x03 && value.length > 1) {
              _autoSubmitPolicyController.add(value[1] == 0x01);
            }
          }
        });
      }

      // Start periodic RSSI heartbeat
      _startRssiHeartbeat();

      return true;
    } catch (e) {
      debugPrint('[BleCentral] Connect error: $e');
      return false;
    }
  }

  void _handleChunkReceived(ChunkPacket packet) {
    final accepted = _reassemblyBuffer.addPacket(packet);
    if (accepted) {
      _downloadProgressController.add(_reassemblyBuffer.progress);
      debugPrint(
        '[BleCentral] Received chunk ${packet.chunkIndex + 1}/${packet.totalChunks} '
        '(${( _reassemblyBuffer.progress * 100 ).toStringAsFixed(1)}%)',
      );

      if (_reassemblyBuffer.isComplete) {
        try {
          final decryptedJson = _reassemblyBuffer.assembleAndDecrypt();
          final exam = ExamModel.fromRawJson(decryptedJson);
          debugPrint('[BleCentral] Exam reassembled and decrypted successfully: ${exam.title}');
          _completedExamController.add(exam);
        } catch (e) {
          debugPrint('[BleCentral] Error assembling exam: $e');
        }
      }
    }
  }

  void _startRssiHeartbeat() {
    _rssiHeartbeatTimer?.cancel();
    _rssiHeartbeatTimer = Timer.periodic(
      Duration(seconds: BleConstants.rssiHeartbeatIntervalSeconds),
      (_) async {
        if (_connectedDevice != null && _connectedDevice!.isConnected) {
          try {
            final rssi = await _connectedDevice!.readRssi();
            _rssiController.add(rssi);
          } catch (e) {
            debugPrint('[BleCentral] Read RSSI error: $e');
          }
        }
      },
    );
  }

  /// Submit completed exam to Host via CHAR_SUBMIT_RESULT
  Future<BlePacketModel> submitExam(SubmissionModel submission) async {
    if (isMockMode) {
      return await MockBleService.instance.submitExam(submission);
    }

    if (_submitResultChar == null) {
      throw Exception('Submit characteristic not available on connected BLE device');
    }

    final rawJson = submission.toRawJson();
    final encryptedJson = AesEncryptionService.encryptString(rawJson);
    final bytes = utf8.encode(encryptedJson);

    // Write with response to confirm delivery
    await _submitResultChar!.write(bytes, withoutResponse: false);

    return BlePacketModel.ack(
      examId: submission.examId,
      studentId: submission.studentId,
      isSuccess: true,
      message: 'Gửi bài thi thành công qua BLE Characteristic',
    );
  }

  /// Send join handshake request to Proctor Host
  Future<bool> joinExamRoom({
    required String studentId,
    required String studentName,
    required String classroom,
    required String roomPin,
    int totalQuestions = 20,
  }) async {
    if (isMockMode) {
      MockBleService.instance.simulateIncomingCandidate(
        studentId: studentId,
        studentName: studentName,
        classroom: classroom,
        totalQuestions: totalQuestions,
      );
      return true;
    }

    if (_candidateControlChar != null) {
      try {
        final payload = jsonEncode({
          'type': 'join',
          'studentId': studentId,
          'studentName': studentName,
          'classroom': classroom,
          'roomPin': roomPin,
          'totalQuestions': totalQuestions,
        });
        await _candidateControlChar!.write(utf8.encode(payload), withoutResponse: true);
        return true;
      } catch (e) {
        debugPrint('[BleCentral] joinExamRoom error: $e');
      }
    }
    return true;
  }

  /// Send candidate progress update to Host (Heartbeat)
  void sendCandidateProgress({
    required String studentId,
    required int answeredCount,
    int batteryLevel = 90,
  }) {
    if (isMockMode) {
      MockBleService.instance.simulateCandidateProgress(studentId, answeredCount);
      return;
    }
    if (_candidateControlChar != null) {
      try {
        final payload = jsonEncode({
          'type': 'progress',
          'studentId': studentId,
          'answeredCount': answeredCount,
          'battery': batteryLevel,
        });
        _candidateControlChar!.write(utf8.encode(payload), withoutResponse: true);
      } catch (_) {}
    }
  }

  /// Send anti-cheat violation alert to Host in realtime
  void sendCandidateViolation({
    required String studentId,
    required int violationCount,
    required String alertMessage,
  }) {
    if (isMockMode) {
      MockBleService.instance.simulateCandidateViolation(studentId, alertMessage);
      return;
    }
    if (_candidateControlChar != null) {
      try {
        final payload = jsonEncode({
          'type': 'violation',
          'studentId': studentId,
          'violationCount': violationCount,
          'message': alertMessage,
        });
        _candidateControlChar!.write(utf8.encode(payload), withoutResponse: true);
      } catch (_) {}
    }
  }

  /// Disconnect
  Future<void> disconnect() async {
    _rssiHeartbeatTimer?.cancel();
    _rssiHeartbeatTimer = null;

    if (isMockMode) {
      await MockBleService.instance.disconnect();
    } else if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }
  }
}
