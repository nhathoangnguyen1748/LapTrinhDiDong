import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/ble_constants.dart';

enum RssiStatus {
  optimal, // >= -75 dBm: Strong signal, safe in room
  warning, // -85 .. -75 dBm: Warning, moving away
  critical, // < -85 dBm: Out of bounds, freeze exam
  disconnected, // Lost connection
}

class BleRssiHelper {
  /// Determine RSSI status classification
  static RssiStatus getStatus(int? rssi, {bool isConnected = true}) {
    if (!isConnected || rssi == null) {
      return RssiStatus.disconnected;
    }
    if (rssi >= BleConstants.rssiOptimalThreshold) {
      return RssiStatus.optimal;
    } else if (rssi >= BleConstants.rssiWarningThreshold) {
      return RssiStatus.warning;
    } else {
      return RssiStatus.critical;
    }
  }

  /// Get corresponding display color
  static Color getStatusColor(RssiStatus status) {
    switch (status) {
      case RssiStatus.optimal:
        return AppColors.rssiGood;
      case RssiStatus.warning:
        return AppColors.rssiWarning;
      case RssiStatus.critical:
        return AppColors.rssiCritical;
      case RssiStatus.disconnected:
        return AppColors.rssiDisabled;
    }
  }

  /// Get localized Vietnamese status label
  static String getStatusLabel(RssiStatus status, int? rssi) {
    switch (status) {
      case RssiStatus.optimal:
        return 'Tín hiệu tốt ($rssi dBm)';
      case RssiStatus.warning:
        return 'Cảnh báo: Cách xa ($rssi dBm)';
      case RssiStatus.critical:
        return 'Ngoài vùng thi ($rssi dBm)';
      case RssiStatus.disconnected:
        return 'Mất kết nối BLE';
    }
  }

  /// Approximate distance in meters based on log-distance path loss model:
  /// distance = 10 ^ ((MeasuredPower - RSSI) / (10 * N))
  /// MeasuredPower: RSSI at 1m (~ -59 dBm)
  /// N: Path loss exponent (2.0 for free space, 2.5 indoors)
  static double estimateDistance(int? rssi, {int measuredPower = -59, double n = 2.4}) {
    if (rssi == null || rssi == 0) return 0.0;
    final ratio = (measuredPower - rssi) / (10 * n);
    final distance = pow(10, ratio).toDouble();
    return double.parse(distance.toStringAsFixed(1));
  }

  /// Convert RSSI into a signal quality percentage (0% to 100%)
  static double getSignalPercentage(int? rssi) {
    if (rssi == null) return 0.0;
    // Map -100 dBm (0%) to -50 dBm (100%)
    final clamped = rssi.clamp(-100, -50);
    return ((clamped - (-100)) / 50.0).clamp(0.0, 1.0);
  }
}
