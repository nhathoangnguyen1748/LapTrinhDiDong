import 'package:flutter_test/flutter_test.dart';
import 'package:apptracngiem/models/candidate_model.dart';
import 'package:apptracngiem/models/exam_model.dart';
import 'package:apptracngiem/models/submission_model.dart';
import 'package:apptracngiem/services/ble_peripheral_service.dart';

void main() {
  group('Roster & Admin Upgrade Tests', () {
    test('1. ExamModel serializes and parses roomPin correctly', () {
      final exam = ExamModel(
        examId: 'EXAM_TEST_PIN',
        title: 'Môn thi thử nghiệm PIN',
        durationSeconds: 1800,
        roomPin: '9999',
        questions: const [
          QuestionModel(
            id: 1,
            content: 'Nội dung câu hỏi?',
            options: [
              OptionModel(id: 'A', text: 'Đáp án A'),
              OptionModel(id: 'B', text: 'Đáp án B'),
            ],
            correctOptionId: 'A',
          ),
        ],
      );

      final json = exam.toJson();
      expect(json['room_pin'], equals('9999'));

      final parsed = ExamModel.fromJson(json);
      expect(parsed.roomPin, equals('9999'));
      expect(parsed.examId, equals('EXAM_TEST_PIN'));
    });

    test('2. CandidateModel serializes and deserializes accurately', () {
      final candidate = CandidateModel(
        studentId: 'TS-2026-001',
        studentName: 'Nguyễn Văn An',
        classroom: 'CNTT-K18A',
        deviceName: 'Pixel 8 Pro',
        status: CandidateStatus.taking,
        answeredCount: 15,
        totalQuestions: 20,
        batteryLevel: 88,
        violationCount: 1,
        lastSeen: DateTime(2026, 10, 12, 10, 0),
        lastViolationAlert: 'Rời ứng dụng',
      );

      final json = candidate.toJson();
      expect(json['student_id'], equals('TS-2026-001'));
      expect(json['classroom'], equals('CNTT-K18A'));
      expect(json['status'], equals('taking'));
      expect(json['answered_count'], equals(15));
      expect(json['battery_level'], equals(88));

      final parsed = CandidateModel.fromJson(json);
      expect(parsed.studentId, equals('TS-2026-001'));
      expect(parsed.classroom, equals('CNTT-K18A'));
      expect(parsed.status, equals(CandidateStatus.taking));
      expect(parsed.answeredCount, equals(15));
      expect(parsed.lastViolationAlert, equals('Rời ứng dụng'));
    });

    test('3. SubmissionModel serializes classroom and receiptHash', () {
      final sub = SubmissionModel(
        examId: 'EXAM_TEST',
        studentId: 'TS-001',
        studentName: 'Trần Văn Nam',
        classroom: 'KTPM-K18',
        answers: const {1: 'A', 2: 'B'},
        submittedAt: DateTime(2026, 10, 12, 11, 0),
        timeTakenSeconds: 600,
        score: 2,
        totalQuestions: 2,
        receiptHash: 'ACK-TS-001-OK',
      );

      final json = sub.toJson();
      expect(json['classroom'], equals('KTPM-K18'));
      expect(json['receipt_hash'], equals('ACK-TS-001-OK'));

      final parsed = SubmissionModel.fromJson(json);
      expect(parsed.classroom, equals('KTPM-K18'));
      expect(parsed.receiptHash, equals('ACK-TS-001-OK'));
    });

    test('4. BlePeripheralService manages roster candidates and master start command', () {
      final service = BlePeripheralService.instance;
      
      final c1 = CandidateModel(
        studentId: 'TS-TEST-01',
        studentName: 'Lê Văn C',
        classroom: 'CNTT-K18',
        status: CandidateStatus.waiting,
        lastSeen: DateTime.now(),
      );

      service.addOrUpdateCandidate(c1);
      expect(service.candidates.any((c) => c.studentId == 'TS-TEST-01'), isTrue);

      // Update progress
      service.updateCandidateProgress('TS-TEST-01', 5, 80);
      final updated = service.candidates.firstWhere((c) => c.studentId == 'TS-TEST-01');
      expect(updated.answeredCount, equals(5));
      expect(updated.batteryLevel, equals(80));

      // Record violation
      service.recordCandidateViolation('TS-TEST-01', 2, 'Bật đa nhiệm');
      final violated = service.candidates.firstWhere((c) => c.studentId == 'TS-TEST-01');
      expect(violated.violationCount, equals(2));
      expect(violated.lastViolationAlert, equals('Bật đa nhiệm'));

      // Broadcast start exam
      service.broadcastStartExam();
      expect(service.isExamStarted, isTrue);
      final startedCandidate = service.candidates.firstWhere((c) => c.studentId == 'TS-TEST-01');
      expect(startedCandidate.status, equals(CandidateStatus.taking));
    });
  });
}
