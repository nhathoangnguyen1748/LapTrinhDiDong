import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/ble_rssi_helper.dart';
import '../../../core/utils/device_environment_helper.dart';
import '../../../providers/ble_providers.dart';
import '../../../services/ble_central_service.dart';
import '../../common/glass_card.dart';
import '../../common/radar_pulse_widget.dart';
import '../../common/rssi_badge.dart';
import 'exam_download_screen.dart';

class DiscoveryRadarScreen extends ConsumerStatefulWidget {
  final bool useSimulator;

  const DiscoveryRadarScreen({super.key, this.useSimulator = false});

  @override
  ConsumerState<DiscoveryRadarScreen> createState() => _DiscoveryRadarScreenState();
}

class _DiscoveryRadarScreenState extends ConsumerState<DiscoveryRadarScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadSavedStudentInfo();
  }

  Future<void> _loadSavedStudentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nameController.text = prefs.getString('saved_student_name') ?? '';
        _studentIdController.text = prefs.getString('saved_student_id') ?? '';
        _classController.text = prefs.getString('saved_student_class') ?? '';
      });
    }
  }

  Future<void> _saveStudentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_student_name', _nameController.text.trim());
    await prefs.setString('saved_student_id', _studentIdController.text.trim());
    await prefs.setString('saved_student_class', _classController.text.trim());
  }

  Future<void> _startScanning() async {
    setState(() => _isScanning = true);
    await BleCentralService.instance.startScan(useMock: widget.useSimulator);
  }

  Future<void> _stopScanning() async {
    setState(() => _isScanning = false);
    await BleCentralService.instance.stopScan();
  }

  Future<void> _onScanButtonPressed() async {
    if (_isScanning) {
      await _stopScanning();
      return;
    }

    final name = _nameController.text.trim();
    final studentId = _studentIdController.text.trim();
    final classroom = _classController.text.trim();

    if (name.isEmpty || studentId.isEmpty || classroom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Vui lòng nhập đầy đủ Họ tên, MSSV và Lớp học trước khi quét')),
            ],
          ),
          backgroundColor: AppColors.rssiCritical,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    await _saveStudentInfo();

    // Check hardware & environment: Bluetooth ON, GPS ON, Wi-Fi OFF
    final env = await DeviceEnvironmentHelper.checkStudentPreConditions();
    if (!env.isReadyToScan) {
      _showRequirementDialog(env.errorMessage ?? 'Chưa đáp ứng đủ điều kiện phòng thi');
      return;
    }

    await _startScanning();
  }

  void _showRequirementDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.rssiCritical, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Điều Kiện Phòng Thi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yêu cầu bắt buộc:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 6),
                  Text('• Bật Bluetooth', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  Text('• Bật Vị trí (GPS)', style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  Text(
                    '• TẮT Wi-Fi (Chế độ phòng thi ngoại tuyến)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.rssiCritical),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÃ HIỂU'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshPage() async {
    await _loadSavedStudentInfo();
    if (_isScanning) {
      await _stopScanning();
      await Future.delayed(const Duration(milliseconds: 300));
      await _startScanning();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã làm mới dữ liệu trang'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _classController.dispose();
    BleCentralService.instance.stopScan();
    super.dispose();
  }

  void _onJoinRoom(DiscoveredExamRoom room) {
    if (_nameController.text.trim().isEmpty || _studentIdController.text.trim().isEmpty || _classController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Vui lòng nhập đầy đủ Họ tên, MSSV và Lớp học trước khi vào phòng thi')),
            ],
          ),
          backgroundColor: AppColors.rssiCritical,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    _saveStudentInfo();

    final pinTextController = TextEditingController();
    String? pinError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.backgroundSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.glassBorder),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pin_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Vui lòng nhập mã PIN do Giám thị cung cấp để tham gia phòng thi:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinTextController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: AppColors.primaryLight,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Nhập mã pin',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      letterSpacing: 2,
                      color: AppColors.textMuted.withOpacity(0.5),
                    ),
                    errorText: pinError,
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onSubmitted: (_) {
                    final enteredPin = pinTextController.text.trim();
                    if (enteredPin.isEmpty) {
                      setDialogState(() => pinError = 'Vui lòng nhập mã PIN');
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    _proceedToDownloadScreen(room, enteredPin);
                  },
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('HỦY', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () {
                  final enteredPin = pinTextController.text.trim();
                  if (enteredPin.isEmpty) {
                    setDialogState(() => pinError = 'Vui lòng nhập mã PIN');
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  _proceedToDownloadScreen(room, enteredPin);
                },
                child: const Text('VÀO PHÒNG', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _proceedToDownloadScreen(DiscoveredExamRoom room, String pin) {
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
          roomPin: pin,
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại trang',
            onPressed: _refreshPage,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Student identity inputs (Họ tên, SBD, Lớp)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên thí sinh',
                        hintText: 'Nhập họ và tên...',
                        labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        hintStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                    Divider(color: AppColors.glassBorder.withOpacity(0.5), height: 10),
                    TextField(
                      controller: _studentIdController,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'SBD / MSSV',
                        hintText: 'Nhập số báo danh / MSSV...',
                        labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        hintStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                    Divider(color: AppColors.glassBorder.withOpacity(0.5), height: 10),
                    TextField(
                      controller: _classController,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Lớp học (VD: CNTT-K18A)',
                        hintText: 'Nhập lớp học...',
                        labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        hintStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nút quét tìm phòng thi (chỉ quét khi đã nhập đủ thông tin và thỏa mãn Bluetooth/Vị trí/Wi-Fi)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  icon: Icon(_isScanning ? Icons.stop_circle_outlined : Icons.radar_rounded, size: 20),
                  label: Text(
                    _isScanning ? 'DỪNG QUÉT PHÒNG THI' : 'QUÉT RADAR TÌM PHÒNG THI',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning ? AppColors.rssiCritical : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _onScanButtonPressed,
                ),
              ),
            ),

            // Animated BLE Radar (Thu nhỏ hoặc ẩn khi bàn phím xuất hiện chống tràn màn hình)
            if (MediaQuery.of(context).viewInsets.bottom == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: RadarPulseWidget(
                  size: MediaQuery.of(context).size.height < 650 ? 130 : 160,
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
                    _isScanning ? 'Đang quét sóng phòng thi...' : 'Chưa bật quét phòng thi',
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
