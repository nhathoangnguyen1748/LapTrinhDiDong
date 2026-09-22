import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/ble_constants.dart';
import '../core/utils/ble_rssi_helper.dart';
import '../services/ble_central_service.dart';
import '../services/mock_ble_service.dart';

class GeofenceState {
  final int? rssi;
  final RssiStatus status;
  final double distanceMeters;
  final double signalQuality;
  final bool isOutOfBounds;
  final DateTime? lastSeen;
  final int disconnectedSeconds;

  const GeofenceState({
    this.rssi,
    this.status = RssiStatus.disconnected,
    this.distanceMeters = 0.0,
    this.signalQuality = 0.0,
    this.isOutOfBounds = false,
    this.lastSeen,
    this.disconnectedSeconds = 0,
  });

  GeofenceState copyWith({
    int? rssi,
    RssiStatus? status,
    double? distanceMeters,
    double? signalQuality,
    bool? isOutOfBounds,
    DateTime? lastSeen,
    int? disconnectedSeconds,
  }) {
    return GeofenceState(
      rssi: rssi ?? this.rssi,
      status: status ?? this.status,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      signalQuality: signalQuality ?? this.signalQuality,
      isOutOfBounds: isOutOfBounds ?? this.isOutOfBounds,
      lastSeen: lastSeen ?? this.lastSeen,
      disconnectedSeconds: disconnectedSeconds ?? this.disconnectedSeconds,
    );
  }
}

class GeofenceNotifier extends StateNotifier<GeofenceState> {
  StreamSubscription<int>? _rssiSubscription;
  Timer? _disconnectCheckTimer;

  GeofenceNotifier() : super(const GeofenceState()) {
    _initRssiListener();
  }

  void _initRssiListener() {
    _rssiSubscription = BleCentralService.instance.rssiStream.listen((rssi) {
      updateRssi(rssi);
    });
  }

  void updateRssi(int rssi) {
    final status = BleRssiHelper.getStatus(rssi, isConnected: true);
    final distance = BleRssiHelper.estimateDistance(rssi);
    final signal = BleRssiHelper.getSignalPercentage(rssi);
    final isOut = status == RssiStatus.critical;

    state = state.copyWith(
      rssi: rssi,
      status: status,
      distanceMeters: distance,
      signalQuality: signal,
      isOutOfBounds: isOut,
      lastSeen: DateTime.now(),
      disconnectedSeconds: 0,
    );

    if (_disconnectCheckTimer == null || !_disconnectCheckTimer!.isActive) {
      _startDisconnectMonitor();
    }
  }

  /// Simulate manual RSSI (for testing slider)
  void setManualRssi(int rssi) {
    MockBleService.instance.setSimulatedRssi(rssi);
    updateRssi(rssi);
  }

  void _startDisconnectMonitor() {
    _disconnectCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.lastSeen != null) {
        final elapsed = DateTime.now().difference(state.lastSeen!).inSeconds;
        if (elapsed >= BleConstants.maxDisconnectSeconds) {
          // Disconnected for more than 10s -> trigger out of bounds lock!
          state = state.copyWith(
            status: RssiStatus.disconnected,
            isOutOfBounds: true,
            disconnectedSeconds: elapsed,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _rssiSubscription?.cancel();
    _disconnectCheckTimer?.cancel();
    super.dispose();
  }
}

final geofenceProvider = StateNotifierProvider<GeofenceNotifier, GeofenceState>((ref) {
  return GeofenceNotifier();
});
