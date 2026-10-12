import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../core/constants/ble_constants.dart';
import '../models/candidate_model.dart';
import '../models/exam_model.dart';
import '../models/submission_model.dart';
import 'mock_ble_service.dart';

class BlePeripheralService {
  static final BlePeripheralService instance = BlePeripheralService._internal();
  BlePeripheralService._internal();

  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;
  bool _isExamStarted = false;
  ExamModel? _currentExam;
  final List<SubmissionModel> _receivedSubmissions = [];
  final List<CandidateModel> _candidates = [];

  final _submissionsController = StreamController<List<SubmissionModel>>.broadcast();
  final _candidatesController = StreamController<List<CandidateModel>>.broadcast();
  final _examStartBroadcastController = StreamController<bool>.broadcast();

  Stream<List<SubmissionModel>> get submissionsStream => _submissionsController.stream;
  Stream<List<CandidateModel>> get candidatesStream => _candidatesController.stream;
  Stream<bool> get examStartBroadcastStream => _examStartBroadcastController.stream;

  bool get isAdvertising => _isAdvertising;
  bool get isExamStarted => _isExamStarted;
  ExamModel? get currentExam => _currentExam;
  List<SubmissionModel> get receivedSubmissions => List.unmodifiable(_receivedSubmissions);
  List<CandidateModel> get candidates => List.unmodifiable(_candidates);

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
    _isExamStarted = false;
    _receivedSubmissions.clear();
    _candidates.clear();
    _submissionsController.add([]);
    _candidatesController.add([]);

    if (isMock) {
      _isAdvertising = true;
      MockBleService.instance.hostSubmissions.listen((sub) {
        addSubmission(sub);
      });
      MockBleService.instance.hostCandidates.listen((list) {
        _candidates.clear();
        _candidates.addAll(list);
        _candidatesController.add(List.from(_candidates));
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

  /// Phát lệnh đồng loạt bắt đầu làm bài (Master Start Command)
  void broadcastStartExam() {
    _isExamStarted = true;
    _examStartBroadcastController.add(true);
    MockBleService.instance.notifyMasterStart();

    // Cập nhật trạng thái các thí sinh đang chờ sang 'taking' (Đang làm)
    for (int i = 0; i < _candidates.length; i++) {
      if (_candidates[i].status == CandidateStatus.waiting) {
        _candidates[i] = _candidates[i].copyWith(status: CandidateStatus.taking);
      }
    }
    _candidatesController.add(List.from(_candidates));
  }

  /// Thêm hoặc cập nhật thí sinh trong danh sách điểm danh (Roster)
  void addOrUpdateCandidate(CandidateModel candidate) {
    final idx = _candidates.indexWhere((c) => c.studentId == candidate.studentId);
    if (idx >= 0) {
      _candidates[idx] = candidate;
    } else {
      _candidates.add(candidate);
    }
    _candidatesController.add(List.from(_candidates));
  }

  /// Cập nhật tiến độ làm bài (Heartbeat từ thí sinh)
  void updateCandidateProgress(String studentId, int answered, int battery) {
    final idx = _candidates.indexWhere((c) => c.studentId == studentId);
    if (idx >= 0) {
      final old = _candidates[idx];
      _candidates[idx] = old.copyWith(
        answeredCount: answered,
        batteryLevel: battery,
        lastSeen: DateTime.now(),
        status: old.status == CandidateStatus.waiting && _isExamStarted
            ? CandidateStatus.taking
            : old.status,
      );
      _candidatesController.add(List.from(_candidates));
    }
  }

  /// Ghi nhận cảnh báo vi phạm quy chế thời gian thực từ thí sinh
  void recordCandidateViolation(String studentId, int violationCount, String alertMessage) {
    final idx = _candidates.indexWhere((c) => c.studentId == studentId);
    if (idx >= 0) {
      final old = _candidates[idx];
      _candidates[idx] = old.copyWith(
        violationCount: violationCount,
        lastViolationAlert: alertMessage,
        lastSeen: DateTime.now(),
      );
      _candidatesController.add(List.from(_candidates));
    }
  }

  /// Stop Host advertising
  Future<void> stopHosting() async {
    _isAdvertising = false;
    _isExamStarted = false;
    try {
      await _blePeripheral.stop();
    } catch (_) {}
  }

  /// Manually add received submission
  void addSubmission(SubmissionModel submission) {
    _receivedSubmissions.add(submission);
    _submissionsController.add(List.from(_receivedSubmissions));

    // Cập nhật trạng thái thí sinh thành 'submitted'
    final idx = _candidates.indexWhere((c) => c.studentId == submission.studentId);
    if (idx >= 0) {
      _candidates[idx] = _candidates[idx].copyWith(
        status: CandidateStatus.submitted,
        submittedAt: submission.submittedAt,
        receiptHash: submission.receiptHash ?? 'ACK-${submission.studentId}-OK',
      );
      _candidatesController.add(List.from(_candidates));
    }
  }
}
