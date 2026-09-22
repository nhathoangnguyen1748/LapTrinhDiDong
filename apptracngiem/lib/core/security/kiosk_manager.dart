import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import '../constants/ble_constants.dart';

typedef ViolationCallback = void Function(int currentViolations, String reason);
typedef AutoSubmitCallback = void Function();

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

  /// Enable Kiosk protection: FLAG_SECURE and lifecycle monitoring
  Future<void> startKiosk({
    ViolationCallback? onViolationDetected,
    AutoSubmitCallback? onAutoSubmitTriggered,
  }) async {
    _isKioskActive = true;
    _violationCount = 0;
    _violationTimestamps.clear();
    onViolation = onViolationDetected;
    onAutoSubmit = onAutoSubmitTriggered;

    WidgetsBinding.instance.addObserver(this);
    await _enableFlagSecure();
    debugPrint('[KioskManager] Kiosk Mode Activated');
  }

  /// Disable Kiosk protection
  Future<void> stopKiosk() async {
    _isKioskActive = false;
    WidgetsBinding.instance.removeObserver(this);
    await _disableFlagSecure();
    onViolation = null;
    onAutoSubmit = null;
    debugPrint('[KioskManager] Kiosk Mode Deactivated');
  }

  Future<void> _enableFlagSecure() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        debugPrint('[KioskManager] FLAG_SECURE enabled');
      } catch (e) {
        debugPrint('[KioskManager] Error enabling FLAG_SECURE: $e');
      }
    }
  }

  Future<void> _disableFlagSecure() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        debugPrint('[KioskManager] FLAG_SECURE disabled');
      } catch (e) {
        debugPrint('[KioskManager] Error disabling FLAG_SECURE: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isKioskActive) return;

    // Detect when user attempts to leave app, split-screen, or switch tasks
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _recordViolation('Rời khỏi ứng dụng hoặc bật cửa sổ đa nhiệm');
    }
  }

  void _recordViolation(String reason) {
    _violationCount++;
    _violationTimestamps.add(DateTime.now());
    debugPrint('[KioskManager] Violation #$_violationCount detected: $reason');

    onViolation?.call(_violationCount, reason);

    if (_violationCount >= BleConstants.maxViolationsAllowed) {
      debugPrint('[KioskManager] Max violations reached! Auto-submitting exam...');
      onAutoSubmit?.call();
    }
  }

  /// Reset violation counter
  void reset() {
    _violationCount = 0;
    _violationTimestamps.clear();
  }
}
