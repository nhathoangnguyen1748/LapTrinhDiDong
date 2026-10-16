import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/local_exam_storage.dart';
import '../../../core/utils/excel_helper.dart';
import '../../../models/exam_model.dart';
import '../../../services/api_service.dart';
import '../../common/glass_card.dart';
import '../../common/neumorphic_button.dart';

class TeacherCreateExamScreen extends StatefulWidget {
  const TeacherCreateExamScreen({super.key});

  @override
  State<TeacherCreateExamScreen> createState() => _TeacherCreateExamScreenState();
}

class _TeacherCreateExamScreenState extends State<TeacherCreateExamScreen> {
  final _idController = TextEditingController(text: 'EXAM_CNTT_${DateTime.now().minute}${DateTime.now().second}');
  final _titleController = TextEditingController(text: 'Kiểm Tra Chuyên Đề Lập Trình Di Động');
  final _durationController = TextEditingController(text: '20');
  final _pinController = TextEditingController(text: '1234');
  int _rssiThreshold = -80;
  bool _isLoading = false;

  final List<QuestionModel> _questions = [
    const QuestionModel(
      id: 1,
      content: 'Giao thức Bluetooth Low Energy (BLE) hoạt động ở băng tần số nào?',
      options: [
        OptionModel(id: 'A', text: '2.4 GHz ISM Band'),
        OptionModel(id: 'B', text: '5.0 GHz UNII Band'),
        OptionModel(id: 'C', text: '900 MHz Sub-GHz'),
        OptionModel(id: 'D', text: '433 MHz RFID'),
      ],
      correctOptionId: 'A',
    ),
    const QuestionModel(
      id: 2,
      content: 'Đơn vị đo chuẩn của giá trị RSSI trong mạng không dây là gì?',
      options: [
        OptionModel(id: 'A', text: 'Milliwatt (mW)'),
        OptionModel(id: 'B', text: 'Decibel-milliwatts (dBm)'),
        OptionModel(id: 'C', text: 'Microvolt (μV)'),
        OptionModel(id: 'D', text: 'Hertz (Hz)'),
      ],
      correctOptionId: 'B',
    ),
  ];

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _durationController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  /// Nạp danh sách câu hỏi từ file Excel (.xlsx)
  Future<void> _handleImportExcel() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (files.isEmpty) return;

      setState(() => _isLoading = true);

      final file = files.first;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('File đã chọn không có dữ liệu (rỗng).');
      }

      final imported = ExcelHelper.parseQuestionsFromExcel(bytes);

      setState(() {
        _questions.clear();
        _questions.addAll(imported);
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nạp thành công ${imported.length} câu hỏi từ file Excel!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi nạp Excel: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppColors.rssiCritical,
        ),
      );
    }
  }

  /// Tải / Chia sẻ file Excel mẫu để giảng viên chỉnh sửa
  Future<void> _handleDownloadTemplate() async {
    try {
      final templateBytes = ExcelHelper.createQuestionTemplateExcel();
      await ExcelHelper.shareOrSaveExcelFile(
        bytes: templateBytes,
        filename: 'Mau_De_Thi_LocalQuiz.xlsx',
        title: 'Mẫu Đề Thi Trắc Nghiệm Excel (.xlsx)',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tạo file mẫu: $e'),
          backgroundColor: AppColors.rssiCritical,
        ),
      );
    }
  }

  /// Hộp thoại thêm hoặc sửa câu hỏi (Không bao giờ tràn màn hình)
  void _showAddQuestionDialog({QuestionModel? editingQuestion, int? index}) {
    final contentCtrl = TextEditingController(text: editingQuestion?.content ?? '');
    final optACtrl = TextEditingController(text: editingQuestion?.options.isNotEmpty == true ? editingQuestion!.options[0].text : '');
    final optBCtrl = TextEditingController(text: editingQuestion != null && editingQuestion.options.length > 1 ? editingQuestion.options[1].text : '');
    final optCCtrl = TextEditingController(text: editingQuestion != null && editingQuestion.options.length > 2 ? editingQuestion.options[2].text : '');
    final optDCtrl = TextEditingController(text: editingQuestion != null && editingQuestion.options.length > 3 ? editingQuestion.options[3].text : '');
    String correctOpt = editingQuestion?.correctOptionId ?? 'A';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            editingQuestion != null ? 'Sửa Câu Hỏi ${editingQuestion.id}' : 'Thêm Câu Hỏi Mới',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Nội dung câu hỏi',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                _buildOptionField('A', optACtrl),
                const SizedBox(height: 8),
                _buildOptionField('B', optBCtrl),
                const SizedBox(height: 8),
                _buildOptionField('C', optCCtrl),
                const SizedBox(height: 8),
                _buildOptionField('D', optDCtrl),
                const SizedBox(height: 14),

                // Lựa chọn đáp án đúng: Chia đều 4 nút bằng Expanded, chống tràn 100%
                const Text(
                  'Chọn đáp án đúng:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['A', 'B', 'C', 'D'].map((opt) {
                    final isSelected = correctOpt == opt;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => setDlgState(() => correctOpt = opt),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isSelected ? AppColors.secondary : AppColors.surfaceDark,
                              border: Border.all(
                                color: isSelected ? AppColors.secondary : AppColors.glassBorder,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: () {
                if (contentCtrl.text.trim().isEmpty) return;
                final newQ = QuestionModel(
                  id: editingQuestion?.id ?? (_questions.length + 1),
                  content: contentCtrl.text.trim(),
                  options: [
                    OptionModel(id: 'A', text: optACtrl.text.trim().isNotEmpty ? optACtrl.text.trim() : 'Phương án A'),
                    OptionModel(id: 'B', text: optBCtrl.text.trim().isNotEmpty ? optBCtrl.text.trim() : 'Phương án B'),
                    OptionModel(id: 'C', text: optCCtrl.text.trim().isNotEmpty ? optCCtrl.text.trim() : 'Phương án C'),
                    OptionModel(id: 'D', text: optDCtrl.text.trim().isNotEmpty ? optDCtrl.text.trim() : 'Phương án D'),
                  ],
                  correctOptionId: correctOpt,
                );

                setState(() {
                  if (index != null && index < _questions.length) {
                    _questions[index] = newQ;
                  } else {
                    _questions.add(newQ);
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Lưu câu hỏi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Hộp thoại xác nhận xóa câu hỏi
  void _confirmDeleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontSize: 16)),
        content: Text('Bạn có chắc chắn muốn xóa câu hỏi ${index + 1} không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rssiCritical),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _questions.removeAt(index);
                // Đánh lại số thứ tự ID
                for (int i = 0; i < _questions.length; i++) {
                  _questions[i] = _questions[i].copyWith(id: i + 1);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã xóa câu hỏi ${index + 1}'),
                  backgroundColor: AppColors.rssiCritical,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionField(String optLabel, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Phương án $optLabel',
        prefixIcon: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceDark,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            optLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
          ),
        ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _handleSaveExam() async {
    final examId = _idController.text.trim();
    final title = _titleController.text.trim();
    final durationMin = int.tryParse(_durationController.text.trim()) ?? 20;
    final pin = _pinController.text.trim();

    if (examId.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Mã đề thi và Tên bài thi'),
          backgroundColor: AppColors.rssiCritical,
        ),
      );
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần ít nhất 1 câu hỏi để tạo đề thi'),
          backgroundColor: AppColors.rssiCritical,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final examModel = ExamModel(
      examId: examId,
      title: title,
      durationSeconds: durationMin * 60,
      rssiThreshold: _rssiThreshold,
      roomPin: pin.isNotEmpty ? pin : '1234',
      questions: _questions,
    );

    // Lưu offline vào Local Storage
    await LocalExamStorage.saveDownloadedExam(examModel);

    // Đồng bộ lên Backend nếu có mạng
    try {
      final examPayload = {
        'id': examId,
        'title': title,
        'duration_seconds': durationMin * 60,
        'rssi_threshold': _rssiThreshold,
        'room_pin': pin.isNotEmpty ? pin : '1234',
        'questions': _questions.map((q) => q.toJson()).toList(),
      };
      await ApiService.instance.createExam(examPayload);
    } catch (_) {
      // Khi offline vẫn an toàn vì đã lưu cục bộ
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã lưu đề thi "$title" (${_questions.length} câu) thành công!'),
        backgroundColor: AppColors.secondary,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soạn & Nạp Đề Thi'),
        actions: [
          IconButton(
            tooltip: 'Tải file Excel mẫu',
            icon: const Icon(Icons.download_rounded),
            onPressed: _handleDownloadTemplate,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Thẻ thông tin bài thi
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Thông Tin Ca Thi',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _idController,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Mã bài thi',
                        prefixIcon: Icon(Icons.tag_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Tên môn thi / Bài thi',
                        prefixIcon: Icon(Icons.title_rounded, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Thời gian (phút)',
                              prefixIcon: Icon(Icons.timer_outlined, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Mã PIN phòng',
                              prefixIcon: Icon(Icons.pin_rounded, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cấu hình Ngưỡng RSSI: Dùng DropdownButtonFormField full-width chống tràn hoàn toàn
                    const Text(
                      'Ngưỡng sóng an toàn (RSSI Geofencing):',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _rssiThreshold,
                      dropdownColor: AppColors.surfaceDark,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: -75,
                          child: Text('-75 dBm (Phòng hẹp < 5m)', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: -80,
                          child: Text('-80 dBm (Tiêu chuẩn 8 - 10m)', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: -85,
                          child: Text('-85 dBm (Phòng rộng 12 - 15m)', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _rssiThreshold = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Thẻ Nạp Đề Bằng Excel
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient.scale(0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.table_chart_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Nạp Đề Bằng File Excel (.xlsx)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tải file mẫu',
                          icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                          onPressed: _handleDownloadTemplate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hỗ trợ cột: [STT, Câu hỏi, Phương án A, B, C, D, Đáp án đúng]',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('CHỌN FILE EXCEL TỪ ĐIỆN THOẠI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _handleImportExcel,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Danh sách câu hỏi & Thêm thủ công
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu hỏi đã nạp (${_questions.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Thêm câu', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showAddQuestionDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              if (_questions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text('Chưa có câu hỏi nào. Hãy chọn file Excel hoặc bấm Thêm câu.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Câu ${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                              const Spacer(),
                              Text('Đ/A: ${q.correctOptionId}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showAddQuestionDialog(editingQuestion: q, index: index),
                                child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () => _confirmDeleteQuestion(index),
                                child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.rssiCritical),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            q.content,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 16),

              // 4. Nút lưu đề thi
              NeumorphicButton(
                gradient: AppColors.emeraldGradient,
                isLoading: _isLoading,
                onPressed: _handleSaveExam,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'LƯU ĐỀ THI & PHÁT BLE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
