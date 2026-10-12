import 'dart:async';
import '../core/constants/ble_constants.dart';
import '../models/exam_model.dart';
import '../models/submission_model.dart';
import '../models/ble_packet_model.dart';
import '../core/security/chunk_protocol.dart';

import '../models/candidate_model.dart';

class MockDiscoveredDevice {
  final String remoteId;
  final String platformName;
  final int rssi;

  const MockDiscoveredDevice({
    required this.remoteId,
    required this.platformName,
    required this.rssi,
  });
}

class MockBleService {
  static final MockBleService instance = MockBleService._internal();
  MockBleService._internal();

  bool _isScanning = false;
  bool _isConnected = false;
  int _currentRssi = -64; // Default strong signal
  Timer? _rssiHeartbeatTimer;

  final _scanResultsController = StreamController<List<MockDiscoveredDevice>>.broadcast();
  final _rssiController = StreamController<int>.broadcast();
  final _chunkStreamController = StreamController<ChunkPacket>.broadcast();
  final _hostSubmissionsController = StreamController<SubmissionModel>.broadcast();
  final _hostCandidatesController = StreamController<List<CandidateModel>>.broadcast();
  final _masterStartController = StreamController<bool>.broadcast();

  final List<CandidateModel> _mockCandidates = [];

  Stream<List<MockDiscoveredDevice>> get scanResults => _scanResultsController.stream;
  Stream<int> get rssiStream => _rssiController.stream;
  Stream<ChunkPacket> get chunkStream => _chunkStreamController.stream;
  Stream<SubmissionModel> get hostSubmissions => _hostSubmissionsController.stream;
  Stream<List<CandidateModel>> get hostCandidates => _hostCandidatesController.stream;
  Stream<bool> get masterStartStream => _masterStartController.stream;

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  int get currentRssi => _currentRssi;

  final List<MockDiscoveredDevice> _mockRooms = [
    const MockDiscoveredDevice(
      remoteId: 'BLE:EXAM:ROOM:A102',
      platformName: 'Phòng Thi A-102 (Mạng Máy Tính)',
      rssi: -62,
    ),
    const MockDiscoveredDevice(
      remoteId: 'BLE:EXAM:ROOM:B205',
      platformName: 'Phòng Thi B-205 (IoT & Di Động)',
      rssi: -78,
    ),
  ];

  /// Start mock scanning
  Future<void> startScan() async {
    _isScanning = true;
    _scanResultsController.add([]);
    await Future.delayed(const Duration(milliseconds: 600));
    _scanResultsController.add([_mockRooms[0]]);
    await Future.delayed(const Duration(milliseconds: 700));
    _scanResultsController.add(_mockRooms);
  }

  /// Stop mock scanning
  Future<void> stopScan() async {
    _isScanning = false;
  }

  /// Connect to mock device
  Future<bool> connect(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _isConnected = true;
    _currentRssi = -64;
    _rssiController.add(_currentRssi);

    // Start RSSI heartbeat
    _startRssiHeartbeat();
    return true;
  }

  /// Disconnect
  Future<void> disconnect() async {
    _isConnected = false;
    _rssiHeartbeatTimer?.cancel();
    _rssiHeartbeatTimer = null;
  }

  /// Set simulated RSSI directly (for geofencing UI testing)
  void setSimulatedRssi(int rssi) {
    _currentRssi = rssi;
    _rssiController.add(_currentRssi);
  }

  /// Start periodic heartbeat RSSI emitting
  void _startRssiHeartbeat() {
    _rssiHeartbeatTimer?.cancel();
    _rssiHeartbeatTimer = Timer.periodic(
      Duration(seconds: BleConstants.rssiHeartbeatIntervalSeconds),
      (_) {
        if (_isConnected) {
          // Slight natural jitter of +/- 2 dBm
          final jitter = (DateTime.now().millisecond % 5) - 2;
          final updatedRssi = (_currentRssi + jitter).clamp(-100, -40);
          _rssiController.add(updatedRssi);
        }
      },
    );
  }

  /// Stream chunks for a given exam
  Future<void> streamExamChunks(ExamModel exam) async {
    final jsonStr = exam.toRawJson();
    final packets = ChunkProtocol.packetize(jsonStr, chunkSize: 200);

    for (int i = 0; i < packets.length; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      _chunkStreamController.add(packets[i]);
    }
  }

  /// Submit result to mock host
  Future<BlePacketModel> submitExam(SubmissionModel submission) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    _hostSubmissionsController.add(submission);

    // Update mock candidate status to submitted
    final idx = _mockCandidates.indexWhere((c) => c.studentId == submission.studentId);
    if (idx >= 0) {
      _mockCandidates[idx] = _mockCandidates[idx].copyWith(
        status: CandidateStatus.submitted,
        submittedAt: submission.submittedAt,
        receiptHash: 'ACK-${submission.studentId}-OK',
      );
      _hostCandidatesController.add(List.from(_mockCandidates));
    }

    return BlePacketModel.ack(
      examId: submission.examId,
      studentId: submission.studentId,
      isSuccess: true,
      message: 'Giám thị đã nhận thành công bài thi của ${submission.studentName}',
    );
  }

  /// Notify all mock clients that Master Proctor pressed "Start Exam"
  void notifyMasterStart() {
    _masterStartController.add(true);
    for (int i = 0; i < _mockCandidates.length; i++) {
      if (_mockCandidates[i].status == CandidateStatus.waiting) {
        _mockCandidates[i] = _mockCandidates[i].copyWith(status: CandidateStatus.taking);
      }
    }
    _hostCandidatesController.add(List.from(_mockCandidates));
  }

  /// Simulate incoming candidate joining the room
  void simulateIncomingCandidate({
    required String studentId,
    required String studentName,
    String classroom = 'CNTT-K18A',
    String deviceName = 'Galaxy S23',
    int totalQuestions = 20,
  }) {
    final candidate = CandidateModel(
      studentId: studentId,
      studentName: studentName,
      classroom: classroom,
      deviceName: deviceName,
      status: CandidateStatus.waiting,
      answeredCount: 0,
      totalQuestions: totalQuestions,
      batteryLevel: 92,
      violationCount: 0,
      lastSeen: DateTime.now(),
    );

    _mockCandidates.removeWhere((c) => c.studentId == studentId);
    _mockCandidates.add(candidate);
    _hostCandidatesController.add(List.from(_mockCandidates));
  }

  /// Simulate candidate progress update
  void simulateCandidateProgress(String studentId, int answered) {
    final idx = _mockCandidates.indexWhere((c) => c.studentId == studentId);
    if (idx >= 0) {
      _mockCandidates[idx] = _mockCandidates[idx].copyWith(
        answeredCount: answered,
        status: CandidateStatus.taking,
        lastSeen: DateTime.now(),
      );
      _hostCandidatesController.add(List.from(_mockCandidates));
    }
  }

  /// Simulate candidate violation event
  void simulateCandidateViolation(String studentId, String alert) {
    final idx = _mockCandidates.indexWhere((c) => c.studentId == studentId);
    if (idx >= 0) {
      final old = _mockCandidates[idx];
      _mockCandidates[idx] = old.copyWith(
        violationCount: old.violationCount + 1,
        lastViolationAlert: alert,
        lastSeen: DateTime.now(),
      );
      _hostCandidatesController.add(List.from(_mockCandidates));
    }
  }
}
