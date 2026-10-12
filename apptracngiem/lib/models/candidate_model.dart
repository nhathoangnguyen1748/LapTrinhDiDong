import 'dart:convert';

enum CandidateStatus {
  waiting,   // Chờ thi (vừa vào phòng)
  taking,    // Đang làm bài
  submitted, // Đã nộp bài
}

class CandidateModel {
  final String studentId;
  final String studentName;
  final String classroom;
  final String deviceName;
  final CandidateStatus status;
  final int answeredCount;
  final int totalQuestions;
  final int batteryLevel; // 0 - 100%
  final int violationCount;
  final DateTime lastSeen;
  final DateTime? submittedAt;
  final String? receiptHash;
  final String? lastViolationAlert;

  const CandidateModel({
    required this.studentId,
    required this.studentName,
    this.classroom = 'CNTT-K18A',
    this.deviceName = 'Điện thoại di động',
    this.status = CandidateStatus.waiting,
    this.answeredCount = 0,
    this.totalQuestions = 0,
    this.batteryLevel = 100,
    this.violationCount = 0,
    required this.lastSeen,
    this.submittedAt,
    this.receiptHash,
    this.lastViolationAlert,
  });

  CandidateModel copyWith({
    String? studentId,
    String? studentName,
    String? classroom,
    String? deviceName,
    CandidateStatus? status,
    int? answeredCount,
    int? totalQuestions,
    int? batteryLevel,
    int? violationCount,
    DateTime? lastSeen,
    DateTime? submittedAt,
    String? receiptHash,
    String? lastViolationAlert,
  }) {
    return CandidateModel(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      classroom: classroom ?? this.classroom,
      deviceName: deviceName ?? this.deviceName,
      status: status ?? this.status,
      answeredCount: answeredCount ?? this.answeredCount,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      violationCount: violationCount ?? this.violationCount,
      lastSeen: lastSeen ?? this.lastSeen,
      submittedAt: submittedAt ?? this.submittedAt,
      receiptHash: receiptHash ?? this.receiptHash,
      lastViolationAlert: lastViolationAlert ?? this.lastViolationAlert,
    );
  }

  factory CandidateModel.fromJson(Map<String, dynamic> json) {
    CandidateStatus status = CandidateStatus.waiting;
    final statusStr = json['status'] as String?;
    if (statusStr == 'taking') {
      status = CandidateStatus.taking;
    } else if (statusStr == 'submitted') {
      status = CandidateStatus.submitted;
    }

    return CandidateModel(
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      classroom: json['classroom'] as String? ?? 'CNTT-K18A',
      deviceName: json['device_name'] as String? ?? 'Thiết bị thí sinh',
      status: status,
      answeredCount: json['answered_count'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      batteryLevel: json['battery_level'] as int? ?? 100,
      violationCount: json['violation_count'] as int? ?? 0,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String) ?? DateTime.now()
          : DateTime.now(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      receiptHash: json['receipt_hash'] as String?,
      lastViolationAlert: json['last_violation_alert'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'student_name': studentName,
      'classroom': classroom,
      'device_name': deviceName,
      'status': status.name,
      'answered_count': answeredCount,
      'total_questions': totalQuestions,
      'battery_level': batteryLevel,
      'violation_count': violationCount,
      'last_seen': lastSeen.toIso8601String(),
      if (submittedAt != null) 'submitted_at': submittedAt!.toIso8601String(),
      if (receiptHash != null) 'receipt_hash': receiptHash,
      if (lastViolationAlert != null) 'last_violation_alert': lastViolationAlert,
    };
  }

  String toRawJson() => jsonEncode(toJson());

  factory CandidateModel.fromRawJson(String str) =>
      CandidateModel.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
