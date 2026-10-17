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
  final bool autoSubmitOnViolations;
  final SubmissionModel? submission;
  final String studentId;
  final String studentName;
  final String classroom;
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
    this.autoSubmitOnViolations = true,
    this.submission,
    this.studentId = 'TS-2026-001',
    this.studentName = 'Nguyễn Văn An',
    this.classroom = 'CNTT-K18A',
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
    bool? autoSubmitOnViolations,
    SubmissionModel? submission,
    String? studentId,
    String? studentName,
    String? classroom,
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
      autoSubmitOnViolations: autoSubmitOnViolations ?? this.autoSubmitOnViolations,
      submission: submission ?? this.submission,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      classroom: classroom ?? this.classroom,
      lastViolationReason: lastViolationReason ?? this.lastViolationReason,
    );
  }
}

class ExamSessionNotifier extends StateNotifier<ExamSessionState> {
  Timer? _countdownTimer;

  ExamSessionNotifier() : super(const ExamSessionState()) {
    BleCentralService.instance.forceSubmitStream.listen((force) {
      if (force && !state.isSubmitted && !state.isSubmitting && state.exam != null) {
        submitExam(isAutoSubmit: true);
      }
    });

    BleCentralService.instance.autoSubmitPolicyStream.listen((enable) {
      state = state.copyWith(autoSubmitOnViolations: enable);
    });
  }

  void setAutoSubmitOnViolations(bool enable) {
    state = state.copyWith(autoSubmitOnViolations: enable);
  }

  /// Initialize and start an exam session
  Future<void> startExam(
    ExamModel exam, {
    String studentId = 'TS-2026-001',
    String studentName = 'Nguyễn Văn An',
    String classroom = 'CNTT-K18A',
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
      classroom: classroom,
      lastViolationReason: null,
    );

    // Save exam locally encrypted
    await LocalExamStorage.saveExam(exam);

    final now = DateTime.now();
    final endTime = now.add(Duration(seconds: exam.durationSeconds));
    await LocalExamStorage.saveActiveStudentSession(
      ActiveStudentSession(
        exam: exam,
        studentId: studentId,
        studentName: studentName,
        classroom: classroom,
        examStartTime: now,
        examEndTime: endTime,
        violationCount: 0,
        autoSubmitOnViolations: state.autoSubmitOnViolations,
        deviceRemoteId: BleCentralService.instance.connectedDevice?.remoteId.str,
        isMock: BleCentralService.instance.isMockMode,
      ),
    );

    // Start Kiosk anti-cheat protection
    await KioskManager.instance.startKiosk(
      initialViolations: 0,
      onViolationDetected: (count, reason) {
        recordViolation(reason);
      },
      onAutoSubmitTriggered: () {
        if (state.autoSubmitOnViolations && !state.isSubmitted && !state.isSubmitting) {
          submitExam(isAutoSubmit: true);
        }
      },
    );

    // Start countdown timer
    _startCountdown();
  }

  /// Khôi phục phiên thi khi thí sinh thoát ứng dụng và mở lại
  Future<void> restoreSession(ActiveStudentSession session, {required int additionalViolations}) async {
    _countdownTimer?.cancel();

    final drafts = await LocalExamStorage.loadDraftAnswers(session.exam.examId);
    final totalViolations = session.violationCount + additionalViolations;
    final remaining = session.examEndTime.difference(DateTime.now()).inSeconds;

    state = state.copyWith(
      exam: session.exam,
      currentQuestionIndex: 0,
      answers: drafts,
      flaggedQuestions: {},
      remainingSeconds: remaining > 0 ? remaining : 0,
      isTimerPaused: false,
      violationCount: totalViolations,
      autoSubmitOnViolations: session.autoSubmitOnViolations,
      isSubmitted: false,
      isSubmitting: false,
      studentId: session.studentId,
      studentName: session.studentName,
      classroom: session.classroom,
      lastViolationReason: 'Rời khỏi ứng dụng khi đang làm bài',
    );

    // Cập nhật lại phiên lưu trữ với số lần vi phạm mới
    await LocalExamStorage.saveActiveStudentSession(
      ActiveStudentSession(
        exam: session.exam,
        studentId: session.studentId,
        studentName: session.studentName,
        classroom: session.classroom,
        examStartTime: session.examStartTime,
        examEndTime: session.examEndTime,
        violationCount: totalViolations,
        autoSubmitOnViolations: session.autoSubmitOnViolations,
        deviceRemoteId: session.deviceRemoteId,
        isMock: session.isMock,
      ),
    );

    // Nếu thời gian đã hết HOẶC (số vi phạm >= 3 VÀ GIẢNG VIÊN BẬT auto-submit) -> Thu bài luôn
    if (remaining <= 0 || (session.autoSubmitOnViolations && totalViolations >= BleConstants.maxViolationsAllowed)) {
      debugPrint('[ExamSession] Tự động nộp bài khi khôi phục (vi phạm: $totalViolations, hết giờ: ${remaining <= 0})...');
      await submitExam(isAutoSubmit: true);
      return;
    }

    // Bắt đầu Kiosk và đếm ngược tiếp với số lần vi phạm ban đầu là totalViolations
    await KioskManager.instance.startKiosk(
      initialViolations: totalViolations,
      onViolationDetected: (count, reason) {
        recordViolation(reason);
      },
      onAutoSubmitTriggered: () {
        if (state.autoSubmitOnViolations && !state.isSubmitted && !state.isSubmitting) {
          submitExam(isAutoSubmit: true);
        }
      },
    );

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
      // Gửi tiến độ realtime về máy Giám thị (Heartbeat)
      BleCentralService.instance.sendCandidateProgress(
        studentId: state.studentId,
        answeredCount: updatedAnswers.length,
      );
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

    // Cập nhật lại session lưu trữ với số lần vi phạm mới
    LocalExamStorage.getActiveStudentSession().then((active) {
      if (active != null) {
        LocalExamStorage.saveActiveStudentSession(
          ActiveStudentSession(
            exam: active.exam,
            studentId: active.studentId,
            studentName: active.studentName,
            classroom: active.classroom,
            examStartTime: active.examStartTime,
            examEndTime: active.examEndTime,
            violationCount: count,
            autoSubmitOnViolations: active.autoSubmitOnViolations,
            deviceRemoteId: active.deviceRemoteId,
            isMock: active.isMock,
          ),
        );
      }
    });

    // Gửi cảnh báo vi phạm về máy Giám thị qua BLE ngay lập tức
    BleCentralService.instance.sendCandidateViolation(
      studentId: state.studentId,
      violationCount: count,
      alertMessage: reason,
    );

    if (count >= BleConstants.maxViolationsAllowed && !state.isSubmitted && !state.isSubmitting && state.autoSubmitOnViolations) {
      submitExam(isAutoSubmit: true);
    }
  }

  /// Calculate score and submit exam via BLE
  Future<bool> submitExam({bool isAutoSubmit = false}) async {
    if (state.isSubmitted || state.isSubmitting || state.exam == null) return false;

    state = state.copyWith(isSubmitting: true, isSubmitted: true);
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
    final receiptHash = 'ACK-${state.studentId}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final submission = SubmissionModel(
      examId: state.exam!.examId,
      studentId: state.studentId,
      studentName: state.studentName,
      classroom: state.classroom,
      answers: state.answers,
      submittedAt: DateTime.now(),
      timeTakenSeconds: timeTaken > 0 ? timeTaken : 0,
      score: correctCount,
      totalQuestions: state.exam!.questions.length,
      violationCount: state.violationCount,
      receiptHash: receiptHash,
    );

    try {
      // Nếu BLE đang kết nối, gửi bài trực tiếp
      if (BleCentralService.instance.isConnected) {
        await BleCentralService.instance.submitExam(submission);
      } else {
        // Nếu BLE chưa kết nối (ví dụ app vừa mở lại sau khi bị đóng), thử kết nối lại nhanh để gửi bài
        final active = await LocalExamStorage.getActiveStudentSession();
        if (active != null && (active.deviceRemoteId != null || active.isMock)) {
          try {
            final reconnected = await BleCentralService.instance.reconnectToDevice(
              remoteId: active.deviceRemoteId,
              isMock: active.isMock,
            ).timeout(const Duration(seconds: 4));
            if (reconnected) {
              await BleCentralService.instance.submitExam(submission);
            }
          } catch (_) {}
        }
      }
      await LocalExamStorage.saveSubmission(submission);
      await LocalExamStorage.clearSession();
      await LocalExamStorage.clearActiveStudentSession();

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
      await LocalExamStorage.clearActiveStudentSession();
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
