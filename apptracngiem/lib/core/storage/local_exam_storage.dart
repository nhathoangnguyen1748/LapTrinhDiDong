import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/aes_encryption_service.dart';
import '../../models/exam_model.dart';
import '../../models/submission_model.dart';
import '../../models/candidate_model.dart';

/// Lớp hỗ trợ lưu trữ dữ liệu ngoại tuyến an toàn vào bộ nhớ trong của thiết bị.
/// Sử dụng SharedPreferences kết hợp AES Encryption cho dữ liệu nhạy cảm.
class LocalExamStorage {
  static const String _keyCachedExam = 'localquiz_cached_exam';
  static const String _keyDownloadedExamsList = 'localquiz_downloaded_exams_list';
  static const String _keyDraftAnswers = 'localquiz_draft_answers';
  static const String _keyLastSubmission = 'localquiz_last_submission';

  /// Lưu đề thi đã tải về xuống bộ nhớ thiết bị sau khi mã hóa bằng AES
  /// Giúp chống việc lấy trộm nội dung đề thi từ bộ nhớ cache.
  static Future<void> saveExam(ExamModel exam) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = exam.toRawJson();
    final encrypted = AesEncryptionService.encryptString(jsonStr);
    await prefs.setString(_keyCachedExam, encrypted);
    await saveDownloadedExam(exam);
  }

  /// Tải lên đề thi đã lưu tạm và giải mã
  static Future<ExamModel?> getCachedExam() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(_keyCachedExam);
    if (encrypted == null) return null;

    try {
      final decrypted = AesEncryptionService.decryptString(encrypted);
      return ExamModel.fromRawJson(decrypted);
    } catch (_) {
      return null;
    }
  }

  /// Lưu trữ gói đề thi vào kho lưu trữ ngoại tuyến của Giảng viên (Khâu 1)
  static Future<void> saveDownloadedExam(ExamModel exam) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'localquiz_pkg_${exam.examId}';
    final encrypted = AesEncryptionService.encryptString(exam.toRawJson());
    await prefs.setString(key, encrypted);

    // Cập nhật danh sách ID các đề đã tải
    final list = prefs.getStringList(_keyDownloadedExamsList) ?? [];
    if (!list.contains(exam.examId)) {
      list.add(exam.examId);
      await prefs.setStringList(_keyDownloadedExamsList, list);
    }
  }

  /// Lấy danh sách toàn bộ đề thi đã tải về máy
  static Future<List<ExamModel>> getDownloadedExams() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyDownloadedExamsList) ?? [];
    final results = <ExamModel>[];

    for (final examId in list) {
      final encrypted = prefs.getString('localquiz_pkg_$examId');
      if (encrypted != null) {
        try {
          final decrypted = AesEncryptionService.decryptString(encrypted);
          results.add(ExamModel.fromRawJson(decrypted));
        } catch (_) {}
      }
    }
    return results;
  }

  /// Kiểm tra xem đề thi đã được tải về máy chưa
  static Future<bool> isExamDownloaded(String examId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('localquiz_pkg_$examId');
  }

  /// Xóa gói đề thi đã tải khỏi bộ nhớ thiết bị
  static Future<void> deleteDownloadedExam(String examId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('localquiz_pkg_$examId');

    final list = prefs.getStringList(_keyDownloadedExamsList) ?? [];
    list.remove(examId);
    await prefs.setStringList(_keyDownloadedExamsList, list);
  }

  /// Lưu bản nháp bài làm của thí sinh theo thời gian thực (chống mất dữ liệu khi sập nguồn)
  /// [examId]: ID của đề thi.
  /// [answers]: Bản đồ nối ID câu hỏi với ID phương án đã chọn.
  static Future<void> saveDraftAnswers(String examId, Map<int, String> answers) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Convert Map<int, String> thành Map<String, String> để jsonEncode
    final mapStrKeys = answers.map((k, v) => MapEntry(k.toString(), v));
    final jsonStr = jsonEncode({'exam_id': examId, 'answers': mapStrKeys});
    
    await prefs.setString(_keyDraftAnswers, jsonStr);
  }

  /// Tải lại bản nháp bài làm của thí sinh
  static Future<Map<int, String>> loadDraftAnswers(String examId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyDraftAnswers);
    if (raw == null) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      
      // Nếu ID đề thi không khớp, trả về danh sách rỗng (tránh nhầm lẫn với bài thi cũ)
      if (decoded['exam_id'] != examId) return {};
      
      final mapStrKeys = decoded['answers'] as Map<String, dynamic>? ?? {};
      
      // Convert ngược lại từ String keys thành int keys
      return mapStrKeys.map((k, v) => MapEntry(int.tryParse(k) ?? 0, v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Lưu kết quả bài nộp sau khi hoàn thành
  static Future<void> saveSubmission(SubmissionModel submission) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSubmission, submission.toRawJson());
  }

  /// Xóa toàn bộ dữ liệu phiên làm bài (khi kết thúc thành công)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDraftAnswers);
    // Lưu ý: Không xóa _keyLastSubmission ở đây để còn có thể xem lại kết quả
  }

  /// Lưu trữ lịch sử phòng thi của Giám thị (bài nộp và danh sách thí sinh)
  static Future<void> saveHostSessionHistory(
    String examId,
    List<SubmissionModel> submissions,
    List<CandidateModel> candidates,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final subList = submissions.map((s) => s.toJson()).toList();
    final canList = candidates.map((c) => c.toJson()).toList();
    final raw = jsonEncode({
      'submissions': subList,
      'candidates': canList,
    });
    await prefs.setString('localquiz_host_history_$examId', raw);
  }

  /// Tải lại lịch sử phòng thi đã lưu trước đó của Giám thị
  static Future<HostSessionHistory> loadHostSessionHistory(String examId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('localquiz_host_history_$examId');
    if (raw == null) return const HostSessionHistory(submissions: [], candidates: []);

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawSubs = decoded['submissions'] as List<dynamic>? ?? [];
      final rawCans = decoded['candidates'] as List<dynamic>? ?? [];

      final submissions = rawSubs
          .map((m) => SubmissionModel.fromJson(m as Map<String, dynamic>))
          .toList();
      final candidates = rawCans
          .map((m) => CandidateModel.fromJson(m as Map<String, dynamic>))
          .toList();
      return HostSessionHistory(submissions: submissions, candidates: candidates);
    } catch (_) {
      return const HostSessionHistory(submissions: [], candidates: []);
    }
  }

  /// Xóa lịch sử phòng thi khi cần thiết
  static Future<void> clearHostSessionHistory(String examId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('localquiz_host_history_$examId');
  }

  static const String _keyActiveStudentSession = 'localquiz_active_student_session';
  static const String _keyActiveHostSession = 'localquiz_active_host_session';

  /// Lưu trạng thái phiên làm bài đang diễn ra của Thí sinh
  static Future<void> saveActiveStudentSession(ActiveStudentSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveStudentSession, jsonEncode(session.toJson()));
  }

  /// Lấy thông tin phiên làm bài đang diễn ra của Thí sinh
  static Future<ActiveStudentSession?> getActiveStudentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyActiveStudentSession);
    if (raw == null) return null;
    try {
      return ActiveStudentSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Xóa phiên làm bài của Thí sinh khi đã nộp xong
  static Future<void> clearActiveStudentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveStudentSession);
  }

  /// Lưu trạng thái phiên giám thị ca thi của Giảng viên
  static Future<void> saveActiveHostSession(ActiveHostSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveHostSession, jsonEncode(session.toJson()));
  }

  /// Lấy thông tin phiên giám thị ca thi của Giảng viên
  static Future<ActiveHostSession?> getActiveHostSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyActiveHostSession);
    if (raw == null) return null;
    try {
      return ActiveHostSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Xóa phiên giám thị của Giảng viên khi kết thúc ca thi
  static Future<void> clearActiveHostSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveHostSession);
  }
}

class HostSessionHistory {
  final List<SubmissionModel> submissions;
  final List<CandidateModel> candidates;
  const HostSessionHistory({required this.submissions, required this.candidates});
}

class ActiveStudentSession {
  final ExamModel exam;
  final String studentId;
  final String studentName;
  final String classroom;
  final DateTime examStartTime;
  final DateTime examEndTime;
  final int violationCount;
  final bool autoSubmitOnViolations;
  final String? deviceRemoteId;
  final bool isMock;

  const ActiveStudentSession({
    required this.exam,
    required this.studentId,
    required this.studentName,
    required this.classroom,
    required this.examStartTime,
    required this.examEndTime,
    this.violationCount = 0,
    this.autoSubmitOnViolations = true,
    this.deviceRemoteId,
    this.isMock = false,
  });

  Map<String, dynamic> toJson() => {
    'exam': exam.toJson(),
    'studentId': studentId,
    'studentName': studentName,
    'classroom': classroom,
    'examStartTime': examStartTime.toIso8601String(),
    'examEndTime': examEndTime.toIso8601String(),
    'violationCount': violationCount,
    'autoSubmitOnViolations': autoSubmitOnViolations,
    'deviceRemoteId': deviceRemoteId,
    'isMock': isMock,
  };

  factory ActiveStudentSession.fromJson(Map<String, dynamic> json) {
    return ActiveStudentSession(
      exam: ExamModel.fromJson(json['exam'] as Map<String, dynamic>),
      studentId: json['studentId'] as String? ?? 'TS',
      studentName: json['studentName'] as String? ?? 'Thí sinh',
      classroom: json['classroom'] as String? ?? 'CNTT-K18A',
      examStartTime: DateTime.tryParse(json['examStartTime'] as String? ?? '') ?? DateTime.now(),
      examEndTime: DateTime.tryParse(json['examEndTime'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 30)),
      violationCount: json['violationCount'] as int? ?? 0,
      autoSubmitOnViolations: json['autoSubmitOnViolations'] as bool? ?? true,
      deviceRemoteId: json['deviceRemoteId'] as String?,
      isMock: json['isMock'] as bool? ?? false,
    );
  }
}

class ActiveHostSession {
  final ExamModel exam;
  final bool isAdvertising;
  final bool isExamStarted;
  final bool autoSubmitOnViolations;
  final DateTime startedAt;

  const ActiveHostSession({
    required this.exam,
    this.isAdvertising = true,
    this.isExamStarted = false,
    this.autoSubmitOnViolations = true,
    required this.startedAt,
  });

  Map<String, dynamic> toJson() => {
    'exam': exam.toJson(),
    'isAdvertising': isAdvertising,
    'isExamStarted': isExamStarted,
    'autoSubmitOnViolations': autoSubmitOnViolations,
    'startedAt': startedAt.toIso8601String(),
  };

  factory ActiveHostSession.fromJson(Map<String, dynamic> json) {
    return ActiveHostSession(
      exam: ExamModel.fromJson(json['exam'] as Map<String, dynamic>),
      isAdvertising: json['isAdvertising'] as bool? ?? true,
      isExamStarted: json['isExamStarted'] as bool? ?? false,
      autoSubmitOnViolations: json['autoSubmitOnViolations'] as bool? ?? true,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
