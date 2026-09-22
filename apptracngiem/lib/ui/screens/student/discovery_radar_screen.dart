import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/ble_rssi_helper.dart';
import '../../../providers/ble_providers.dart';
import '../../../services/ble_central_service.dart';
import '../../common/glass_card.dart';
import '../../common/radar_pulse_widget.dart';
import '../../common/rssi_badge.dart';
import 'exam_download_screen.dart';

class DiscoveryRadarScreen extends ConsumerStatefulWidget {
  final bool useSimulator;

  const DiscoveryRadarScreen({super.key, this.useSimulator = true});

  @override
  ConsumerState<DiscoveryRadarScreen> createState() => _DiscoveryRadarScreenState();
}

class _DiscoveryRadarScreenState extends ConsumerState<DiscoveryRadarScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Nguyễn Văn An');
  final TextEditingController _studentIdController = TextEditingController(text: 'TS-2026-001');
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  Future<void> _startScanning() async {
    setState(() => _isScanning = true);
    await BleCentralService.instance.startScan(useMock: widget.useSimulator);
  }

  Future<void> _stopScanning() async {
    setState(() => _isScanning = false);
    await BleCentralService.instance.stopScan();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    BleCentralService.instance.stopScan();
    super.dispose();
  }

  void _onJoinRoom(DiscoveredExamRoom room) {
    _stopScanning();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamDownloadScreen(
          room: room,
          studentName: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : 'Thí sinh',
          studentId: _studentIdController.text.trim().isNotEmpty
              ? _studentIdController.text.trim()
              : 'TS-001',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(discoveredRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm Phòng Thi BLE'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.sync_rounded : Icons.refresh_rounded),
            onPressed: () {
              if (_isScanning) {
                _stopScanning();
              } else {
                _startScanning();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Student identity inputs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                          labelStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 28, color: AppColors.glassBorder),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _studentIdController,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'SBD / MSSV',
                          labelStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Animated BLE Radar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: RadarPulseWidget(
                size: 200,
                isScanning: _isScanning,
              ),
            ),

            // Scan status title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isScanning ? 'Đang quét sóng phòng thi...' : 'Đã dừng quét',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (widget.useSimulator)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SIMULATOR',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Discovered Rooms List
            Expanded(
              child: roomsAsync.when(
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_find_rounded,
                            size: 48,
                            color: AppColors.textMuted.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Chưa phát hiện phòng thi BLE nào lân cận',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Đảm bảo máy Giám thị đã bật phát sóng đề thi',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      final distance = BleRssiHelper.estimateDistance(room.rssi);

                      return GlassCard(
                        onTap: () => _onJoinRoom(room),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: const Icon(
                                Icons.sensors_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Khoảng cách ước tính: ~${distance}m',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                RssiBadge(rssi: room.rssi, isCompact: true),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Vào thi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Lỗi quét BLE: $e', style: const TextStyle(color: AppColors.rssiCritical)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
