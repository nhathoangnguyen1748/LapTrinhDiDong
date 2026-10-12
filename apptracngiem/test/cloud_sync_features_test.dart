import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apptracngiem/core/storage/local_exam_storage.dart';
import 'package:apptracngiem/models/exam_model.dart';
import 'package:apptracngiem/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Sync & Multi-Exam Storage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('LocalExamStorage saves and loads multiple downloaded exams offline', () async {
      final sampleExam = ExamModel.sampleExam();
      expect(await LocalExamStorage.isExamDownloaded(sampleExam.examId), isFalse);

      await LocalExamStorage.saveDownloadedExam(sampleExam);
      expect(await LocalExamStorage.isExamDownloaded(sampleExam.examId), isTrue);

      final list = await LocalExamStorage.getDownloadedExams();
      expect(list.length, equals(1));
      expect(list.first.examId, equals(sampleExam.examId));
      expect(list.first.title, equals(sampleExam.title));
      expect(list.first.questions.length, equals(sampleExam.questions.length));
    });

    test('ApiService baseUrl configuration and token persistence', () async {
      await ApiService.instance.init();
      const testUrl = 'http://192.168.1.100:8000';
      await ApiService.instance.setBaseUrl(testUrl);
      expect(ApiService.instance.baseUrl, equals('http://192.168.1.100:8000/api/v1'));

      await ApiService.instance.saveToken('test_jwt_token_123');
      expect(ApiService.instance.token, equals('test_jwt_token_123'));

      await ApiService.instance.saveToken(null);
      expect(ApiService.instance.token, isNull);
    });
  });
}
