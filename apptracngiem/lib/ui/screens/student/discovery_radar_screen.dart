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
  final TextEditingController _classController = TextEditingController(text: 'CNTT-K18A');
  final TextEditingController _pinController = TextEditingController(text: '1234');
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
    _classController.dispose();
    _pinController.dispose();
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
          classroom: _classController.text.trim().isNotEmpty
              ? _classController.text.trim()
              : 'CNTT-K18A',
          roomPin: _pinController.text.trim().isNotEmpty
              ? _pinController.text.trim()
              : '1234',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(discoveredRoomsProvider);
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Tìm Phòng Thi BLE'),
        actions: [
          IconButton(
            tooltip: _isScanning ? 'Dừng quét' : 'Quét lại',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive radar sizing depending on screen height & keyboard presence
            final showBigRadar = !isKeyboardOpen && screenHeight >= 640;
            final radarSize = (screenHeight * 0.20).clamp(110.0, 160.0);

            return Column(
              children: [
                // 1. Thẻ thông tin thí sinh (Tối ưu Padding & Font chống tràn màn hình)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _nameController,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  labelText: 'Họ và tên thí sinh',
                                  labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            Container(width: 1, height: 24, color: AppColors.glassBorder),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _studentIdController,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                decoration: const InputDecoration(
                                  labelText: 'SBD / MSSV',
                                  labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(color: AppColors.glassBorder.withOpacity(0.5), height: 10),
                        Row(
                          children: [
                            const Icon(Icons.class_outlined, size: 18, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _classController,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'Lớp học (VD: CNTT-K18A)',
                                  labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            Container(width: 1, height: 24, color: AppColors.glassBorder),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _pinController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13, color: AppColors.secondary, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  labelText: 'Mã PIN phòng',
                                  labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Animated Radar (Tự động co giãn mượt mà)
                if (showBigRadar)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: RadarPulseWidget(
                      size: radarSize,
                      isScanning: _isScanning,
                    ),
                  ),

                // 3. Scan status bar (Luôn co giãn và không bao giờ tràn mép)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isScanning)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondary,
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                                  begin: const Offset(0.6, 0.6),
                                  end: const Offset(1.3, 1.3),
                                  duration: 800.ms,
                                ),
                          Text(
                            _isScanning ? 'Đang quét sóng phòng thi BLE...' : 'Đã dừng quét sóng',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (widget.useSimulator)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'SIMULATOR',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // 4. Danh sách phòng thi phát hiện được (Scrollable & Responsive)
                Expanded(
                  child: roomsAsync.when(
                    data: (rooms) {
                      if (rooms.isEmpty) {
                        return Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wifi_find_rounded,
                                    size: 42,
                                    color: AppColors.textMuted.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Chưa phát hiện phòng thi BLE nào lân cận',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Đảm bảo máy Giám thị đã bấm "PHÁT SÓNG ĐỀ THI"',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          final distance = BleRssiHelper.estimateDistance(room.rssi);

                          return GlassCard(
                            onTap: () => _onJoinRoom(room),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.12),
                                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                  ),
                                  child: const Icon(
                                    Icons.sensors_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        room.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Khoảng cách: ~${distance}m',
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
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(10),
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
                          ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.08);
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
            );
          },
        ),
      ),
    );
  }
}
