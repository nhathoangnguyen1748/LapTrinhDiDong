import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_central_service.dart';
import '../services/ble_peripheral_service.dart';
import '../models/submission_model.dart';

final discoveredRoomsProvider = StreamProvider.autoDispose<List<DiscoveredExamRoom>>((ref) {
  return BleCentralService.instance.roomsStream;
});

final downloadProgressProvider = StreamProvider.autoDispose<double>((ref) {
  return BleCentralService.instance.downloadProgressStream;
});

final hostSubmissionsProvider = StreamProvider.autoDispose<List<SubmissionModel>>((ref) {
  return BlePeripheralService.instance.submissionsStream;
});
