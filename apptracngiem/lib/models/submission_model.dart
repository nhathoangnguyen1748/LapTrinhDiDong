import 'dart:convert';

class SubmissionModel {
  final String examId;
  final String studentId;
  final String studentName;
  final Map<int, String> answers;
  final DateTime submittedAt;
  final int timeTakenSeconds;
  final int score;
  final int totalQuestions;
  final int violationCount;
  final String? deviceId;

  const SubmissionModel({
    required this.examId,
    required this.studentId,
    required this.studentName,
    required this.answers,
    required this.submittedAt,
    required this.timeTakenSeconds,
    required this.score,
    required this.totalQuestions,
    this.violationCount = 0,
    this.deviceId,
  });

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? {};
    final parsedAnswers = rawAnswers.map(
      (key, value) => MapEntry(int.tryParse(key) ?? 0, value.toString()),
    );

    return SubmissionModel(
      examId: json['exam_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      answers: parsedAnswers,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      timeTakenSeconds: json['time_taken_seconds'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      violationCount: json['violation_count'] as int? ?? 0,
      deviceId: json['device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final stringAnswers = answers.map((k, v) => MapEntry(k.toString(), v));
    return {
      'exam_id': examId,
      'student_id': studentId,
      'student_name': studentName,
      'answers': stringAnswers,
      'submitted_at': submittedAt.toIso8601String(),
      'time_taken_seconds': timeTakenSeconds,
      'score': score,
      'total_questions': totalQuestions,
      'violation_count': violationCount,
      if (deviceId != null) 'device_id': deviceId,
    };
  }

  String toRawJson() => jsonEncode(toJson());

  factory SubmissionModel.fromRawJson(String str) =>
      SubmissionModel.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
