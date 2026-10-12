import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/ble_constants.dart';

/// Trạng thái cường độ sóng (RSSI) của kết nối BLE
enum RssiStatus {
  optimal,       // Tín hiệu tốt, an toàn (>= -75 dBm)
  warning,       // Cảnh báo, đang di chuyển ra xa (-85 dBm đến -75 dBm)
  critical,      // Vi phạm phạm vi, ngoài vùng an toàn (< -85 dBm)
  disconnected,  // Đã mất kết nối hoàn toàn
}

/// Tiện ích hỗ trợ phân tích và tính toán các chỉ số liên quan đến RSSI BLE
class BleRssiHelper {
  
  /// Phân loại trạng thái tín hiệu dựa trên giá trị RSSI (dBm)
  /// [rssi] là cường độ sóng hiện tại nhận được từ thiết bị Giám thị.
  static RssiStatus getStatus(int? rssi, {bool isConnected = true}) {
    if (!isConnected || rssi == null) {
      return RssiStatus.disconnected;
    }
    
    // Nếu cường độ >= -75 dBm, tín hiệu ở mức tối ưu
    if (rssi >= BleConstants.rssiOptimalThreshold) {
      return RssiStatus.optimal;
    } 
    // Nếu cường độ >= -85 dBm, tín hiệu bắt đầu yếu đi (cảnh báo)
    else if (rssi >= BleConstants.rssiWarningThreshold) {
      return RssiStatus.warning;
    } 
    // Nếu < -85 dBm, thí sinh đã đi quá xa phòng thi
    else {
      return RssiStatus.critical;
    }
  }

  /// Lấy màu sắc tương ứng với trạng thái để hiển thị lên giao diện
  static Color getStatusColor(RssiStatus status) {
    switch (status) {
      case RssiStatus.optimal:
        return AppColors.rssiGood;      // Màu xanh lá
      case RssiStatus.warning:
        return AppColors.rssiWarning;   // Màu cam/vàng
      case RssiStatus.critical:
        return AppColors.rssiCritical;  // Màu đỏ
      case RssiStatus.disconnected:
        return AppColors.rssiDisabled;  // Màu xám
    }
  }

  /// Trả về nhãn trạng thái thân thiện cho người dùng (Tiếng Việt)
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

  /// Ước tính khoảng cách (mét) dựa trên mô hình suy hao tín hiệu theo khoảng cách (Log-distance path loss).
  /// [measuredPower]: Giá trị RSSI tham chiếu tại khoảng cách 1 mét (thường ~ -59 dBm).
  /// [n]: Hệ số suy hao môi trường (N = 2.0 cho không gian mở, 2.4 - 2.5 cho môi trường trong nhà/phòng thi).
  static double estimateDistance(int? rssi, {int measuredPower = -59, double n = 2.4}) {
    // Không thể tính toán nếu không có rssi
    if (rssi == null || rssi == 0) return 0.0;
    
    // Công thức tính: Khoảng cách = 10 ^ ((MeasuredPower - RSSI) / (10 * n))
    final ratio = (measuredPower - rssi) / (10 * n);
    final distanceInMeters = pow(10, ratio).toDouble();
    
    // Làm tròn đến 1 chữ số thập phân cho dễ nhìn
    return double.parse(distanceInMeters.toStringAsFixed(1));
  }

  /// Chuyển đổi RSSI sang phần trăm chất lượng tín hiệu (từ 0% đến 100%)
  static double getSignalPercentage(int? rssi) {
    if (rssi == null) return 0.0;
    
    // Giới hạn RSSI trong khoảng -100 dBm (0%) tới -50 dBm (100%)
    final clampedRssi = rssi.clamp(-100, -50);
    
    // Tính phần trăm
    return ((clampedRssi - (-100)) / 50.0).clamp(0.0, 1.0);
  }
}
