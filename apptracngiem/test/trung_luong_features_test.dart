import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apptracngiem/core/utils/ble_rssi_helper.dart';
import 'package:apptracngiem/core/security/kiosk_manager.dart';
import 'package:apptracngiem/core/storage/local_exam_storage.dart';
import 'package:apptracngiem/core/constants/ble_constants.dart';
import 'package:apptracngiem/models/exam_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. BleRssiHelper Tests (RSSI Geofencing)', () {
    test('getStatus() nên trả về RssiStatus.optimal khi tín hiệu mạnh (>= -75 dBm)', () {
      expect(BleRssiHelper.getStatus(-70), RssiStatus.optimal);
      expect(BleRssiHelper.getStatus(-75), RssiStatus.optimal);
      expect(BleRssiHelper.getStatus(-50), RssiStatus.optimal);
    });

    test('getStatus() nên trả về RssiStatus.warning khi tín hiệu bắt đầu yếu đi (-85 đến -75 dBm)', () {
      expect(BleRssiHelper.getStatus(-76), RssiStatus.warning);
      expect(BleRssiHelper.getStatus(-80), RssiStatus.warning);
      expect(BleRssiHelper.getStatus(-84), RssiStatus.warning);
    });

    test('getStatus() nên trả về RssiStatus.critical khi tín hiệu quá yếu (< -85 dBm) - vi phạm phạm vi', () {
      expect(BleRssiHelper.getStatus(-86), RssiStatus.critical);
      expect(BleRssiHelper.getStatus(-95), RssiStatus.critical);
    });

    test('getStatus() nên trả về RssiStatus.disconnected nếu mất kết nối hoặc rssi bị null', () {
      expect(BleRssiHelper.getStatus(null), RssiStatus.disconnected);
      expect(BleRssiHelper.getStatus(-60, isConnected: false), RssiStatus.disconnected);
    });

    test('estimateDistance() tính khoảng cách theo mô hình Log-distance path loss chuẩn', () {
      // Ở 1 mét chuẩn thì RSSI ~ -59 dBm
      final dist1 = BleRssiHelper.estimateDistance(-59, measuredPower: -59, n: 2.0);
      expect(dist1, 1.0); 

      // Nếu tín hiệu yếu hơn, khoảng cách lớn hơn
      final dist2 = BleRssiHelper.estimateDistance(-79, measuredPower: -59, n: 2.0);
      expect(dist2, 10.0);
    });
  });

  group('2. KioskManager Tests (Anti-Cheat)', () {
    setUp(() {
      KioskManager.instance.reset();
    });

    test('Ban đầu số lần vi phạm (violationCount) phải là 0', () {
      expect(KioskManager.instance.violationCount, 0);
    });

    test('Tự động nộp bài khi số lần vi phạm >= maxViolationsAllowed', () async {
      bool autoSubmitTriggered = false;
      int violationCounter = 0;

      await KioskManager.instance.startKiosk(
        onViolationDetected: (count, reason) {
          violationCounter = count;
        },
        onAutoSubmitTriggered: () {
          autoSubmitTriggered = true;
        },
      );

      // Thoát ra (inactive + paused) rồi vào lại (resumed) chỉ tính 1 lần mỗi lần thoát
      for (int i = 0; i < BleConstants.maxViolationsAllowed; i++) {
        // Hệ điều hành Android gửi inactive rồi paused trong cùng 1 lần thoát app
        KioskManager.instance.didChangeAppLifecycleState(AppLifecycleState.inactive);
        KioskManager.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
        // Thí sinh quay lại app
        KioskManager.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
      }

      expect(violationCounter, BleConstants.maxViolationsAllowed);
      expect(autoSubmitTriggered, isTrue);

      await KioskManager.instance.stopKiosk();
    });
  });

  group('3. LocalExamStorage Tests (Draft Offline Storage)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveDraftAnswers() và loadDraftAnswers() hoạt động chính xác với đúng ID đề thi', () async {
      const testExamId = 'exam_123';
      final draftAnswers = {
        1: 'A',
        2: 'C',
        5: 'B'
      };

      // Gọi save
      await LocalExamStorage.saveDraftAnswers(testExamId, draftAnswers);

      // Gọi load
      final loaded = await LocalExamStorage.loadDraftAnswers(testExamId);

      expect(loaded.length, 3);
      expect(loaded[1], 'A');
      expect(loaded[2], 'C');
      expect(loaded[5], 'B');
    });

    test('loadDraftAnswers() trả về map rỗng nếu ID đề thi không khớp (đề mới)', () async {
      const testExamId = 'exam_123';
      final draftAnswers = { 1: 'A' };
      await LocalExamStorage.saveDraftAnswers(testExamId, draftAnswers);

      // Thử load bằng ID khác
      final loaded = await LocalExamStorage.loadDraftAnswers('exam_456');
      expect(loaded, isEmpty);
    });

    test('clearSession() xóa toàn bộ bản nháp nhưng không ảnh hưởng dữ liệu khác', () async {
      const testExamId = 'exam_123';
      await LocalExamStorage.saveDraftAnswers(testExamId, {1: 'A'});
      
      var loaded = await LocalExamStorage.loadDraftAnswers(testExamId);
      expect(loaded, isNotEmpty);

      await LocalExamStorage.clearSession();

      loaded = await LocalExamStorage.loadDraftAnswers(testExamId);
      expect(loaded, isEmpty);
    });

    test('ActiveStudentSession lưu và khôi phục chính xác phiên thi của thí sinh', () async {
      final sampleExam = ExamModel.sampleExam();
      final startTime = DateTime.now();
      final endTime = startTime.add(const Duration(minutes: 15));

      final session = ActiveStudentSession(
        exam: sampleExam,
        studentId: '21110001',
        studentName: 'Nguyễn Văn A',
        classroom: 'KTPM01',
        examStartTime: startTime,
        examEndTime: endTime,
        violationCount: 1,
        autoSubmitOnViolations: true,
        deviceRemoteId: 'AA:BB:CC:DD:EE:FF',
        isMock: false,
      );

      await LocalExamStorage.saveActiveStudentSession(session);

      final restored = await LocalExamStorage.getActiveStudentSession();
      expect(restored, isNotNull);
      expect(restored!.studentId, '21110001');
      expect(restored.studentName, 'Nguyễn Văn A');
      expect(restored.classroom, 'KTPM01');
      expect(restored.violationCount, 1);
      expect(restored.autoSubmitOnViolations, isTrue);
      expect(restored.deviceRemoteId, 'AA:BB:CC:DD:EE:FF');
      expect(restored.isMock, isFalse);
      expect(restored.exam.examId, sampleExam.examId);

      await LocalExamStorage.clearActiveStudentSession();
      expect(await LocalExamStorage.getActiveStudentSession(), isNull);
    });

    test('KioskManager nhận initialViolations và kích hoạt autoSubmit chính xác khi đạt ngưỡng', () async {
      bool autoSubmitted = false;
      int recordedViolations = 0;

      await KioskManager.instance.startKiosk(
        initialViolations: 2,
        onViolationDetected: (count, reason) {
          recordedViolations = count;
        },
        onAutoSubmitTriggered: () {
          autoSubmitted = true;
        },
      );

      expect(KioskManager.instance.violationCount, 2);

      // Rời app lần thứ 3 (inactive -> paused -> resumed)
      KioskManager.instance.didChangeAppLifecycleState(AppLifecycleState.inactive);
      KioskManager.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
      KioskManager.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(KioskManager.instance.violationCount, 3);
      expect(recordedViolations, 3);
      expect(autoSubmitted, isTrue);

      await KioskManager.instance.stopKiosk();
    });

    test('ActiveHostSession lưu và khôi phục chính xác phiên tổ chức thi của giám thị', () async {
      final sampleExam = ExamModel.sampleExam();
      final session = ActiveHostSession(
        exam: sampleExam,
        isAdvertising: true,
        isExamStarted: true,
        autoSubmitOnViolations: false,
        startedAt: DateTime.now(),
      );

      await LocalExamStorage.saveActiveHostSession(session);

      final restored = await LocalExamStorage.getActiveHostSession();
      expect(restored, isNotNull);
      expect(restored!.exam.examId, sampleExam.examId);
      expect(restored.isAdvertising, isTrue);
      expect(restored.isExamStarted, isTrue);
      expect(restored.autoSubmitOnViolations, isFalse);

      await LocalExamStorage.clearActiveHostSession();
      expect(await LocalExamStorage.getActiveHostSession(), isNull);
    });
  });
}
