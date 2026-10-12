import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exam_model.dart';
import '../models/submission_model.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  static const String _prefBaseUrlKey = 'localquiz_api_base_url';
  static const String _prefTokenKey = 'localquiz_jwt_token';

  // Default to live Render cloud backend
  String _baseUrl = 'https://localquiz-backend.onrender.com/api/v1';

  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefBaseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
    _token = prefs.getString(_prefTokenKey);
  }

  Future<void> setBaseUrl(String url) async {
    var formatted = url.trim();
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (!formatted.endsWith('/api/v1')) {
      formatted = '$formatted/api/v1';
    }
    _baseUrl = formatted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrlKey, _baseUrl);
  }

  Future<void> saveToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_prefTokenKey, token);
    } else {
      await prefs.remove(_prefTokenKey);
    }
  }

  Map<String, String> _headers({bool requiresAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // --- 1. Authentication ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: _headers(requiresAuth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      await saveToken(accessToken);
      return data;
    } else {
      final error = _parseError(response);
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String fullName) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    final response = await http.post(
      url,
      headers: _headers(requiresAuth: false),
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      await saveToken(accessToken);
      return data;
    } else {
      final error = _parseError(response);
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>?> getMe() async {
    if (_token == null) return null;
    final url = Uri.parse('$_baseUrl/auth/me');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      await saveToken(null);
      return null;
    }
  }

  // --- 2. Exam Management ---
  Future<List<Map<String, dynamic>>> getExams() async {
    final url = Uri.parse('$_baseUrl/exams');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception(_parseError(response));
    }
  }

  /// Tạo đề thi mới trên FastAPI Backend
  Future<Map<String, dynamic>> createExam(Map<String, dynamic> examData) async {
    final url = Uri.parse('$_baseUrl/exams');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode(examData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception(_parseError(response));
    }
  }

  /// Khâu 1: Tải gói đề thi trọn gói về máy để chuẩn bị phát BLE offline
  Future<ExamModel> downloadExamPackage(String examId) async {
    final url = Uri.parse('$_baseUrl/exams/$examId/package');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ExamModel.fromJson(data);
    } else {
      throw Exception(_parseError(response));
    }
  }

  // --- 3. Cloud Sync (Khâu 3: Sau ca thi) ---
  Future<Map<String, dynamic>> syncSubmissions({
    required String examId,
    required String roomName,
    required List<SubmissionModel> submissions,
  }) async {
    final url = Uri.parse('$_baseUrl/exams/$examId/sync-submissions');

    final payload = {
      'exam_id': examId,
      'room_name': roomName,
      'submissions': submissions.map((s) {
        return {
          'student_id': s.studentId,
          'student_name': s.studentName,
          if (s.classroom != null) 'classroom': s.classroom,
          'answers': s.answers.map((k, v) => MapEntry(k.toString(), v)),
          'score': s.score,
          'total_questions': s.totalQuestions,
          'time_taken_seconds': s.timeTakenSeconds,
          'violation_count': s.violationCount,
          'submitted_at': s.submittedAt.toIso8601String(),
        };
      }).toList(),
    };

    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception(_parseError(response));
    }
  }

  // --- 4. Reports & Analytics ---
  Future<Map<String, dynamic>> getExamReport(String examId) async {
    final url = Uri.parse('$_baseUrl/exams/$examId/report');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception(_parseError(response));
    }
  }

  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return 'Lỗi máy chủ (${response.statusCode}): ${response.reasonPhrase ?? ""}';
  }
}
