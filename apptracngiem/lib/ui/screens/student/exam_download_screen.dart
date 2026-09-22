import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/exam_model.dart';
import '../../../providers/ble_providers.dart';
import '../../../providers/exam_session_provider.dart';
import '../../../services/ble_central_service.dart';
import '../../../services/mock_ble_service.dart';
import '../../common/glass_card.dart';
import '../../common/neumorphic_button.dart';
import '../../common/rssi_badge.dart';
import 'exam_taking_screen.dart';

class ExamDownloadScreen extends ConsumerStatefulWidget {
  final DiscoveredExamRoom room;
  final String studentName;
  final String studentId;

  const ExamDownloadScreen({
    super.key,
    required this.room,
    required this.studentName,
    required this.studentId,
  });

  @override
  ConsumerState<ExamDownloadScreen> createState() => _ExamDownloadScreenState();
}

class _ExamDownloadScreenState extends ConsumerState<ExamDownloadScreen> {
  bool _isConnected = false;
  bool _isConnecting = true;
  String _statusMessage = 'Đang bắt tay kết nối BLE & Đàm phán MTU 512...';
  ExamModel? _downloadedExam;
  StreamSubscription<ExamModel>? _examSubscription;

  @override
  void initState() {
    super.initState();
    _startConnectionAndDownload();
  }

  Future<void> _startConnectionAndDownload() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Đang kết nối tới ${widget.room.name}...';
    });

    final success = await BleCentralService.instance.connectToRoom(widget.room);
    if (!mounted) return;

    if (!success) {
      setState(() {
        _isConnecting = false;
        _statusMessage = 'Kết nối BLE thất bại! Vui lòng thử lại.';
      });
      return;
    }

    setState(() {
      _isConnected = true;
      _isConnecting = false;
      _statusMessage = 'Đã kết nối! Đang nhận các gói tin đề thi...';
    });

    // Listen for completed reassembled exam
    _examSubscription = BleCentralService.instance.completedExamStream.listen((exam) {
      if (mounted) {
        setState(() {
          _downloadedExam = exam;
          _statusMessage = 'Tải và giải mã đề thi thành công!';
        });
      }
    });

    // If in mock mode, trigger simulated stream of chunks
    if (widget.room.isMock || BleCentralService.instance.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      MockBleService.instance.streamExamChunks(ExamModel.sampleExam());
    }
  }

  @override
  void dispose() {
    _examSubscription?.cancel();
    super.dispose();
  }

  void _onStartExam() {
    if (_downloadedExam == null) return;

    ref.read(examSessionProvider.notifier).startExam(
          _downloadedExam!,
          studentId: widget.studentId,
          studentName: widget.studentName,
        );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExamTakingScreen(exam: _downloadedExam!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(downloadProgressProvider);
    final currentProgress = progressAsync.valueOrNull ?? 0.0;
    final buffer = BleCentralService.instance.reassemblyBuffer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tải Đề Thi Ngoại Tuyến'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            BleCentralService.instance.disconnect();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Room Info Card
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withOpacity(0.15),
                      ),
                      child: const Icon(Icons.cast_connected_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.room.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Thí sinh: ${widget.studentName} (${widget.studentId})',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    RssiBadge(rssi: widget.room.rssi, isCompact: true),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Chunk Reassembly & Security Pipeline
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Circular / Progress Bar for Packets
                      Container(
                        width: 130,
                        height: 130,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceCard,
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 110,
                              height: 110,
                              child: CircularProgressIndicator(
                                value: currentProgress > 0 ? currentProgress : null,
                                strokeWidth: 8,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _downloadedExam != null ? AppColors.secondary : AppColors.primary,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(currentProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  buffer.totalCount > 0
                                      ? '${buffer.receivedCount}/${buffer.totalCount} Chunks'
                                      : 'Đang kết nối',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().scale(duration: 400.ms),

                      const SizedBox(height: 20),

                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Pipeline Checklist Cards
                      _buildPipelineStep(
                        title: 'Đàm phán MTU 512 bytes & GATT Discovery',
                        isDone: _isConnected,
                        isActive: _isConnecting,
                      ),
                      const SizedBox(height: 10),
                      _buildPipelineStep(
                        title: 'Truyền nhận phân mảnh BLE Packets',
                        isDone: currentProgress >= 1.0,
                        isActive: _isConnected && currentProgress < 1.0,
                      ),
                      const SizedBox(height: 10),
                      _buildPipelineStep(
                        title: 'Kiểm tra toàn vẹn CRC32 / MD5 Checksum',
                        isDone: _downloadedExam != null,
                        isActive: currentProgress >= 1.0 && _downloadedExam == null,
                      ),
                      const SizedBox(height: 10),
                      _buildPipelineStep(
                        title: 'Giải mã AES-256 & Giải nén GZip',
                        isDone: _downloadedExam != null,
                        isActive: currentProgress >= 1.0 && _downloadedExam == null,
                      ),

                      const SizedBox(height: 24),

                      // If Exam Downloaded, Show Summary Box
                      if (_downloadedExam != null)
                        GlassCard(
                          borderColor: AppColors.secondary.withOpacity(0.5),
                          color: AppColors.secondary.withOpacity(0.08),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _downloadedExam!.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildExamMeta(
                                    Icons.timer_rounded,
                                    '${_downloadedExam!.durationSeconds ~/ 60} Phút',
                                  ),
                                  _buildExamMeta(
                                    Icons.quiz_rounded,
                                    '${_downloadedExam!.questions.length} Câu hỏi',
                                  ),
                                  _buildExamMeta(
                                    Icons.radar_rounded,
                                    'Ngưỡng ${_downloadedExam!.rssiThreshold} dBm',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn().slideY(begin: 0.1),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Button
              NeumorphicButton(
                onPressed: _downloadedExam != null ? _onStartExam : null,
                gradient: _downloadedExam != null ? AppColors.emeraldGradient : null,
                isLoading: _isConnecting || (currentProgress > 0 && currentProgress < 1.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _downloadedExam != null ? Icons.play_arrow_rounded : Icons.downloading_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _downloadedExam != null ? 'BẮT ĐẦU LÀM BÀI' : 'ĐANG TẢI ĐỀ THI...',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
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
  }

  Widget _buildPipelineStep({
    required String title,
    required bool isDone,
    required bool isActive,
  }) {
    Color iconColor;
    IconData icon;

    if (isDone) {
      iconColor = AppColors.secondary;
      icon = Icons.check_circle_rounded;
    } else if (isActive) {
      iconColor = AppColors.primary;
      icon = Icons.sync_rounded;
    } else {
      iconColor = AppColors.textMuted.withOpacity(0.5);
      icon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? AppColors.secondary.withOpacity(0.3) : AppColors.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isDone || isActive ? FontWeight.w600 : FontWeight.normal,
                color: isDone || isActive ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamMeta(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primaryLight),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
