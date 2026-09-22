import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/aes_encryption_service.dart';
import '../../models/exam_model.dart';
import '../../models/submission_model.dart';

class LocalExamStorage {
  static const String _keyCachedExam = 'localquiz_cached_exam';
  static const String _keyDraftAnswers = 'localquiz_draft_answers';
  static const String _keyLastSubmission = 'localquiz_last_submission';

  /// Save downloaded exam encrypted locally
  static Future<void> saveExam(ExamModel exam) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = exam.toRawJson();
    final encrypted = AesEncryptionService.encryptString(jsonStr);
    await prefs.setString(_keyCachedExam, encrypted);
  }

  /// Load cached exam
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

  /// Save answer drafts continuously
  static Future<void> saveDraftAnswers(String examId, Map<int, String> answers) async {
    final prefs = await SharedPreferences.getInstance();
    final map = answers.map((k, v) => MapEntry(k.toString(), v));
    final jsonStr = jsonEncode({'exam_id': examId, 'answers': map});
    await prefs.setString(_keyDraftAnswers, jsonStr);
  }

  /// Load saved draft answers
  static Future<Map<int, String>> loadDraftAnswers(String examId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyDraftAnswers);
    if (raw == null) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['exam_id'] != examId) return {};
      final map = decoded['answers'] as Map<String, dynamic>? ?? {};
      return map.map((k, v) => MapEntry(int.tryParse(k) ?? 0, v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Save successful submission
  static Future<void> saveSubmission(SubmissionModel submission) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSubmission, submission.toRawJson());
  }

  /// Clear all exam session data
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDraftAnswers);
  }
}
