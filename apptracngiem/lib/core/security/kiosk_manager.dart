import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import '../constants/ble_constants.dart';

typedef ViolationCallback = void Function(int currentViolations, String reason);
typedef AutoSubmitCallback = void Function();

/// Quản lý chế độ Kiosk chống gian lận trong thời gian làm bài thi.
/// Chức năng:
/// - Chặn chụp màn hình, quay phim màn hình (thông qua FLAG_SECURE).
/// - Giám sát vòng đời ứng dụng (App Lifecycle) để phát hiện thoát app, đa nhiệm.
/// - Tự động thu bài nộp nếu vi phạm quá số lần quy định.
class KioskManager with WidgetsBindingObserver {
  static final KioskManager instance = KioskManager._internal();
  KioskManager._internal();

  bool _isKioskActive = false;
  int _violationCount = 0;
  final List<DateTime> _violationTimestamps = [];
  
  ViolationCallback? onViolation;
  AutoSubmitCallback? onAutoSubmit;

  int get violationCount => _violationCount;
  bool get isKioskActive => _isKioskActive;
  List<DateTime> get violationTimestamps => List.unmodifiable(_violationTimestamps);

  /// Kích hoạt chế độ Kiosk bảo vệ
  Future<void> startKiosk({
    ViolationCallback? onViolationDetected,
    AutoSubmitCallback? onAutoSubmitTriggered,
  }) async {
    _isKioskActive = true;
    _violationCount = 0;
    _violationTimestamps.clear();
    
    onViolation = onViolationDetected;
    onAutoSubmit = onAutoSubmitTriggered;

    // Đăng ký lắng nghe sự kiện vòng đời ứng dụng
    WidgetsBinding.instance.addObserver(this);
    
    // Bật cờ FLAG_SECURE (chỉ áp dụng trên Android)
    await _enableFlagSecure();
    debugPrint('[KioskManager] Đã kích hoạt chế độ Kiosk Mode');
  }

  /// Tắt chế độ Kiosk bảo vệ sau khi nộp bài xong
  Future<void> stopKiosk() async {
    _isKioskActive = false;
    
    // Hủy đăng ký lắng nghe
    WidgetsBinding.instance.removeObserver(this);
    
    // Tắt cờ FLAG_SECURE
    await _disableFlagSecure();
    
    onViolation = null;
    onAutoSubmit = null;
    debugPrint('[KioskManager] Đã tắt chế độ Kiosk Mode');
  }

  /// Bật cờ chặn chụp và quay màn hình
  Future<void> _enableFlagSecure() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        debugPrint('[KioskManager] Đã bật FLAG_SECURE');
      } catch (e) {
        debugPrint('[KioskManager] Lỗi khi bật FLAG_SECURE: $e');
      }
    }
  }

  /// Tắt cờ chặn chụp và quay màn hình
  Future<void> _disableFlagSecure() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        debugPrint('[KioskManager] Đã tắt FLAG_SECURE');
      } catch (e) {
        debugPrint('[KioskManager] Lỗi khi tắt FLAG_SECURE: $e');
      }
    }
  }

  /// Lắng nghe thay đổi trạng thái vòng đời của ứng dụng
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isKioskActive) return;

    // Phát hiện người dùng cố tình thoát app, chia đôi màn hình hoặc chuyển qua app khác
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _recordViolation('Rời khỏi ứng dụng hoặc bật cửa sổ đa nhiệm');
    }
  }

  /// Ghi nhận 1 lần vi phạm
  void _recordViolation(String reason) {
    _violationCount++;
    _violationTimestamps.add(DateTime.now());
    debugPrint('[KioskManager] Phát hiện vi phạm lần thứ $_violationCount: $reason');

    // Báo cáo vi phạm về UI / Provider
    onViolation?.call(_violationCount, reason);

    // Nếu vi phạm vượt quá số lần tối đa, tự động thu bài nộp
    if (_violationCount >= BleConstants.maxViolationsAllowed) {
      debugPrint('[KioskManager] Đã đạt số lần vi phạm tối đa! Tự động nộp bài...');
      onAutoSubmit?.call();
    }
  }

  /// Đặt lại bộ đếm vi phạm
  void reset() {
    _violationCount = 0;
    _violationTimestamps.clear();
  }
}
