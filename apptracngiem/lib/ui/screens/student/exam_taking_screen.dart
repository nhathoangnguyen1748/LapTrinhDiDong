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
  final String classroom;

  const ExamTakingScreen({
    super.key,
    required this.exam,
    this.classroom = 'CNTT-K18A',
  });

  @override
  ConsumerState<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends ConsumerState<ExamTakingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = ref.read(examSessionProvider);
      if (session.isSubmitted && session.submission != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExamResultScreen(
              submission: session.submission!,
              exam: widget.exam,
            ),
          ),
        );
      }
    });
  }

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
            builder: (_) => ExamResultScreen(
              submission: next.submission!,
              exam: widget.exam,
            ),
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

                  // Question Content & Options
                  Expanded(
                    child: currentQuestion != null
                        ? _buildQuestionContent(
                            currentQuestion,
                            selectedOption,
                            isFlagged,
                            currentIndex: currentIndex,
                            totalQuestions: questions.length,
                          )
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Live BLE RSSI Badge
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RssiBadge(rssi: geofence.rssi, isCompact: true),
            ),
          ),

          const SizedBox(width: 8),

          // Timer circular badge
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Container(
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
                  mainAxisSize: MainAxisSize.min,
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
            ),
          ),

          const SizedBox(width: 4),

          // Question Palette Trigger Button with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.grid_view_rounded, color: AppColors.textPrimary, size: 28),
                onPressed: () => _showPaletteBottomSheet(context, session),
              ),
              if (session.flaggedQuestions.isNotEmpty)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.rssiWarning,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${session.flaggedQuestions.length}',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
            ],
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

  Widget _buildQuestionContent(
    QuestionModel question,
    String? selectedOption,
    bool isFlagged, {
    required int currentIndex,
    required int totalQuestions,
  }) {
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
                      'CÂU HỎI ${currentIndex + 1} / $totalQuestions',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    InkWell(
                      onTap: () => ref.read(examSessionProvider.notifier).toggleFlag(question.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isFlagged
                              ? AppColors.rssiWarning.withOpacity(0.15)
                              : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFlagged ? AppColors.rssiWarning : AppColors.glassBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFlagged ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 15,
                              color: isFlagged ? AppColors.rssiWarning : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFlagged ? 'Đang xem lại' : 'Xem lại',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isFlagged ? AppColors.rssiWarning : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
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
                    ? AppColors.primary.withOpacity(0.08)
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
                        color: isSelected ? AppColors.primary : AppColors.surfaceDark,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.glassBorder,
                        ),
                      ),
                      child: Text(
                        opt.id,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
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
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Padding(
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
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(widget.exam.questions.length, (i) {
                        final qId = widget.exam.questions[i].id;
                        final isDone = session.answers.containsKey(qId);
                        final isCurrent = i == session.currentQuestionIndex;
                        final isFlagged = session.flaggedQuestions.contains(qId);

                        return GestureDetector(
                          onTap: () {
                            ref.read(examSessionProvider.notifier).goToQuestion(i);
                            Navigator.pop(context);
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCurrent
                                      ? AppColors.primary
                                      : (isDone ? AppColors.secondary.withOpacity(0.15) : AppColors.surfaceDark),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppColors.primary
                                        : (isDone ? AppColors.secondary : AppColors.glassBorder),
                                    width: isCurrent ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCurrent
                                        ? Colors.white
                                        : (isDone ? AppColors.secondary : AppColors.textPrimary),
                                  ),
                                ),
                              ),
                              if (isFlagged)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppColors.rssiWarning,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.bookmark_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
