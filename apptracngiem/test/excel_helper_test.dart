import 'package:flutter_test/flutter_test.dart';
import 'package:apptracngiem/core/utils/excel_helper.dart';
import 'package:apptracngiem/models/submission_model.dart';

void main() {
  group('ExcelHelper Tests', () {
    test('1. Tạo và đọc file Excel mẫu câu hỏi (.xlsx) thành công', () {
      // 1. Tạo file Excel mẫu
      final templateBytes = ExcelHelper.createQuestionTemplateExcel();
      expect(templateBytes.isNotEmpty, isTrue);

      // 2. Parse ngược lại thành danh sách QuestionModel
      final questions = ExcelHelper.parseQuestionsFromExcel(templateBytes);
      expect(questions.length, equals(4));

      // Kiểm tra câu 1
      expect(questions[0].id, equals(1));
      expect(questions[0].content, contains('Bluetooth Low Energy'));
      expect(questions[0].options.length, equals(4));
      expect(questions[0].options[0].id, equals('A'));
      expect(questions[0].options[0].text, equals('2.4 GHz ISM Band'));
      expect(questions[0].correctOptionId, equals('A'));

      // Kiểm tra câu 2
      expect(questions[1].id, equals(2));
      expect(questions[1].content, contains('RSSI'));
      expect(questions[1].correctOptionId, equals('B'));

      // Kiểm tra câu 3
      expect(questions[2].id, equals(3));
      expect(questions[2].correctOptionId, equals('C'));

      // Kiểm tra câu 4
      expect(questions[3].id, equals(4));
      expect(questions[3].correctOptionId, equals('D'));
    });

    test('2. Xuất bảng điểm danh sách bài nộp ra file Excel (.xlsx)', () {
      final mockSubmissions = [
        SubmissionModel(
          examId: 'EXAM_CNTT_K18',
          studentId: 'SV001',
          studentName: 'Nguyễn Văn A',
          classroom: 'CNTT-K18A',
          answers: {1: 'A', 2: 'B'},
          submittedAt: DateTime(2026, 10, 13, 10, 0),
          timeTakenSeconds: 300,
          score: 4,
          totalQuestions: 4,
          violationCount: 0,
          receiptHash: 'ACK-SV001-OK',
        ),
        SubmissionModel(
          examId: 'EXAM_CNTT_K18',
          studentId: 'SV002',
          studentName: 'Trần Thị B',
          classroom: 'CNTT-K18B',
          answers: {1: 'A', 2: 'A'},
          submittedAt: DateTime(2026, 10, 13, 10, 5),
          timeTakenSeconds: 450,
          score: 1,
          totalQuestions: 4,
          violationCount: 2,
          receiptHash: 'ACK-SV002-OK',
        ),
      ];

      final excelBytes = ExcelHelper.exportSubmissionsToExcel(
        examTitle: 'Lập trình di động',
        examId: 'EXAM_CNTT_K18',
        submissions: mockSubmissions,
      );

      expect(excelBytes.isNotEmpty, isTrue);
    });
  });
}
