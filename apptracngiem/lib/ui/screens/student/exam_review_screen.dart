import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/exam_model.dart';
import '../../../models/submission_model.dart';
import '../../common/glass_card.dart';

class ExamReviewScreen extends StatelessWidget {
  final ExamModel exam;
  final SubmissionModel submission;

  const ExamReviewScreen({
    super.key,
    required this.exam,
    required this.submission,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem Lại Chi Tiết Bài Thi'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: exam.questions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final q = exam.questions[index];
            final studentAnswer = submission.answers[q.id];
            final correctAnswer = q.correctOptionId;
            final isCorrect = studentAnswer != null && studentAnswer == correctAnswer;
            final isSkipped = studentAnswer == null;

            Color statusColor;
            String statusText;
            IconData statusIcon;

            if (isSkipped) {
              statusColor = AppColors.rssiWarning;
              statusText = 'Chưa trả lời';
              statusIcon = Icons.help_outline_rounded;
            } else if (isCorrect) {
              statusColor = AppColors.secondary;
              statusText = 'Chính xác';
              statusIcon = Icons.check_circle_rounded;
            } else {
              statusColor = AppColors.rssiCritical;
              statusText = 'Sai';
              statusIcon = Icons.cancel_rounded;
            }

            return GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: statusColor.withOpacity(0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header câu hỏi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CÂU HỎI ${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    q.content,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Danh sách các phương án A, B, C, D
                  ...q.options.map((opt) {
                    final isUserPick = studentAnswer == opt.id;
                    final isCorrectOpt = correctAnswer == opt.id;

                    Color optBg = AppColors.surfaceCard;
                    Color optBorder = AppColors.glassBorder;
                    Color optText = AppColors.textSecondary;
                    Widget? trailingBadge;

                    if (isCorrectOpt) {
                      optBg = AppColors.secondary.withOpacity(0.18);
                      optBorder = AppColors.secondary;
                      optText = AppColors.textPrimary;
                      trailingBadge = const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, color: AppColors.secondary, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Đáp án đúng',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      );
                    } else if (isUserPick && !isCorrect) {
                      optBg = AppColors.rssiCritical.withOpacity(0.18);
                      optBorder = AppColors.rssiCritical;
                      optText = AppColors.textPrimary;
                      trailingBadge = const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, color: AppColors.rssiCritical, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Lựa chọn của bạn',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.rssiCritical,
                            ),
                          ),
                        ],
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: optBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: optBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUserPick
                                  ? (isCorrect ? AppColors.secondary : AppColors.rssiCritical)
                                  : (isCorrectOpt ? AppColors.secondary : AppColors.background),
                              border: (isUserPick || isCorrectOpt)
                                  ? null
                                  : Border.all(color: AppColors.glassBorder),
                            ),
                            child: Text(
                              opt.id,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (isUserPick || isCorrectOpt) ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              opt.text,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: (isUserPick || isCorrectOpt) ? FontWeight.w600 : FontWeight.normal,
                                color: optText,
                              ),
                            ),
                          ),
                          ?trailingBadge,
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.05);
          },
        ),
      ),
    );
  }
}
