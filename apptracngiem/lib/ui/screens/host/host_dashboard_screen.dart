import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/ble_constants.dart';
import '../../../models/exam_model.dart';
import '../../../models/submission_model.dart';
import '../../../providers/ble_providers.dart';
import '../../../services/ble_peripheral_service.dart';
import '../../common/glass_card.dart';
import '../../common/neumorphic_button.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  final bool useSimulator;

  const HostDashboardScreen({super.key, this.useSimulator = true});

  @override
  ConsumerState<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  final ExamModel _exam = ExamModel.sampleExam();
  bool _isAdvertising = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isAdvertising = BlePeripheralService.instance.isAdvertising;
  }

  Future<void> _toggleAdvertising() async {
    setState(() => _isLoading = true);

    if (_isAdvertising) {
      await BlePeripheralService.instance.stopHosting();
      if (!mounted) return;
      setState(() {
        _isAdvertising = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã dừng phát phòng thi BLE')),
      );
    } else {
      final success = await BlePeripheralService.instance.startHosting(
        _exam,
        isMock: widget.useSimulator,
      );
      if (!mounted) return;
      setState(() {
        _isAdvertising = success;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Đang phát sóng phòng thi BLE với Service UUID: ${BleConstants.serviceUuid.substring(0, 8)}...'
                : 'Không thể khởi động BLE Peripheral trên thiết bị này.',
          ),
          backgroundColor: success ? AppColors.secondary : AppColors.rssiCritical,
        ),
      );
    }
  }

  void _simulateIncomingSubmission() {
    final mockSub = SubmissionModel(
      examId: _exam.examId,
      studentId: 'TS-2026-${(DateTime.now().millisecond % 900) + 100}',
      studentName: 'Trần Thị Mai',
      answers: {1: 'A', 2: 'B', 3: 'B', 4: 'A', 5: 'B', 6: 'B'},
      submittedAt: DateTime.now(),
      timeTakenSeconds: 840,
      score: 6,
      totalQuestions: 6,
      violationCount: 0,
    );
    BlePeripheralService.instance.addSubmission(mockSub);
  }

  @override
  Widget build(BuildContext context) {
    final submissionsAsync = ref.watch(hostSubmissionsProvider);
    final submissions = submissionsAsync.valueOrNull ?? BlePeripheralService.instance.receivedSubmissions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giám Thị - Quản Trị Phòng Thi'),
        actions: [
          if (widget.useSimulator)
            IconButton(
              tooltip: 'Mô phỏng 1 bài nộp',
              icon: const Icon(Icons.add_task_rounded, color: AppColors.primary),
              onPressed: _simulateIncomingSubmission,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Host Status Broadcast Card
              GlassCard(
                borderColor: _isAdvertising ? AppColors.secondary : AppColors.glassBorder,
                color: _isAdvertising ? AppColors.secondary.withOpacity(0.1) : AppColors.surfaceCard,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isAdvertising ? AppColors.secondary : AppColors.textMuted).withOpacity(0.15),
                          ),
                          child: Icon(
                            _isAdvertising ? Icons.podcasts_rounded : Icons.cell_tower_rounded,
                            color: _isAdvertising ? AppColors.secondary : AppColors.textMuted,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isAdvertising ? 'ĐANG PHÁT SÓNG GATT SERVER' : 'CHƯA PHÁT PHÒNG THI',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _isAdvertising ? AppColors.secondary : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _exam.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHostMeta(Icons.access_time_rounded, '${_exam.durationSeconds ~/ 60} phút'),
                        _buildHostMeta(Icons.quiz_rounded, '${_exam.questions.length} câu'),
                        _buildHostMeta(Icons.radar_rounded, 'Ngưỡng: ${_exam.rssiThreshold} dBm'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NeumorphicButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      gradient: _isAdvertising ? AppColors.criticalGradient : AppColors.emeraldGradient,
                      isLoading: _isLoading,
                      onPressed: _toggleAdvertising,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isAdvertising ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isAdvertising ? 'DỪNG PHÁT SÓNG BLE' : 'PHÁT SÓNG ĐỀ THI BLE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Submissions list header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bài thi đã nhận (${submissions.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Text(
                      'Live BLE Stream',
                      style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Submissions List
              Expanded(
                child: submissions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                            const SizedBox(height: 10),
                            const Text(
                              'Chưa có thí sinh nào nộp bài',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            if (widget.useSimulator) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'Bấm biểu đồ dấu + trên góc phải để thử nhận 1 bài nộp',
                                style: TextStyle(color: AppColors.primary, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: submissions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sub = submissions[index];
                          final ratio = sub.totalQuestions > 0 ? (sub.score / sub.totalQuestions) : 0.0;
                          final score10 = (ratio * 10).toStringAsFixed(1);

                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ratio >= 0.5
                                        ? AppColors.secondary.withOpacity(0.15)
                                        : AppColors.rssiCritical.withOpacity(0.15),
                                  ),
                                  child: Text(
                                    score10,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: ratio >= 0.5 ? AppColors.secondary : AppColors.rssiCritical,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sub.studentName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'SBD: ${sub.studentId} • Làm: ${sub.timeTakenSeconds ~/ 60}p ${sub.timeTakenSeconds % 60}s',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (sub.violationCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.rssiCritical.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${sub.violationCount} Vi phạm',
                                      style: const TextStyle(fontSize: 10, color: AppColors.rssiCritical, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.05);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostMeta(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
