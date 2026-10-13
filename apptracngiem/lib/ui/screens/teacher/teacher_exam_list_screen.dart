import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/local_exam_storage.dart';
import '../../../core/utils/excel_helper.dart';
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
      // Khi offline, tải danh sách đề thi đã lưu cục bộ
      final downloaded = await LocalExamStorage.getDownloadedExams();
      if (mounted) {
        setState(() {
          _downloadedExamIds = downloaded.map((e) => e.examId).toSet();
          _isLoading = false;
          _errorMessage = downloaded.isNotEmpty
              ? 'Ngoại tuyến: Đang hiển thị ${downloaded.length} đề thi đã lưu trong máy.'
              : 'Lỗi tải đề thi: ${e.toString().replaceAll("Exception: ", "")}';
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
      _showToast('Đã tải đề thi "${examPackage.title}" về máy!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Lỗi khi tải đề thi: $e', isError: true);
    }
  }

  void _startHostingExam(Map<String, dynamic> examInfo) async {
    final examId = examInfo['id'] as String;

    ExamModel? examToHost;
    final downloaded = await LocalExamStorage.getDownloadedExams();
    for (final e in downloaded) {
      if (e.examId == examId) {
        examToHost = e;
        break;
      }
    }

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

  /// Hộp thoại xác nhận và xóa đề thi / phòng thi
  void _confirmDeleteExam(String examId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa đề thi', style: TextStyle(fontSize: 16)),
        content: Text('Bạn có chắc chắn muốn xóa đề thi "$title" ($examId) không? Thao tác này sẽ xóa đề thi khỏi máy và hệ thống.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rssiCritical),
            onPressed: () async {
              Navigator.pop(ctx);
              _handleDeleteExam(examId, title);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteExam(String examId, String title) async {
    setState(() => _isLoading = true);

    // 1. Xóa trong bộ nhớ ngoại tuyến cục bộ
    await LocalExamStorage.deleteDownloadedExam(examId);

    // 2. Xóa trên Server nếu có mạng
    try {
      await ApiService.instance.deleteExam(examId);
    } catch (_) {
      // Khi offline, đã xóa xong cục bộ
    }

    if (!mounted) return;
    setState(() {
      _onlineExams.removeWhere((e) => e['id'] == examId);
      _downloadedExamIds.remove(examId);
      _isLoading = false;
    });

    _showToast('Đã xóa đề thi "$title" thành công!');
  }

  Future<void> _downloadAndShareExcelFile(String examId, String title) async {
    try {
      _showToast('Đang tải và xuất file Excel kết quả nộp bài...');
      final bytes = await ApiService.instance.downloadExcelReport(examId);
      await ExcelHelper.shareOrSaveExcelFile(
        bytes: Uint8List.fromList(bytes),
        filename: 'KetQua_$examId.xlsx',
        title: 'Bảng Điểm Ca Thi: $title',
      );
    } catch (e) {
      _showToast('Lỗi tải file Excel: $e', isError: true);
    }
  }

  void _showReportDialog(String examId, String title) async {
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      ),
    );

    try {
      final report = await ApiService.instance.getExamReport(examId);
      navigator.pop(); // Close loading dialog

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Báo Cáo: $title',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildReportStatCard(
                      'Điểm TB',
                      '${report['average_score']}',
                      Icons.bar_chart_rounded,
                      AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildReportStatCard(
                      'Tỷ lệ Đạt',
                      '${report['pass_rate_percent']}%',
                      Icons.verified_rounded,
                      AppColors.secondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text(
                  'XUẤT FILE EXCEL KẾT QUẢ NỘP BÀI',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _downloadAndShareExcelFile(examId, title);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      navigator.pop();
      _showToast('Chưa có dữ liệu báo cáo trên server: $e', isError: true);
    }
  }

  Widget _buildReportStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            textAlign: TextAlign.center,
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
        titleSpacing: 12,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Ngân Hàng Đề Thi',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadExams,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            icon: const Icon(Icons.logout_rounded, size: 22),
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
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Thẻ Giảng Viên thu gọn (hiển thị đầy đủ thông tin)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 18,
                    child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      teacherName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_onlineExams.length} đề thi',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.rssiWarning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 11, color: AppColors.rssiWarning),
                ),
              ),

            // Danh sách đề thi
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _onlineExams.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted.withOpacity(0.4)),
                              const SizedBox(height: 8),
                              const Text('Chưa có đề thi nào', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _onlineExams.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final exam = _onlineExams[index];
                            final examId = exam['id'] as String;
                            final title = exam['title'] as String;
                            final duration = (exam['duration_seconds'] as int) ~/ 60;
                            final qCount = exam['question_count'] ?? 0;
                            final isDownloaded = _downloadedExamIds.contains(examId);

                            return GlassCard(
                              padding: const EdgeInsets.all(14),
                              borderColor: isDownloaded ? AppColors.secondary.withOpacity(0.4) : AppColors.glassBorder,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDownloaded
                                              ? AppColors.secondary.withOpacity(0.18)
                                              : AppColors.primary.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          examId,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDownloaded ? AppColors.secondary : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isDownloaded)
                                        const Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 14),
                                            SizedBox(width: 4),
                                            Text(
                                              'ĐÃ LƯU MÁY',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(width: 6),
                                      // Nút xóa đề thi
                                      InkWell(
                                        onTap: () => _confirmDeleteExam(examId, title),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.delete_outline_rounded, color: AppColors.rssiCritical, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Hiển thị đầy đủ tên đề thi hài hòa, không cắt ngắn dấu ...
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Text('$duration phút', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      Text('$qCount câu hỏi', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Action Row
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
                                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                        tooltip: 'Xem Điểm & Xuất Excel',
                                        icon: const Icon(Icons.table_view_rounded, color: AppColors.textSecondary, size: 20),
                                        onPressed: () => _showReportDialog(examId, title),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      // Nút thêm đề chỉ hiện dấu + tròn gọn gàng
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        tooltip: 'Thêm Đề Mới (Excel)',
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeacherCreateExamScreen()),
          );
          if (created == true) {
            _loadExams();
          }
        },
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
