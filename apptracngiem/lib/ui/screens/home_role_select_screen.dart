import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/storage/local_exam_storage.dart';
import '../../core/utils/permission_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_session_provider.dart';
import '../common/glass_card.dart';
import 'host/host_dashboard_screen.dart';
import 'student/discovery_radar_screen.dart';
import 'student/exam_taking_screen.dart';
import 'student/exam_result_screen.dart';
import 'teacher/teacher_login_screen.dart';
import 'teacher/teacher_exam_list_screen.dart';
import '../../services/ble_central_service.dart';

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
    _checkActiveSessions();
  }

  Future<void> _checkActiveSessions() async {
    // 1. Kiểm tra phiên thi của Thí sinh (nếu thoát app khi đang làm bài)
    final studentSession = await LocalExamStorage.getActiveStudentSession();
    if (studentSession != null && mounted) {
      final now = DateTime.now();
      final remaining = studentSession.examEndTime.difference(now).inSeconds;

      // Sinh viên mở lại app sau khi thoát:
      // Tự động khôi phục kết nối BLE trong nền
      if (studentSession.deviceRemoteId != null || studentSession.isMock) {
        BleCentralService.instance.reconnectToDevice(
          remoteId: studentSession.deviceRemoteId,
          isMock: studentSession.isMock,
        ).then((connected) {
          debugPrint('[SessionRestore] Reconnect BLE result: $connected');
          // Gửi cảnh báo vi phạm về máy Giám thị
          BleCentralService.instance.sendCandidateViolation(
            studentId: studentSession.studentId,
            violationCount: studentSession.violationCount + 1,
            alertMessage: 'Rời khỏi ứng dụng khi đang làm bài',
          );
        });
      }

      await ref.read(examSessionProvider.notifier).restoreSession(
        studentSession,
        additionalViolations: 1,
      );

      if (!mounted) return;

      final sessionState = ref.read(examSessionProvider);

      // Nếu bài thi đã nộp (do hết giờ HOẶC do vi phạm >= 3 và Giám thị bật tự nộp)
      if (sessionState.isSubmitted && sessionState.submission != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remaining <= 0
                        ? 'Đã hết thời gian làm bài! Bài thi đã tự động nộp.'
                        : 'Bài thi đã tự động nộp do vi phạm quy chế (${sessionState.violationCount}/3 lần)!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.rssiCritical,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExamResultScreen(
              submission: sessionState.submission!,
              exam: studentSession.exam,
            ),
          ),
        );
        return;
      }

      // Ngược lại nếu chưa nộp (còn giờ và vi phạm < 3, HOẶC vi phạm >= 3 nhưng Giám thị TẮT tự nộp)
      if (remaining > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sessionState.violationCount >= 3
                        ? 'Cảnh báo: Bạn đã vi phạm ${sessionState.violationCount} lần quy chế thi!'
                        : 'Đã khôi phục bài thi! Bạn bị tính 1 lần vi phạm do thoát app (${sessionState.violationCount}/3 lần).',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: sessionState.violationCount >= 3 ? AppColors.rssiCritical : AppColors.rssiWarning,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExamTakingScreen(
              exam: studentSession.exam,
              classroom: studentSession.classroom,
            ),
          ),
        );
        return;
      }
    }

    // 2. Kiểm tra phiên giám thị ca thi của Giảng viên (nếu thoát app khi đang giám thị)
    final hostSession = await LocalExamStorage.getActiveHostSession();
    if (hostSession != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Đang tiếp tục ca thi: ${hostSession.exam.title}'),
              ),
            ],
          ),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HostDashboardScreen(
            selectedExam: hostSession.exam,
            useSimulator: false,
          ),
        ),
      );
    }
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
