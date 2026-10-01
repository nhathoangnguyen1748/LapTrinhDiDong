import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apptracngiem/core/utils/ble_rssi_helper.dart';
import 'package:apptracngiem/core/security/kiosk_manager.dart';
import 'package:apptracngiem/core/storage/local_exam_storage.dart';
import 'package:apptracngiem/core/constants/ble_constants.dart';

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

      // Bắn sự kiện AppLifecycleState.paused nhiều lần để giả lập đa nhiệm
      for (int i = 0; i < BleConstants.maxViolationsAllowed; i++) {
        KioskManager.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
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
  });
}
