import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/ble_constants.dart';
import '../core/security/kiosk_manager.dart';
import '../core/storage/local_exam_storage.dart';
import '../models/exam_model.dart';
import '../models/submission_model.dart';
import '../services/ble_central_service.dart';

class ExamSessionState {
  final ExamModel? exam;
  final int currentQuestionIndex;
  final Map<int, String> answers;
  final Set<int> flaggedQuestions;
  final int remainingSeconds;
  final bool isTimerPaused;
  final int violationCount;
  final bool isSubmitted;
  final bool isSubmitting;
  final SubmissionModel? submission;
  final String studentId;
  final String studentName;
  final String? lastViolationReason;

  const ExamSessionState({
    this.exam,
    this.currentQuestionIndex = 0,
    this.answers = const {},
    this.flaggedQuestions = const {},
    this.remainingSeconds = 0,
    this.isTimerPaused = false,
    this.violationCount = 0,
    this.isSubmitted = false,
    this.isSubmitting = false,
    this.submission,
    this.studentId = 'TS-2026-001',
    this.studentName = 'Nguyễn Văn An',
    this.lastViolationReason,
  });

  ExamSessionState copyWith({
    ExamModel? exam,
    int? currentQuestionIndex,
    Map<int, String>? answers,
    Set<int>? flaggedQuestions,
    int? remainingSeconds,
    bool? isTimerPaused,
    int? violationCount,
    bool? isSubmitted,
    bool? isSubmitting,
    SubmissionModel? submission,
    String? studentId,
    String? studentName,
    String? lastViolationReason,
  }) {
    return ExamSessionState(
      exam: exam ?? this.exam,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      flaggedQuestions: flaggedQuestions ?? this.flaggedQuestions,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isTimerPaused: isTimerPaused ?? this.isTimerPaused,
      violationCount: violationCount ?? this.violationCount,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submission: submission ?? this.submission,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      lastViolationReason: lastViolationReason ?? this.lastViolationReason,
    );
  }
}

class ExamSessionNotifier extends StateNotifier<ExamSessionState> {
  Timer? _countdownTimer;

  ExamSessionNotifier() : super(const ExamSessionState());

  /// Initialize and start an exam session
  Future<void> startExam(
    ExamModel exam, {
    String studentId = 'TS-2026-001',
    String studentName = 'Nguyễn Văn An',
  }) async {
    _countdownTimer?.cancel();

    // Check for saved draft answers
    final drafts = await LocalExamStorage.loadDraftAnswers(exam.examId);

    state = state.copyWith(
      exam: exam,
      currentQuestionIndex: 0,
      answers: drafts,
      flaggedQuestions: {},
      remainingSeconds: exam.durationSeconds,
      isTimerPaused: false,
      violationCount: 0,
      isSubmitted: false,
      isSubmitting: false,
      studentId: studentId,
      studentName: studentName,
      lastViolationReason: null,
    );

    // Save exam locally encrypted
    await LocalExamStorage.saveExam(exam);

    // Start Kiosk anti-cheat protection
    await KioskManager.instance.startKiosk(
      onViolationDetected: (count, reason) {
        recordViolation(reason);
      },
      onAutoSubmitTriggered: () {
        submitExam(isAutoSubmit: true);
      },
    );

    // Start countdown timer
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isSubmitted || state.remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        if (state.remainingSeconds <= 0 && !state.isSubmitted) {
          submitExam(isAutoSubmit: true);
        }
        return;
      }

      // If timer is not frozen by Geofencing out-of-bounds, decrement
      if (!state.isTimerPaused) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  /// Pause or resume countdown (called when student is out-of-bounds)
  void setTimerPaused(bool paused) {
    if (state.isTimerPaused != paused) {
      state = state.copyWith(isTimerPaused: paused);
      debugPrint('[ExamSession] Countdown timer paused: $paused');
    }
  }

  /// Select answer option for a question
  void selectAnswer(int questionId, String optionId) {
    if (state.isSubmitted) return;

    final updatedAnswers = Map<int, String>.from(state.answers);
    updatedAnswers[questionId] = optionId;
    state = state.copyWith(answers: updatedAnswers);

    if (state.exam != null) {
      LocalExamStorage.saveDraftAnswers(state.exam!.examId, updatedAnswers);
    }
  }

  /// Toggle flagged status for review
  void toggleFlag(int questionId) {
    final updatedFlags = Set<int>.from(state.flaggedQuestions);
    if (updatedFlags.contains(questionId)) {
      updatedFlags.remove(questionId);
    } else {
      updatedFlags.add(questionId);
    }
    state = state.copyWith(flaggedQuestions: updatedFlags);
  }

  /// Navigation
  void goToQuestion(int index) {
    if (state.exam != null && index >= 0 && index < state.exam!.questions.length) {
      state = state.copyWith(currentQuestionIndex: index);
    }
  }

  void nextQuestion() {
    if (state.exam != null && state.currentQuestionIndex < state.exam!.questions.length - 1) {
      state = state.copyWith(currentQuestionIndex: state.currentQuestionIndex + 1);
    }
  }

  void previousQuestion() {
    if (state.currentQuestionIndex > 0) {
      state = state.copyWith(currentQuestionIndex: state.currentQuestionIndex - 1);
    }
  }

  /// Record violation
  void recordViolation(String reason) {
    final count = state.violationCount + 1;
    state = state.copyWith(
      violationCount: count,
      lastViolationReason: reason,
    );

    if (count >= BleConstants.maxViolationsAllowed && !state.isSubmitted) {
      submitExam(isAutoSubmit: true);
    }
  }

  /// Calculate score and submit exam via BLE
  Future<bool> submitExam({bool isAutoSubmit = false}) async {
    if (state.isSubmitted || state.exam == null) return false;

    state = state.copyWith(isSubmitting: true);
    _countdownTimer?.cancel();
    await KioskManager.instance.stopKiosk();

    // Compute score
    int correctCount = 0;
    for (final q in state.exam!.questions) {
      final selected = state.answers[q.id];
      if (selected != null && selected == q.correctOptionId) {
        correctCount++;
      }
    }

    final timeTaken = state.exam!.durationSeconds - state.remainingSeconds;

    final submission = SubmissionModel(
      examId: state.exam!.examId,
      studentId: state.studentId,
      studentName: state.studentName,
      answers: state.answers,
      submittedAt: DateTime.now(),
      timeTakenSeconds: timeTaken > 0 ? timeTaken : 0,
      score: correctCount,
      totalQuestions: state.exam!.questions.length,
      violationCount: state.violationCount,
    );

    try {
      // Send over BLE
      await BleCentralService.instance.submitExam(submission);
      await LocalExamStorage.saveSubmission(submission);
      await LocalExamStorage.clearSession();

      state = state.copyWith(
        isSubmitted: true,
        isSubmitting: false,
        submission: submission,
      );
      return true;
    } catch (e) {
      debugPrint('[ExamSession] Submit error: $e');
      // Even if network fails, cache locally as completed
      await LocalExamStorage.saveSubmission(submission);
      state = state.copyWith(
        isSubmitted: true,
        isSubmitting: false,
        submission: submission,
      );
      return false;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    KioskManager.instance.stopKiosk();
    super.dispose();
  }
}

final examSessionProvider = StateNotifierProvider<ExamSessionNotifier, ExamSessionState>((ref) {
  return ExamSessionNotifier();
});
