import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/permission_helper.dart';
import '../common/glass_card.dart';
import 'student/discovery_radar_screen.dart';
import 'host/host_dashboard_screen.dart';

class HomeRoleSelectScreen extends StatefulWidget {
  const HomeRoleSelectScreen({super.key});

  @override
  State<HomeRoleSelectScreen> createState() => _HomeRoleSelectScreenState();
}

class _HomeRoleSelectScreenState extends State<HomeRoleSelectScreen> {
  bool _useSimulator = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final granted = await PermissionHelper.hasBlePermissions();
    if (mounted) {
      setState(() => _hasPermission = granted);
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await PermissionHelper.requestBlePermissions();
    if (mounted) {
      setState(() => _hasPermission = granted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Đã cấp đầy đủ quyền BLE & Vị trí!'
                : 'Cần cấp quyền Bluetooth để quét và phát phòng thi.',
          ),
          backgroundColor: granted ? AppColors.secondary : AppColors.rssiCritical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background ambient gradient circles
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.15),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // App Logo & Badge
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.wifi_tethering_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  )
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.easeOutBack)
                      .fadeIn(),

                  const SizedBox(height: 20),

                  // App Name
                  const Center(
                    child: Text(
                      'LocalQuiz BLE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 8),

                  const Center(
                    child: Text(
                      'Hệ Thống Thi Trắc Nghiệm BLE Ngoại Tuyến\nĐịnh Vị Vùng Làm Bài Bằng RSSI Geofencing',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 28),

                  // Simulator / Hardware Mode Toggle Card
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          _useSimulator ? Icons.science_rounded : Icons.bluetooth_rounded,
                          color: _useSimulator ? AppColors.primary : AppColors.secondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _useSimulator ? 'Chế độ Mô phỏng (Simulator)' : 'BLE Phần cứng (Hardware)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _useSimulator
                                    ? 'Kiểm thử toàn diện mạng & RSSI mà không cần 2 máy thật'
                                    : 'Sử dụng chip BLE vật lý của điện thoại',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _useSimulator,
                          onChanged: (val) => setState(() => _useSimulator = val),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 16),

                  // Permissions Check Card
                  if (!_hasPermission && !_useSimulator)
                    GlassCard(
                      borderColor: AppColors.rssiWarning.withOpacity(0.5),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.rssiWarning, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Cần cấp quyền Bluetooth & Vị trí để quét phòng thi',
                              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: _requestPermissions,
                            child: const Text('Cấp quyền', style: TextStyle(color: AppColors.rssiWarning, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Role 1: Student / Examinee
                  GlassCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiscoveryRadarScreen(useSimulator: _useSimulator),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppColors.primaryGradient,
                          ),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vào Thi (Thí Sinh)',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Quét radar tìm phòng thi BLE, nhận đề thi mã hóa, giám sát vùng an toàn RSSI',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ).animate().slideX(begin: -0.1, duration: 400.ms).fadeIn(),

                  const SizedBox(height: 16),

                  // Role 2: Host / Proctor
                  GlassCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HostDashboardScreen(useSimulator: _useSimulator),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppColors.emeraldGradient,
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Phát Đề (Giám Thị)',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Mở GATT Server phát đề qua BLE, giám sát thí sinh và nhận bài nộp trực tiếp',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ).animate().slideX(begin: 0.1, duration: 400.ms).fadeIn(),

                  const SizedBox(height: 32),

                  // Technical Specifications Highlights
                  const Center(
                    child: Text(
                      'BẢO MẬT & KIẾN TRÚC BLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildFeaturePill(Icons.lock_rounded, 'AES-256 + GZip'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFeaturePill(Icons.radar_rounded, 'Geofence RSSI'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFeaturePill(Icons.security_rounded, 'Kiosk Anti-Cheat'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
