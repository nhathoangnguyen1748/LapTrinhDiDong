import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/permission_helper.dart';
import '../../providers/auth_provider.dart';
import '../common/glass_card.dart';
import 'student/discovery_radar_screen.dart';
import 'teacher/teacher_login_screen.dart';
import 'teacher/teacher_exam_list_screen.dart';

class HomeRoleSelectScreen extends ConsumerStatefulWidget {
  const HomeRoleSelectScreen({super.key});

  @override
  ConsumerState<HomeRoleSelectScreen> createState() => _HomeRoleSelectScreenState();
}

class _HomeRoleSelectScreenState extends ConsumerState<HomeRoleSelectScreen> {
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
                color: AppColors.primary.withOpacity(0.08),
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
                color: AppColors.secondary.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // App Logo & Badge
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.wifi_tethering_rounded,
                        color: Colors.white,
                        size: 46,
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

                  const SizedBox(height: 32),

                  // Permissions Check Card
                  if (!_hasPermission) ...[
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
                    const SizedBox(height: 20),
                  ],

                  // Role 1: Student / Examinee
                  GlassCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DiscoveryRadarScreen(useSimulator: false),
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
                          child: Text(
                            'Vào Thi (Thí Sinh)',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ).animate().slideX(begin: -0.1, duration: 400.ms).fadeIn(),

                  const SizedBox(height: 18),

                  // Role 2: Teacher / Proctor
                  GlassCard(
                    onTap: () {
                      final authState = ref.read(authProvider);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => authState.isLoggedIn
                              ? const TeacherExamListScreen()
                              : const TeacherLoginScreen(),
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
                          child: Text(
                            'Khu Vực Giảng Viên',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ).animate().slideX(begin: 0.1, duration: 400.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
