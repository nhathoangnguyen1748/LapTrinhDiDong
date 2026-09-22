class BleConstants {
  // BLE Service & Characteristic UUIDs
  static const String serviceUuid = '0000fef0-0000-1000-8000-00805f9b34fb';
  static const String charExamDataUuid = '0000fef1-0000-1000-8000-00805f9b34fb';
  static const String charSubmitResultUuid = '0000fef2-0000-1000-8000-00805f9b34fb';

  // RSSI Thresholds (dBm)
  // Standard: RSSI >= -75 dBm (In exam room)
  // Warning: -85 dBm <= RSSI < -75 dBm (Too far from proctor)
  // Out of bounds: RSSI < -85 dBm or disconnected > 10s
  static const int rssiOptimalThreshold = -75;
  static const int rssiWarningThreshold = -85;
  static const int rssiHeartbeatIntervalSeconds = 3;
  static const int maxDisconnectSeconds = 10;
  static const int maxViolationsAllowed = 3;

  // MTU & Chunking
  static const int requestedMtu = 512;
  static const int defaultChunkPayloadSize = 380; // Leaving room for L2CAP/ATT + Chunk header

  // Encryption standard (AES-256)
  static const String defaultExamSecretKey = 'LocalQuizBLE@SecurityKey2026!#@'; // 32 bytes (256-bit)
  static const String defaultExamIv = 'ExamBleIV2026!#@'; // 16 bytes (128-bit)
}
