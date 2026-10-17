import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'permission_helper.dart';

class DeviceEnvironmentStatus {
  final bool isBluetoothOn;
  final bool isLocationOn;
  final bool isLocationPermissionGranted;
  final bool isWifiOff;
  final String? errorMessage;

  bool get isReadyToScan =>
      isBluetoothOn && isLocationOn && isLocationPermissionGranted && isWifiOff;

  const DeviceEnvironmentStatus({
    required this.isBluetoothOn,
    required this.isLocationOn,
    required this.isLocationPermissionGranted,
    required this.isWifiOff,
    this.errorMessage,
  });
}

class DeviceEnvironmentHelper {
  static const MethodChannel _channel = MethodChannel('com.example.apptracngiem/device_check');

  /// Check if Wi-Fi is currently connected/active
  static Future<bool> isWifiActive() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final bool? isWifi = await _channel.invokeMethod<bool>('isWifiEnabled');
        if (isWifi != null) return isWifi;
      } catch (_) {}
    }

    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wifi') || name.contains('wl')) {
          if (iface.addresses.isNotEmpty) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Check if Bluetooth adapter is enabled
  static Future<bool> isBluetoothEnabled() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      try {
        final bool? isBt = await _channel.invokeMethod<bool>('isBluetoothEnabled');
        if (isBt != null) return isBt;
      } catch (_) {}
    }
    return true;
  }

  /// Check if Location service (GPS) is enabled
  static Future<bool> isLocationServiceEnabled() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      try {
        final bool? isLoc = await _channel.invokeMethod<bool>('isLocationEnabled');
        if (isLoc != null) return isLoc;
      } catch (_) {}
    }
    try {
      return await Permission.location.serviceStatus.isEnabled;
    } catch (_) {
      return true;
    }
  }

  /// Comprehensive check for Student Scan pre-conditions
  static Future<DeviceEnvironmentStatus> checkStudentPreConditions() async {
    final hasBlePerms = await PermissionHelper.hasBlePermissions();
    if (!hasBlePerms) {
      final requested = await PermissionHelper.requestBlePermissions();
      if (!requested) {
        return const DeviceEnvironmentStatus(
          isBluetoothOn: false,
          isLocationOn: false,
          isLocationPermissionGranted: false,
          isWifiOff: true,
          errorMessage: 'Vui lòng cấp quyền Bluetooth & Vị trí trong Cài đặt để quét phòng thi.',
        );
      }
    }

    final isBtOn = await isBluetoothEnabled();
    if (!isBtOn) {
      return const DeviceEnvironmentStatus(
        isBluetoothOn: false,
        isLocationOn: true,
        isLocationPermissionGranted: true,
        isWifiOff: true,
        errorMessage: 'Vui lòng BẬT Bluetooth trên điện thoại để quét phòng thi BLE.',
      );
    }

    final isLocOn = await isLocationServiceEnabled();
    if (!isLocOn) {
      return const DeviceEnvironmentStatus(
        isBluetoothOn: true,
        isLocationOn: false,
        isLocationPermissionGranted: true,
        isWifiOff: true,
        errorMessage: 'Vui lòng BẬT Vị trí (GPS) để quét và đo khoảng cách RSSI.',
      );
    }

    final isWifi = await isWifiActive();
    if (isWifi) {
      return const DeviceEnvironmentStatus(
        isBluetoothOn: true,
        isLocationOn: true,
        isLocationPermissionGranted: true,
        isWifiOff: false,
        errorMessage: 'Vui lòng TẮT Wi-Fi trước khi quét phòng thi để đảm bảo chế độ thi ngoại tuyến!',
      );
    }

    return const DeviceEnvironmentStatus(
      isBluetoothOn: true,
      isLocationOn: true,
      isLocationPermissionGranted: true,
      isWifiOff: true,
      errorMessage: null,
    );
  }
}
