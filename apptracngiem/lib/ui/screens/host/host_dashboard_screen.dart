import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/local_exam_storage.dart';
import '../../../core/utils/excel_helper.dart';
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
  bool _autoSubmitOnViolations = true;
  int _lastSyncedCount = 0;

  @override
  void initState() {
    super.initState();
    _exam = widget.selectedExam ?? ExamModel.sampleExam();
    _tabController = TabController(length: 2, vsync: this);
    _isAdvertising = BlePeripheralService.instance.isAdvertising;
    _isExamStarted = BlePeripheralService.instance.isExamStarted;
    _autoSubmitOnViolations = BlePeripheralService.instance.autoSubmitOnViolations;

    // Nạp lại lịch sử bài nộp và danh sách thí sinh đã lưu cho đề thi này
    BlePeripheralService.instance.loadHistoryForExam(_exam.examId);

    // Khôi phục hoặc khởi tạo active host session
    LocalExamStorage.getActiveHostSession().then((session) {
      if (session != null && session.exam.examId == _exam.examId && mounted) {
        setState(() {
          _isExamStarted = session.isExamStarted || _isExamStarted;
          _autoSubmitOnViolations = session.autoSubmitOnViolations;
        });
        BlePeripheralService.instance.setAutoSubmitOnViolations(_autoSubmitOnViolations);
        if (session.isAdvertising && !_isAdvertising) {
          _toggleAdvertising();
        }
      } else {
        _persistHostSession();
      }
    });

    // Chế độ mô phỏng
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

  Future<void> _persistHostSession() async {
    await LocalExamStorage.saveActiveHostSession(
      ActiveHostSession(
        exam: _exam,
        isAdvertising: _isAdvertising,
        isExamStarted: _isExamStarted,
        autoSubmitOnViolations: _autoSubmitOnViolations,
        startedAt: DateTime.now(),
      ),
    );
  }

  void _confirmExitRoom() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        title: const Text('Rời Phòng Giám Thị?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: const Text(
          'Bạn muốn TẠM THOÁT (phiên ca thi vẫn duy trì để quay lại tiếp tục) hay KẾT THÚC hoàn toàn ca thi này?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('TẠM THOÁT', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rssiCritical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await BlePeripheralService.instance.stopHosting();
              await LocalExamStorage.clearActiveHostSession();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('KẾT THÚC CA THI', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
      _persistHostSession();
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
      _persistHostSession();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Đang phát phòng thi: "${_exam.title}" (PIN: ${_exam.roomPin})'
                : 'Không thể khởi động BLE Peripheral.',
          ),
          backgroundColor: success ? AppColors.secondary : AppColors.rssiCritical,
        ),
      );
    }
  }

  void _handleBroadcastStartExam() {
    BlePeripheralService.instance.broadcastStartExam();
    setState(() => _isExamStarted = true);
    _persistHostSession();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã phát lệnh bắt đầu làm bài cho toàn bộ thí sinh!'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  /// Xuất bảng điểm chỉ lấy các kết quả nộp bài thực tế ra file Excel (.xlsx) ngay trên điện thoại (Offline)
  Future<void> _handleExportExcelOffline(List<SubmissionModel> submissions) async {
    // Chỉ lấy các kết quả nộp bài hợp lệ
    final submittedOnly = submissions.where((s) => s.studentId.trim().isNotEmpty && s.totalQuestions > 0).toList();

    if (submittedOnly.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có bài thi nào được nộp để xuất bảng điểm!'),
          backgroundColor: AppColors.rssiWarning,
        ),
      );
      return;
    }

    try {
      final bytes = ExcelHelper.exportSubmissionsToExcel(
        examTitle: _exam.title,
        examId: _exam.examId,
        submissions: submittedOnly,
      );

      final filename = 'KetQua_${_exam.examId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await ExcelHelper.shareOrSaveExcelFile(
        bytes: bytes,
        filename: filename,
        title: 'Bảng Điểm Ca Thi: ${_exam.title}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xuất file Excel: $e'),
          backgroundColor: AppColors.rssiCritical,
        ),
      );
    }
  }

  Future<void> _syncToCloud(List<SubmissionModel> submissions) async {
    final submittedOnly = submissions.where((s) => s.studentId.trim().isNotEmpty).toList();

    if (submittedOnly.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có bài nộp nào để đồng bộ!'),
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
        submissions: submittedOnly,
      );

      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _lastSyncedCount = result['synced_count'] ?? submittedOnly.length;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đồng bộ thành công $_lastSyncedCount bài thi lên Cloud!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi đồng bộ Cloud: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppColors.rssiCritical,
        ),
      );
    }
  }

  // Simulator helper methods
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

  void _simulateCandidateSubmit() {
    final randId = (DateTime.now().millisecond % 800) + 100;
    final mockSub = SubmissionModel(
      examId: _exam.examId,
      studentId: 'TS-2026-$randId',
      studentName: 'Sinh viên $randId',
      classroom: 'CNTT-K18A',
      answers: {1: 'A', 2: 'B', 3: 'C', 4: 'D'},
      submittedAt: DateTime.now(),
      timeTakenSeconds: 650,
      score: _exam.questions.length > 2 ? 3 : _exam.questions.length,
      totalQuestions: _exam.questions.length,
      violationCount: 0,
      receiptHash: 'ACK-TS-$randId',
    );
    BlePeripheralService.instance.addSubmission(mockSub);
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
        title: const Text('Giám Thị Phòng Thi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: _confirmExitRoom,
        ),
        actions: [
          if (widget.useSimulator) ...[
            PopupMenuButton<String>(
              tooltip: 'Mô phỏng test',
              icon: const Icon(Icons.science_rounded, color: AppColors.primary),
              onSelected: (val) {
                if (val == 'join') _simulateCandidateJoin();
                if (val == 'submit') _simulateCandidateSubmit();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'join', child: Text('Thêm thí sinh mẫu')),
                PopupMenuItem(value: 'submit', child: Text('Mô phỏng nộp bài mẫu')),
              ],
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Thẻ trạng thái GATT Server (hiển thị đầy đủ thông tin hài hòa, không cắt ngắn ...)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: GlassCard(
                borderColor: _isAdvertising ? AppColors.secondary : AppColors.glassBorder,
                color: _isAdvertising ? AppColors.secondary.withOpacity(0.08) : AppColors.surfaceCard,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isAdvertising ? Icons.podcasts_rounded : Icons.cell_tower_rounded,
                          color: _isAdvertising ? AppColors.secondary : AppColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _exam.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_isAdvertising ? AppColors.secondary : AppColors.textMuted).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isAdvertising ? 'ĐANG PHÁT' : 'CHƯA PHÁT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isAdvertising ? AppColors.secondary : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text('Mã PIN: ${_exam.roomPin}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        Text('${_exam.durationSeconds ~/ 60} phút', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text('${_exam.questions.length} câu', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text('Ngưỡng: ${_exam.rssiThreshold} dBm', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _autoSubmitOnViolations ? Icons.gavel_rounded : Icons.warning_amber_rounded,
                            size: 16,
                            color: _autoSubmitOnViolations ? AppColors.secondary : AppColors.rssiWarning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _autoSubmitOnViolations
                                  ? 'Tự động thu bài khi vi phạm 3 lần: BẬT'
                                  : 'Tự động thu bài khi vi phạm 3 lần: TẮT',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: _autoSubmitOnViolations,
                              activeColor: AppColors.secondary,
                              onChanged: (val) {
                                setState(() => _autoSubmitOnViolations = val);
                                BlePeripheralService.instance.setAutoSubmitOnViolations(val);
                                _persistHostSession();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicButton(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            gradient: _isAdvertising ? AppColors.criticalGradient : AppColors.emeraldGradient,
                            isLoading: _isLoading,
                            onPressed: _toggleAdvertising,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_isAdvertising ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _isAdvertising ? 'DỪNG PHÁT' : 'PHÁT PHÒNG THI',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isAdvertising) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(_isExamStarted ? Icons.check_circle_rounded : Icons.campaign_rounded, size: 16),
                              label: Text(
                                _isExamStarted ? 'ĐANG THI' : 'BẮT ĐẦU THI',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isExamStarted ? AppColors.primary : AppColors.rssiWarning,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

            // 2. TabBar tinh giản
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.secondary,
                labelColor: AppColors.secondary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(text: 'Thí Sinh (${candidates.length})'),
                  Tab(text: 'Bài Nộp (${submissions.length})'),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 3. TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Danh sách thí sinh
                  _buildCandidatesTab(candidates, waitingCount, takingCount, submittedCount),

                  // Tab 2: Danh sách bài nộp & Xuất Excel
                  _buildSubmissionsTab(submissions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesTab(
    List<CandidateModel> candidates,
    int waiting,
    int taking,
    int submitted,
  ) {
    return Column(
      children: [
        // Thống kê nhanh trạng thái
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Expanded(child: _buildMiniStat('Chờ thi', '$waiting', AppColors.rssiWarning)),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniStat('Đang làm', '$taking', AppColors.primary)),
              const SizedBox(width: 6),
              Expanded(child: _buildMiniStat('Đã nộp', '$submitted', AppColors.secondary)),
            ],
          ),
        ),

        Expanded(
          child: candidates.isEmpty
              ? const Center(
                  child: Text('Chưa có thí sinh nào kết nối', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = candidates[index];
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
                      statusLabel = 'Đã nộp';
                    }

                    return GlassCard(
                      borderColor: hasViolation ? AppColors.rssiCritical : AppColors.glassBorder,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.2),
                                radius: 15,
                                child: Text(
                                  c.studentName.isNotEmpty ? c.studentName[0] : 'S',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${c.studentName} (${c.studentId})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      '${c.classroom} • ${c.deviceName} • Pin: ${c.batteryLevel}%',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          if (hasViolation) ...[
                            const SizedBox(height: 6),
                            Text(
                              'CẢNH BÁO: Vi phạm ${c.violationCount} lần! ${c.lastViolationAlert ?? ""}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.rssiCritical),
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

  Widget _buildSubmissionsTab(List<SubmissionModel> submissions) {
    return Column(
      children: [
        // Hàng nút hành động: Xuất Excel (Chỉ lấy kết quả nộp bài) & Đồng bộ Cloud
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text(
                    'XUẤT EXCEL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: () => _handleExportExcelOffline(submissions),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSyncing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: const Text(
                    'SYNC CLOUD',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: _isSyncing ? null : () => _syncToCloud(submissions),
                ),
              ),
            ],
          ),
        ),

        // Danh sách bài nộp
        Expanded(
          child: submissions.isEmpty
              ? const Center(
                  child: Text('Chưa có bài thi nào được nộp', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: submissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final sub = submissions[index];
                    final ratio = sub.totalQuestions > 0 ? (sub.score / sub.totalQuestions) : 0.0;
                    final score10 = (ratio * 10).toStringAsFixed(1);
                    final isPassed = ratio >= 0.5;

                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPassed
                                  ? AppColors.secondary.withOpacity(0.15)
                                  : AppColors.rssiCritical.withOpacity(0.15),
                            ),
                            child: Text(
                              score10,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isPassed ? AppColors.secondary : AppColors.rssiCritical,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${sub.studentName} (${sub.studentId})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '${sub.classroom ?? ""} • Làm: ${sub.timeTakenSeconds ~/ 60}p ${sub.timeTakenSeconds % 60}s',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (sub.violationCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.rssiCritical.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${sub.violationCount} vi phạm',
                                style: const TextStyle(fontSize: 9, color: AppColors.rssiCritical, fontWeight: FontWeight.bold),
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
