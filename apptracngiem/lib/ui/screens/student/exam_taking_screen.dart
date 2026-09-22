import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/exam_model.dart';
import '../../../providers/exam_session_provider.dart';
import '../../../providers/proximity_geofence_provider.dart';
import '../../common/glass_card.dart';
import '../../common/neumorphic_button.dart';
import '../../common/out_of_bounds_overlay.dart';
import '../../common/rssi_badge.dart';
import 'exam_result_screen.dart';

class ExamTakingScreen extends ConsumerStatefulWidget {
  final ExamModel exam;

  const ExamTakingScreen({super.key, required this.exam});

  @override
  ConsumerState<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends ConsumerState<ExamTakingScreen> {
  @override
  Widget build(BuildContext context) {
    final examSession = ref.watch(examSessionProvider);
    final geofence = ref.watch(geofenceProvider);

    // Sync Geofence out-of-bounds state with timer freeze
    ref.listen<GeofenceState>(geofenceProvider, (_, next) {
      ref.read(examSessionProvider.notifier).setTimerPaused(next.isOutOfBounds);
    });

    // Auto-navigate to result screen when submitted
    ref.listen<ExamSessionState>(examSessionProvider, (_, next) {
      if (next.isSubmitted && next.submission != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExamResultScreen(submission: next.submission!),
          ),
        );
      }
    });

    final questions = widget.exam.questions;
    final currentIndex = examSession.currentQuestionIndex.clamp(0, questions.length - 1);
    final currentQuestion = questions.isNotEmpty ? questions[currentIndex] : null;
    final selectedOption = currentQuestion != null ? examSession.answers[currentQuestion.id] : null;
    final isFlagged = currentQuestion != null && examSession.flaggedQuestions.contains(currentQuestion.id);

    return WillPopScope(
      onWillPop: () async {
        _showExitConfirmation(context);
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Header: Timer, RSSI Badge, Violations
                  _buildHeader(context, examSession, geofence),

                  // Kiosk Violation Warning Banner
                  if (examSession.violationCount > 0)
                    _buildViolationBanner(examSession),

                  // Question Palette Navigator
                  _buildQuestionPalette(examSession, questions.length),

                  // Question Content & Options
                  Expanded(
                    child: currentQuestion != null
                        ? _buildQuestionContent(currentQuestion, selectedOption, isFlagged)
                        : const Center(child: Text('Không có câu hỏi')),
                  ),

                  // Bottom Action Bar
                  _buildBottomBar(context, examSession, questions.length, currentQuestion),
                ],
              ),
            ),

            // Out Of Bounds Frozen Overlay (Lock Screen when RSSI < -85 dBm)
            const OutOfBoundsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ExamSessionState session, GeofenceState geofence) {
    final minutes = session.remainingSeconds ~/ 60;
    final seconds = session.remainingSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isLowTime = session.remainingSeconds < 300; // Under 5 minutes

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Live BLE RSSI Badge
          RssiBadge(rssi: geofence.rssi, isCompact: false),

          // Timer circular badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: isLowTime ? AppColors.criticalGradient : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isLowTime ? AppColors.rssiCritical : AppColors.primary).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  session.isTimerPaused ? Icons.pause_circle_filled_rounded : Icons.timer_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  session.isTimerPaused ? 'ĐÃ ĐÓNG BĂNG' : timeStr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Question Palette Trigger Button
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, color: AppColors.textPrimary),
            onPressed: () => _showPaletteBottomSheet(context, session),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationBanner(ExamSessionState session) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.rssiCritical.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.rssiCritical.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.rssiCritical, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cảnh báo quy chế: Vi phạm ${session.violationCount}/3 lần. Rời app thêm sẽ bị tự nộp bài!',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.rssiCritical),
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 400.ms);
  }

  Widget _buildQuestionPalette(ExamSessionState session, int totalQuestions) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: totalQuestions,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isCurrent = index == session.currentQuestionIndex;
          final qId = widget.exam.questions[index].id;
          final isAnswered = session.answers.containsKey(qId);
          final isFlagged = session.flaggedQuestions.contains(qId);

          Color bgColor;
          Color borderColor;
          Color textColor;

          if (isCurrent) {
            bgColor = AppColors.primary;
            borderColor = AppColors.primaryLight;
            textColor = Colors.white;
          } else if (isAnswered) {
            bgColor = AppColors.secondary.withOpacity(0.2);
            borderColor = AppColors.secondary;
            textColor = AppColors.secondaryLight;
          } else {
            bgColor = AppColors.surfaceCard;
            borderColor = AppColors.glassBorder;
            textColor = AppColors.textSecondary;
          }

          return GestureDetector(
            onTap: () => ref.read(examSessionProvider.notifier).goToQuestion(index),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  if (isFlagged)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.rssiWarning,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionContent(QuestionModel question, String? selectedOption, bool isFlagged) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CÂU HỎI ${question.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (isFlagged)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.rssiWarning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.rssiWarning.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.flag_rounded, size: 12, color: AppColors.rssiWarning),
                            SizedBox(width: 4),
                            Text(
                              'Xem lại',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.rssiWarning),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  question.content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ).animate(key: ValueKey(question.id)).fadeIn(duration: 250.ms).slideY(begin: 0.05),

          const SizedBox(height: 16),

          // Options List (A, B, C, D)
          ...question.options.map((opt) {
            final isSelected = selectedOption == opt.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                onTap: () {
                  ref.read(examSessionProvider.notifier).selectAnswer(question.id, opt.id);
                },
                color: isSelected
                    ? AppColors.primary.withOpacity(0.18)
                    : AppColors.surfaceCard,
                borderColor: isSelected
                    ? AppColors.primary
                    : AppColors.glassBorder,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.08),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryLight : AppColors.glassBorder,
                        ),
                      ),
                      child: Text(
                        opt.id,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        opt.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                          .animate()
                          .scale(duration: 200.ms),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ExamSessionState session,
    int totalQuestions,
    QuestionModel? currentQuestion,
  ) {
    final isFirst = session.currentQuestionIndex == 0;
    final isLast = session.currentQuestionIndex == totalQuestions - 1;
    final isFlagged = currentQuestion != null && session.flaggedQuestions.contains(currentQuestion.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          // Previous button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: isFirst ? null : () => ref.read(examSessionProvider.notifier).previousQuestion(),
            color: isFirst ? AppColors.textMuted.withOpacity(0.3) : AppColors.textPrimary,
          ),

          // Bookmark / Flag button
          IconButton(
            icon: Icon(
              isFlagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
              color: isFlagged ? AppColors.rssiWarning : AppColors.textMuted,
            ),
            onPressed: currentQuestion != null
                ? () => ref.read(examSessionProvider.notifier).toggleFlag(currentQuestion.id)
                : null,
          ),

          const Spacer(),

          // Next or Submit Button
          if (!isLast)
            NeumorphicButton(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              onPressed: () => ref.read(examSessionProvider.notifier).nextQuestion(),
              child: const Row(
                children: [
                  Text('Câu tiếp theo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ],
              ),
            )
          else
            NeumorphicButton(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              gradient: AppColors.emeraldGradient,
              onPressed: () => _showSubmitConfirmation(context, session, totalQuestions),
              child: const Row(
                children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'NỘP BÀI THI',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showPaletteBottomSheet(BuildContext context, ExamSessionState session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  'Danh Sách Câu Hỏi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(widget.exam.questions.length, (i) {
                  final qId = widget.exam.questions[i].id;
                  final isDone = session.answers.containsKey(qId);
                  final isCurrent = i == session.currentQuestionIndex;

                  return GestureDetector(
                    onTap: () {
                      ref.read(examSessionProvider.notifier).goToQuestion(i);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? AppColors.primary
                            : (isDone ? AppColors.secondary.withOpacity(0.25) : AppColors.surfaceCard),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primaryLight
                              : (isDone ? AppColors.secondary : AppColors.glassBorder),
                        ),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              NeumorphicButton(
                gradient: AppColors.emeraldGradient,
                onPressed: () {
                  Navigator.pop(context);
                  _showSubmitConfirmation(context, session, widget.exam.questions.length);
                },
                child: const Text(
                  'NỘP BÀI THI NGAY',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubmitConfirmation(BuildContext context, ExamSessionState session, int total) {
    final answeredCount = session.answers.length;
    final unanswered = total - answeredCount;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận nộp bài thi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đã làm: $answeredCount / $total câu hỏi.'),
            if (unanswered > 0)
              Text(
                'Còn $unanswered câu chưa chọn đáp án!',
                style: const TextStyle(color: AppColors.rssiWarning, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            const Text(
              'Bài thi sẽ được đóng gói mã hóa và truyền ngược về máy Giám thị qua BLE.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tiếp tục làm', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () {
              Navigator.pop(context);
              ref.read(examSessionProvider.notifier).submitExam();
            },
            child: const Text('Nộp bài ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Cảnh báo rời phòng thi'),
        content: const Text(
          'Thoát ứng dụng trong lúc đang làm bài sẽ bị ghi nhận vi phạm quy chế thi. Bạn có chắc muốn nộp bài và rời đi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ở lại làm bài'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(examSessionProvider.notifier).submitExam();
            },
            child: const Text('Nộp & Thoát', style: TextStyle(color: AppColors.rssiCritical)),
          ),
        ],
      ),
    );
  }
}
