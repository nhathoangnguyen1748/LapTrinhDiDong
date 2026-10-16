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
  final String classroom;
  final String roomPin;

  const ExamDownloadScreen({
    super.key,
    required this.room,
    required this.studentName,
    required this.studentId,
    this.classroom = 'CNTT-K18A',
    this.roomPin = '1234',
  });

  @override
  ConsumerState<ExamDownloadScreen> createState() => _ExamDownloadScreenState();
}

class _ExamDownloadScreenState extends ConsumerState<ExamDownloadScreen> {
  bool _isConnected = false;
  bool _isConnecting = true;
  bool _isPinError = false;
  bool _isWaitingForMaster = false;
  String _statusMessage = 'Đang bắt tay kết nối BLE & Đàm phán MTU 512...';
  ExamModel? _downloadedExam;
  StreamSubscription<ExamModel>? _examSubscription;
  StreamSubscription<bool>? _masterStartSubscription;
  late String _enteredPin;

  @override
  void initState() {
    super.initState();
    _enteredPin = widget.roomPin;
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
    _examSubscription = BleCentralService.instance.completedExamStream.listen((exam) async {
      if (mounted) {
        // Validate PIN
        if (exam.roomPin.isNotEmpty && exam.roomPin != _enteredPin) {
          setState(() {
            _downloadedExam = exam;
            _isPinError = true;
            _statusMessage = 'Mã PIN không chính xác! Vui lòng nhập lại.';
          });
          return;
        }

        setState(() {
          _downloadedExam = exam;
          _isPinError = false;
          _isWaitingForMaster = true;
          _statusMessage = 'Đã điểm danh vào phòng! Đang chờ Giám thị phát lệnh bắt đầu...';
        });

        // Điểm danh thí sinh vào danh sách Roster của Giám thị
        await BleCentralService.instance.joinExamRoom(
          studentId: widget.studentId,
          studentName: widget.studentName,
          classroom: widget.classroom,
          roomPin: _enteredPin,
          totalQuestions: exam.questions.length,
        );

        // Lắng nghe lệnh phát đề đồng loạt từ Giám thị (Master Start Sync)
        _masterStartSubscription = BleCentralService.instance.masterStartStream.listen((started) {
          if (started && mounted && !_isPinError) {
            _onStartExam();
          }
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
    _masterStartSubscription?.cancel();
    super.dispose();
  }

  void _onStartExam() {
    if (_downloadedExam == null || _isPinError) return;

    ref.read(examSessionProvider.notifier).startExam(
          _downloadedExam!,
          studentId: widget.studentId,
          studentName: widget.studentName,
          classroom: widget.classroom,
        );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExamTakingScreen(
          exam: _downloadedExam!,
          classroom: widget.classroom,
        ),
      ),
    );
  }

  void _promptReenterPin() {
    final pinCtrl = TextEditingController();
    String? err;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.backgroundSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.glassBorder),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 10),
                Text('Nhập Lại Mã PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Vui lòng nhập đúng mã PIN phòng thi:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pinCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: AppColors.primaryLight,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'VD: 1234',
                    errorText: err,
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('HỦY', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newPin = pinCtrl.text.trim();
                  if (newPin.isEmpty) {
                    setDialogState(() => err = 'Vui lòng nhập mã PIN');
                    return;
                  }
                  if (_downloadedExam != null && _downloadedExam!.roomPin.isNotEmpty && _downloadedExam!.roomPin != newPin) {
                    setDialogState(() => err = 'Mã PIN vẫn chưa đúng');
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  setState(() {
                    _enteredPin = newPin;
                    _isPinError = false;
                    _isWaitingForMaster = true;
                    _statusMessage = 'Mã PIN chính xác! Đang chờ Giám thị phát lệnh...';
                  });
                  if (_downloadedExam != null) {
                    await BleCentralService.instance.joinExamRoom(
                      studentId: widget.studentId,
                      studentName: widget.studentName,
                      classroom: widget.classroom,
                      roomPin: _enteredPin,
                      totalQuestions: _downloadedExam!.questions.length,
                    );
                  }
                },
                child: const Text('XÁC NHẬN'),
              ),
            ],
          );
        },
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Room Info Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 8),
                          RssiBadge(rssi: widget.room.rssi, isCompact: true),
                        ],
                      ),
                    ),
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
                                backgroundColor: AppColors.surfaceDark,
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
                              Wrap(
                                spacing: 16,
                                runSpacing: 10,
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

                      if (_isPinError)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.rssiCritical.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.rssiCritical),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.gpp_bad_rounded, color: AppColors.rssiCritical, size: 28),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'MÃ PIN PHÒNG THI CHƯA CHÍNH XÁC!\nVui lòng nhập lại mã PIN do Giám thị cung cấp.',
                                      style: TextStyle(color: AppColors.rssiCritical, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.key_rounded, size: 18),
                                label: const Text('NHẬP LẠI MÃ PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _promptReenterPin,
                              ),
                            ],
                          ),
                        ),

                      if (_isWaitingForMaster && !_isPinError)
                        Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: AppColors.secondary, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đã điểm danh! Đồng hồ sẽ tự động bắt đầu khi Giám thị phát lệnh thi.',
                                  style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Button
              NeumorphicButton(
                onPressed: _isPinError
                    ? _promptReenterPin
                    : (_downloadedExam != null ? _onStartExam : null),
                gradient: _isPinError
                    ? AppColors.primaryGradient
                    : (_downloadedExam != null ? AppColors.emeraldGradient : null),
                isLoading: _isConnecting || (currentProgress > 0 && currentProgress < 1.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPinError
                          ? Icons.key_rounded
                          : (_downloadedExam != null ? Icons.play_arrow_rounded : Icons.downloading_rounded),
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPinError
                          ? 'NHẬP LẠI MÃ PIN'
                          : (_downloadedExam != null ? 'BẮT ĐẦU LÀM BÀI' : 'ĐANG TẢI ĐỀ THI...'),
                      style: const TextStyle(
                        fontSize: 14,
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
      mainAxisSize: MainAxisSize.min,
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
