import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/candidate_model.dart';
import '../../../models/exam_model.dart';
import '../../../models/submission_model.dart';
import '../../../providers/ble_providers.dart';
import '../../../services/api_service.dart';
import '../../../services/ble_peripheral_service.dart';
import '../../../services/mock_ble_service.dart';
import '../../common/glass_card.dart';
import '../../common/neumorphic_button.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  final ExamModel? selectedExam;
  final bool useSimulator;

  const HostDashboardScreen({
    super.key,
    this.selectedExam,
    this.useSimulator = true,
  });

  @override
  ConsumerState<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen>
    with SingleTickerProviderStateMixin {
  late ExamModel _exam;
  late TabController _tabController;
  bool _isAdvertising = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isExamStarted = false;
  int _lastSyncedCount = 0;

  @override
  void initState() {
    super.initState();
    _exam = widget.selectedExam ?? ExamModel.sampleExam();
    _tabController = TabController(length: 2, vsync: this);
    _isAdvertising = BlePeripheralService.instance.isAdvertising;
    _isExamStarted = BlePeripheralService.instance.isExamStarted;

    // In simulator mode, seed initial candidates if empty
    if (widget.useSimulator && BlePeripheralService.instance.candidates.isEmpty) {
      MockBleService.instance.simulateIncomingCandidate(
        studentId: 'TS-2026-001',
        studentName: 'Nguyễn Văn An',
        classroom: 'CNTT-K18A',
        deviceName: 'Galaxy S23',
        totalQuestions: _exam.questions.length,
      );
      MockBleService.instance.simulateIncomingCandidate(
        studentId: 'TS-2026-002',
        studentName: 'Trần Thị Mai',
        classroom: 'CNTT-K18B',
        deviceName: 'iPhone 14 Pro',
        totalQuestions: _exam.questions.length,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleAdvertising() async {
    setState(() => _isLoading = true);

    if (_isAdvertising) {
      await BlePeripheralService.instance.stopHosting();
      if (!mounted) return;
      setState(() {
        _isAdvertising = false;
        _isExamStarted = false;
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
                ? 'Đang phát sóng phòng thi: "${_exam.title}" (Mã PIN: ${_exam.roomPin})...'
                : 'Không thể khởi động BLE Peripheral trên thiết bị này.',
          ),
          backgroundColor: success ? AppColors.secondary : AppColors.rssiCritical,
        ),
      );
    }
  }

  void _handleBroadcastStartExam() {
    BlePeripheralService.instance.broadcastStartExam();
    setState(() => _isExamStarted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ĐÃ PHÁT LỆNH BẮT ĐẦU THI ĐỒNG LOẠT CHO TOÀN PHÒNG!'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  void _simulateCandidateJoin() {
    final randId = (DateTime.now().millisecond % 800) + 100;
    MockBleService.instance.simulateIncomingCandidate(
      studentId: 'TS-2026-$randId',
      studentName: 'Sinh viên $randId',
      classroom: 'CNTT-K18A',
      deviceName: 'Redmi Note 13',
      totalQuestions: _exam.questions.length,
    );
  }

  void _simulateProgressOrViolation() {
    final candidates = BlePeripheralService.instance.candidates;
    if (candidates.isEmpty) return;
    final first = candidates.first;
    MockBleService.instance.simulateCandidateProgress(first.studentId, (first.answeredCount + 1).clamp(0, _exam.questions.length));
  }

  void _simulateViolationAlert() {
    final candidates = BlePeripheralService.instance.candidates;
    if (candidates.isEmpty) return;
    final first = candidates.first;
    MockBleService.instance.simulateCandidateViolation(first.studentId, 'Rời ứng dụng làm bài / bật đa nhiệm');
  }

  void _simulateIncomingSubmission() {
    final mockSub = SubmissionModel(
      examId: _exam.examId,
      studentId: 'TS-2026-${(DateTime.now().millisecond % 900) + 100}',
      studentName: 'Trần Thị Mai',
      classroom: 'CNTT-K18A',
      answers: {1: 'A', 2: 'B', 3: 'B', 4: 'A', 5: 'B', 6: 'B'},
      submittedAt: DateTime.now(),
      timeTakenSeconds: 840,
      score: 6,
      totalQuestions: _exam.questions.length,
      violationCount: 0,
      receiptHash: 'ACK-TS-2026-OK',
    );
    BlePeripheralService.instance.addSubmission(mockSub);
  }

  Future<void> _syncToCloud(List<SubmissionModel> submissions) async {
    if (submissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có bài thi nào để đồng bộ!'),
          backgroundColor: AppColors.rssiWarning,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final result = await ApiService.instance.syncSubmissions(
        examId: _exam.examId,
        roomName: 'Phòng Thi: ${_exam.title}',
        submissions: submissions,
      );

      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _lastSyncedCount = result['synced_count'] ?? submissions.length;
      });

      _showSyncSuccessDialog(_lastSyncedCount, submissions.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      _showSyncErrorDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showSyncSuccessDialog(int synced, int total) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: AppColors.secondary, size: 28),
            SizedBox(width: 10),
            Text('Đồng Bộ Thành Công!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đã tải $synced / $total bài thi lên cơ sở dữ liệu FastAPI Backend.'),
            const SizedBox(height: 12),
            const Text(
              'Toàn bộ kết quả đã được lưu trữ an toàn. Bạn có thể xem phổ điểm và xuất file Excel ngay bây giờ.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () {
              Navigator.pop(ctx);
              _viewLiveReport();
            },
            child: const Text('Xem Báo Cáo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSyncErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: AppColors.rssiCritical, size: 26),
            SizedBox(width: 8),
            Text('Chưa kết nối Server'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Không thể gửi bài lên Cloud. Vui lòng bật lại Wi-Fi/4G và kiểm tra địa chỉ máy chủ.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text('Chi tiết: $error', style: const TextStyle(fontSize: 11, color: AppColors.rssiCritical)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  void _viewLiveReport() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      ),
    );

    try {
      final report = await ApiService.instance.getExamReport(_exam.examId);
      if (!mounted) return;
      Navigator.pop(context);

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.backgroundSecondary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Thống Kê Ca Thi: ${_exam.title}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildReportPill('Tổng bài nộp', '${report['total_submissions']}')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildReportPill('Điểm TB', '${report['average_score']}')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildReportPill('Tỷ lệ Đạt', '${report['pass_rate_percent']}%')),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Bảng điểm Excel đã sẵn sàng tại:\n${ApiService.instance.baseUrl}/exams/${_exam.examId}/export-excel',
                style: const TextStyle(fontSize: 11, color: AppColors.secondary),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.rssiCritical),
        );
      }
    }
  }

  Widget _buildReportPill(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submissionsAsync = ref.watch(hostSubmissionsProvider);
    final submissions = submissionsAsync.valueOrNull ?? BlePeripheralService.instance.receivedSubmissions;

    final candidatesAsync = ref.watch(hostCandidatesProvider);
    final candidates = candidatesAsync.valueOrNull ?? BlePeripheralService.instance.candidates;

    final waitingCount = candidates.where((c) => c.status == CandidateStatus.waiting).length;
    final takingCount = candidates.where((c) => c.status == CandidateStatus.taking).length;
    final submittedCount = candidates.where((c) => c.status == CandidateStatus.submitted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giám Thị - Quản Trị Ca Thi'),
        actions: [
          if (widget.useSimulator) ...[
            PopupMenuButton<String>(
              tooltip: 'Công cụ mô phỏng test',
              icon: const Icon(Icons.science_rounded, color: AppColors.primary),
              onSelected: (val) {
                if (val == 'join') _simulateCandidateJoin();
                if (val == 'progress') _simulateProgressOrViolation();
                if (val == 'violation') _simulateViolationAlert();
                if (val == 'submit') _simulateIncomingSubmission();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'join', child: Text('Mô phỏng Thí sinh vào phòng')),
                const PopupMenuItem(value: 'progress', child: Text('Mô phỏng Thí sinh làm bài')),
                const PopupMenuItem(value: 'violation', child: Text('Mô phỏng Thí sinh vi phạm')),
                const PopupMenuItem(value: 'submit', child: Text('Mô phỏng Thí sinh nộp bài')),
              ],
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Host Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlassCard(
                borderColor: _isAdvertising ? AppColors.secondary : AppColors.glassBorder,
                color: _isAdvertising ? AppColors.secondary.withOpacity(0.08) : AppColors.surfaceCard,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isAdvertising ? AppColors.secondary : AppColors.textMuted).withOpacity(0.15),
                          ),
                          child: Icon(
                            _isAdvertising ? Icons.podcasts_rounded : Icons.cell_tower_rounded,
                            color: _isAdvertising ? AppColors.secondary : AppColors.textMuted,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isAdvertising ? 'ĐANG PHÁT GATT SERVER' : 'CHƯA PHÁT PHÒNG THI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _isAdvertising ? AppColors.secondary : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _exam.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildHostMeta(Icons.access_time_rounded, '${_exam.durationSeconds ~/ 60} phút'),
                        _buildHostMeta(Icons.quiz_rounded, '${_exam.questions.length} câu'),
                        _buildHostMeta(Icons.pin_rounded, 'Mã PIN: ${_exam.roomPin}'),
                        _buildHostMeta(Icons.radar_rounded, 'Ngưỡng: ${_exam.rssiThreshold} dBm'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicButton(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            gradient: _isAdvertising ? AppColors.criticalGradient : AppColors.emeraldGradient,
                            isLoading: _isLoading,
                            onPressed: _toggleAdvertising,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_isAdvertising ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isAdvertising ? 'DỪNG PHÁT BLE' : 'PHÁT SÓNG ĐỀ THI',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_isAdvertising) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(_isExamStarted ? Icons.check_circle_rounded : Icons.campaign_rounded, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isExamStarted ? 'ĐANG THI' : 'PHÁT LỆNH THI',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isExamStarted ? AppColors.primary : AppColors.rssiWarning,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isExamStarted ? null : _handleBroadcastStartExam,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.secondary,
                labelColor: AppColors.secondary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(text: 'Điểm Danh Realtime (${candidates.length})'),
                  Tab(text: 'Bài Nộp & Sync (${submissions.length})'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Tab View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Live Roster & Candidate Presence
                  _buildCandidatesRosterTab(candidates, waitingCount, takingCount, submittedCount),

                  // Tab 2: Submissions & Cloud Sync
                  _buildSubmissionsSyncTab(submissions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesRosterTab(
    List<CandidateModel> candidates,
    int waiting,
    int taking,
    int submitted,
  ) {
    return Column(
      children: [
        // Roster Summary Counters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(child: _buildRosterStatCard('Chờ thi', '$waiting', AppColors.rssiWarning)),
              const SizedBox(width: 8),
              Expanded(child: _buildRosterStatCard('Đang làm', '$taking', AppColors.primary)),
              const SizedBox(width: 8),
              Expanded(child: _buildRosterStatCard('Đã nộp', '$submitted', AppColors.secondary)),
            ],
          ),
        ),

        Expanded(
          child: candidates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                      const SizedBox(height: 10),
                      const Text('Chưa có thí sinh nào vào phòng thi', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Mã PIN phòng thi: ${_exam.roomPin}', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final c = candidates[index];
                    final progress = c.totalQuestions > 0 ? (c.answeredCount / c.totalQuestions) : 0.0;
                    final hasViolation = c.violationCount > 0;

                    Color statusColor;
                    String statusLabel;
                    if (c.status == CandidateStatus.waiting) {
                      statusColor = AppColors.rssiWarning;
                      statusLabel = 'Chờ thi';
                    } else if (c.status == CandidateStatus.taking) {
                      statusColor = AppColors.primary;
                      statusLabel = 'Đang làm: ${c.answeredCount}/${c.totalQuestions}';
                    } else {
                      statusColor = AppColors.secondary;
                      statusLabel = 'Đã nộp bài';
                    }

                    return GlassCard(
                      borderColor: hasViolation ? AppColors.rssiCritical : AppColors.glassBorder,
                      color: hasViolation ? AppColors.rssiCritical.withOpacity(0.08) : AppColors.surfaceCard,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.2),
                                radius: 18,
                                child: Text(
                                  c.studentName.isNotEmpty ? c.studentName[0] : 'S',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${c.studentName} (${c.studentId})',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Lớp: ${c.classroom} • ${c.deviceName} • Pin: ${c.batteryLevel}%',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          if (c.status == CandidateStatus.taking) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                minHeight: 5,
                              ),
                            ),
                          ],
                          if (hasViolation) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.rssiCritical.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.rssiCritical),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'CẢNH BÁO: Vi phạm ${c.violationCount} lần! ${c.lastViolationAlert ?? ""}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.rssiCritical),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSubmissionsSyncTab(List<SubmissionModel> submissions) {
    return Column(
      children: [
        // Cloud Sync Action Box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient.scale(0.85),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đồng Bộ Ca Thi Lên Cloud',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      Text(
                        _lastSyncedCount > 0
                            ? 'Đã sync $_lastSyncedCount bài lên Server'
                            : 'Thu bài xong -> Bật Wi-Fi và bấm Đồng bộ',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _isSyncing ? null : () => _syncToCloud(submissions),
                  child: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Text('SYNC NGAY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),

        // Submissions List
        Expanded(
          child: submissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                      const SizedBox(height: 10),
                      const Text('Chưa có thí sinh nào nộp bài', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: submissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final sub = submissions[index];
                    final ratio = sub.totalQuestions > 0 ? (sub.score / sub.totalQuestions) : 0.0;
                    final score10 = (ratio * 10).toStringAsFixed(1);

                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
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
                                fontSize: 13,
                                color: ratio >= 0.5 ? AppColors.secondary : AppColors.rssiCritical,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${sub.studentName} (${sub.studentId})',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lớp: ${sub.classroom ?? "CNTT-K18A"} • Làm: ${sub.timeTakenSeconds ~/ 60}p ${sub.timeTakenSeconds % 60}s',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (sub.violationCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.rssiCritical.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${sub.violationCount} Vi phạm',
                                style: const TextStyle(fontSize: 10, color: AppColors.rssiCritical, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRosterStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildHostMeta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
