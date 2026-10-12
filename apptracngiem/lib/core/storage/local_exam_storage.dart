import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/aes_encryption_service.dart';
import '../../models/exam_model.dart';
import '../../models/submission_model.dart';

/// Lớp hỗ trợ lưu trữ dữ liệu ngoại tuyến an toàn vào bộ nhớ trong của thiết bị.
/// Sử dụng SharedPreferences kết hợp AES Encryption cho dữ liệu nhạy cảm.
class LocalExamStorage {
  static const String _keyCachedExam = 'localquiz_cached_exam';
  static const String _keyDraftAnswers = 'localquiz_draft_answers';
  static const String _keyLastSubmission = 'localquiz_last_submission';

  /// Lưu đề thi đã tải về xuống bộ nhớ thiết bị sau khi mã hóa bằng AES
  /// Giúp chống việc lấy trộm nội dung đề thi từ bộ nhớ cache.
  static Future<void> saveExam(ExamModel exam) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = exam.toRawJson();
    final encrypted = AesEncryptionService.encryptString(jsonStr);
    await prefs.setString(_keyCachedExam, encrypted);
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
}
