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
  Timer? _rssiHeartbeatTimer;

  final ReassemblyBuffer _reassemblyBuffer = ReassemblyBuffer();
  final _roomsController = StreamController<List<DiscoveredExamRoom>>.broadcast();
  final _rssiController = StreamController<int>.broadcast();
  final _downloadProgressController = StreamController<double>.broadcast();
  final _completedExamController = StreamController<ExamModel>.broadcast();

  Stream<List<DiscoveredExamRoom>> get roomsStream => _roomsController.stream;
  Stream<int> get rssiStream => _rssiController.stream;
  Stream<double> get downloadProgressStream => _downloadProgressController.stream;
  Stream<ExamModel> get completedExamStream => _completedExamController.stream;

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

      return true;
    }

    try {
      final device = room.device;
      if (device == null) return false;

      _connectedDevice = device;
      await device.connect(timeout: const Duration(seconds: 12));

      // Request MTU negotiation to 512 bytes
      try {
        await device.requestMtu(BleConstants.requestedMtu);
        debugPrint('[BleCentral] MTU requested: ${BleConstants.requestedMtu}');
      } catch (e) {
        debugPrint('[BleCentral] MTU request error (normal on iOS): $e');
      }

      // Discover GATT services
      final services = await device.discoverServices();
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase();
            if (cUuid == BleConstants.charExamDataUuid.toLowerCase()) {
              _examDataChar = c;
            } else if (cUuid == BleConstants.charSubmitResultUuid.toLowerCase()) {
              _submitResultChar = c;
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
