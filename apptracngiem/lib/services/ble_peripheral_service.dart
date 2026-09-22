import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../core/constants/ble_constants.dart';
import '../models/exam_model.dart';
import '../models/submission_model.dart';
import 'mock_ble_service.dart';

class BlePeripheralService {
  static final BlePeripheralService instance = BlePeripheralService._internal();
  BlePeripheralService._internal();

  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;
  ExamModel? _currentExam;
  final List<SubmissionModel> _receivedSubmissions = [];

  final _submissionsController = StreamController<List<SubmissionModel>>.broadcast();
  Stream<List<SubmissionModel>> get submissionsStream => _submissionsController.stream;

  bool get isAdvertising => _isAdvertising;
  ExamModel? get currentExam => _currentExam;
  List<SubmissionModel> get receivedSubmissions => List.unmodifiable(_receivedSubmissions);

  /// Check if device hardware supports BLE Advertising / Peripheral role
  Future<bool> isSupported() async {
    try {
      return await _blePeripheral.isSupported;
    } catch (e) {
      debugPrint('[BlePeripheral] isSupported error: $e');
      return false;
    }
  }

  /// Start Host mode advertising with GATT Service
  Future<bool> startHosting(ExamModel exam, {bool isMock = false}) async {
    _currentExam = exam;
    _receivedSubmissions.clear();
    _submissionsController.add([]);

    if (isMock) {
      _isAdvertising = true;
      MockBleService.instance.hostSubmissions.listen((sub) {
        _receivedSubmissions.add(sub);
        _submissionsController.add(List.from(_receivedSubmissions));
      });
      return true;
    }

    try {
      final supported = await _blePeripheral.isSupported;
      if (!supported) {
        debugPrint('[BlePeripheral] Hardware does not support BLE Peripheral mode');
        return false;
      }

      final advertiseData = AdvertiseData(
        serviceUuid: BleConstants.serviceUuid,
        localName: 'Phòng Thi: ${exam.title}',
        includeDeviceName: true,
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: true,
        timeout: 0,
      );

      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      _isAdvertising = true;
      debugPrint('[BlePeripheral] Started advertising exam: ${exam.title}');
      return true;
    } catch (e) {
      debugPrint('[BlePeripheral] Start advertising error: $e');
      return false;
    }
  }

  /// Stop Host advertising
  Future<void> stopHosting() async {
    _isAdvertising = false;
    try {
      await _blePeripheral.stop();
    } catch (_) {}
  }

  /// Manually add received submission (for testing/mocking)
  void addSubmission(SubmissionModel submission) {
    _receivedSubmissions.add(submission);
    _submissionsController.add(List.from(_receivedSubmissions));
  }
}
