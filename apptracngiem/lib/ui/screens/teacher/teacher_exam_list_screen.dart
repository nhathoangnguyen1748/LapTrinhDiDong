import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/local_exam_storage.dart';
import '../../../models/exam_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../common/glass_card.dart';
import '../../common/neumorphic_button.dart';
import '../host/host_dashboard_screen.dart';
import 'teacher_create_exam_screen.dart';
import 'teacher_login_screen.dart';

class TeacherExamListScreen extends ConsumerStatefulWidget {
  const TeacherExamListScreen({super.key});

  @override
  ConsumerState<TeacherExamListScreen> createState() => _TeacherExamListScreenState();
}

class _TeacherExamListScreenState extends ConsumerState<TeacherExamListScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _onlineExams = [];
  Set<String> _downloadedExamIds = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final exams = await ApiService.instance.getExams();
      final downloaded = await LocalExamStorage.getDownloadedExams();
      final downloadedIds = downloaded.map((e) => e.examId).toSet();

      if (mounted) {
        setState(() {
          _onlineExams = exams;
          _downloadedExamIds = downloadedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      // If offline, attempt to load local cached exams
      final downloaded = await LocalExamStorage.getDownloadedExams();
      if (mounted) {
        setState(() {
          _downloadedExamIds = downloaded.map((e) => e.examId).toSet();
          _isLoading = false;
          _errorMessage = downloaded.isNotEmpty
              ? 'Không kết nối được Server. Đang hiển thị ${downloaded.length} đề thi ngoại tuyến đã lưu.'
              : 'Lỗi tải đề thi từ Server: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _downloadPackage(String examId) async {
    setState(() => _isLoading = true);
    try {
      final examPackage = await ApiService.instance.downloadExamPackage(examId);
      await LocalExamStorage.saveDownloadedExam(examPackage);
      setState(() {
        _downloadedExamIds.add(examId);
        _isLoading = false;
      });
      _showToast('Đã tải gói đề thi "${examPackage.title}" về máy thành công!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Lỗi khi tải đề thi: $e', isError: true);
    }
  }

  void _startHostingExam(Map<String, dynamic> examInfo) async {
    final examId = examInfo['id'] as String;

    // Check if exam is already saved offline
    ExamModel? examToHost;
    final downloaded = await LocalExamStorage.getDownloadedExams();
    for (final e in downloaded) {
      if (e.examId == examId) {
        examToHost = e;
        break;
      }
    }

    // If not yet downloaded, download first or use sample
    if (examToHost == null) {
      try {
        examToHost = await ApiService.instance.downloadExamPackage(examId);
        await LocalExamStorage.saveDownloadedExam(examToHost);
      } catch (_) {
        examToHost = ExamModel.sampleExam();
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostDashboardScreen(
          selectedExam: examToHost,
          useSimulator: false,
        ),
      ),
    );
  }

  void _showReportDialog(String examId, String title) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      ),
    );

    try {
      final report = await ApiService.instance.getExamReport(examId);
      navigator.pop(); // Close loading

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.backgroundSecondary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Báo Cáo: $title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildReportStatCard(
                        'Tổng bài nộp',
                        '${report['total_submissions']}',
                        Icons.assignment_turned_in_rounded,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildReportStatCard(
                        'Điểm TB (Hệ 10)',
                        '${report['average_score']}',
                        Icons.bar_chart_rounded,
                        AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildReportStatCard(
                        'Tỷ lệ Đạt (>=5.0)',
                        '${report['pass_rate_percent']}%',
                        Icons.verified_rounded,
                        AppColors.secondaryLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildReportStatCard(
                        'Tổng vi phạm',
                        '${report['total_violations']}',
                        Icons.warning_amber_rounded,
                        AppColors.rssiWarning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download_rounded, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tải file Excel bảng điểm tại:\n${ApiService.instance.baseUrl}/exams/$examId/export-excel',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      navigator.pop(); // Close loading
      messenger.showSnackBar(
        SnackBar(
          content: Text('Không thể lấy báo cáo: $e'),
          backgroundColor: AppColors.rssiCritical,
        ),
      );
    }
  }

  Widget _buildReportStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.rssiCritical : AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final teacherName = authState.user?['full_name'] ?? 'Giảng viên';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngân Hàng Đề Thi Cloud'),
        actions: [
          IconButton(
            tooltip: 'Tạo đề thi mới / Nạp JSON',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.secondary),
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherCreateExamScreen()),
              );
              if (created == true) {
                _loadExams();
              }
            },
          ),
          IconButton(
            tooltip: 'Tải lại danh sách đề',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadExams,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const TeacherLoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Teacher Profile Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 22,
                    child: Icon(Icons.school_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacherName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Khâu 1: Chuẩn bị đề thi trước ca thi',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rssiWarning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.rssiWarning.withOpacity(0.4)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: AppColors.rssiWarning),
                ),
              ),

            // Exam List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _onlineExams.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                              const SizedBox(height: 12),
                              const Text('Chưa có đề thi nào trên Server', style: TextStyle(color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: _onlineExams.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final exam = _onlineExams[index];
                            final examId = exam['id'] as String;
                            final title = exam['title'] as String;
                            final duration = (exam['duration_seconds'] as int) ~/ 60;
                            final qCount = exam['question_count'] ?? 0;
                            final isDownloaded = _downloadedExamIds.contains(examId);

                            return GlassCard(
                              padding: const EdgeInsets.all(16),
                              borderColor: isDownloaded ? AppColors.secondary.withOpacity(0.4) : AppColors.glassBorder,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDownloaded
                                              ? AppColors.secondary.withOpacity(0.18)
                                              : AppColors.primary.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          examId,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDownloaded ? AppColors.secondary : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isDownloaded)
                                        const Row(
                                          children: [
                                            Icon(Icons.offline_pin_rounded, color: AppColors.secondary, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              'SẴN SÀNG OFFLINE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text('$duration phút', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                      const SizedBox(width: 14),
                                      const Icon(Icons.quiz_outlined, size: 14, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text('$qCount câu hỏi', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Action Buttons Row
                                  Row(
                                    children: [
                                      if (!isDownloaded)
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.download_rounded, size: 16),
                                            label: const Text('Tải về máy', style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.primary,
                                              side: const BorderSide(color: AppColors.primary),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: () => _downloadPackage(examId),
                                          ),
                                        )
                                      else
                                        Expanded(
                                          child: NeumorphicButton(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            gradient: AppColors.emeraldGradient,
                                            onPressed: () => _startHostingExam(exam),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                                SizedBox(width: 4),
                                                Text(
                                                  'PHÁT PHÒNG THI',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Xem Báo Cáo & Thống Kê',
                                        icon: const Icon(Icons.insights_rounded, color: AppColors.textSecondary),
                                        onPressed: () => _showReportDialog(examId, title),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.05);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tạo Đề Mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeacherCreateExamScreen()),
          );
          if (created == true) {
            _loadExams();
          }
        },
      ),
    );
  }
}
