import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/exam_model.dart';
import '../../../models/submission_model.dart';
import '../../common/glass_card.dart';
import '../../common/neumorphic_button.dart';
import 'exam_review_screen.dart';

class ExamResultScreen extends StatelessWidget {
  final SubmissionModel submission;
  final ExamModel? exam;

  const ExamResultScreen({
    super.key,
    required this.submission,
    this.exam,
  });

  @override
  Widget build(BuildContext context) {
    final total = submission.totalQuestions > 0 ? submission.totalQuestions : 1;
    final scoreRatio = (submission.score / total).clamp(0.0, 1.0);
    final score10 = (scoreRatio * 10).toStringAsFixed(1);
    final percent = (scoreRatio * 100).toInt();

    final minutes = submission.timeTakenSeconds ~/ 60;
    final seconds = submission.timeTakenSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết Quả Bài Thi'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // BLE Transmission ACK Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.secondary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Đã Xác Nhận ACK Thành Công',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Biên lai mã hóa: ${submission.receiptHash ?? "ACK-2026-OK"}\nMáy chủ Giám thị đã nhận và ghi nhận bài nộp an toàn.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.1),

              const SizedBox(height: 28),

              // Circular Score Chart
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceCard,
                    border: Border.all(color: AppColors.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: scoreRatio,
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            scoreRatio >= 0.5 ? AppColors.secondary : AppColors.rssiCritical,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$score10 / 10',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$percent% Đúng',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scoreRatio >= 0.5 ? AppColors.secondaryLight : AppColors.rssiCritical,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 28),

              // Statistics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Số câu đúng',
                      value: '${submission.score} / ${submission.totalQuestions}',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Thời gian làm',
                      value: '$minutes p $seconds s',
                      icon: Icons.timelapse_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Số lần vi phạm',
                      value: '${submission.violationCount} / 3',
                      icon: Icons.security_rounded,
                      color: submission.violationCount > 0 ? AppColors.rssiWarning : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Thí sinh / Lớp',
                      value: '${submission.studentName}\n(${submission.classroom ?? "CNTT-K18A"})',
                      icon: Icons.person_rounded,
                      color: AppColors.accentIndigo,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              if (exam != null) ...[
                NeumorphicButton(
                  gradient: AppColors.primaryGradient,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExamReviewScreen(
                          exam: exam!,
                          submission: submission,
                        ),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'XEM LẠI BÀI LÀM CHI TIẾT',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Home Button
              NeumorphicButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'TRỞ VỀ TRANG CHỦ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double? fontSize,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize ?? (value.contains('\n') ? 13 : 16),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
