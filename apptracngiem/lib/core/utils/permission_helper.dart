import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Request all permissions required for Bluetooth Low Energy operation
  static Future<bool> requestBlePermissions() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      // For Android 12+ (API 31+)
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      await Permission.bluetoothAdvertise.request();
      await Permission.locationWhenInUse.request();

      final isScanGranted = scanStatus.isGranted || scanStatus.isLimited;
      final isConnectGranted = connectStatus.isGranted || connectStatus.isLimited;

      // On Android 12+, scan & connect are mandatory.
      return isScanGranted && isConnectGranted;
    } else if (Platform.isIOS) {
      final bluetoothStatus = await Permission.bluetooth.request();
      return bluetoothStatus.isGranted;
    }

    return true;
  }

  /// Check if Bluetooth permissions are currently granted
  static Future<bool> hasBlePermissions() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final scanGranted = await Permission.bluetoothScan.isGranted;
      final connectGranted = await Permission.bluetoothConnect.isGranted;
      return scanGranted && connectGranted;
    } else if (Platform.isIOS) {
      return Permission.bluetooth.isGranted;
    }

    return true;
  }
}
