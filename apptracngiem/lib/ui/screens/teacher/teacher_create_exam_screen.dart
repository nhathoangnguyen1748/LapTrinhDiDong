import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/local_exam_storage.dart';
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
  final _idController = TextEditingController(text: 'EXAM_CNTT_K18');
  final _titleController = TextEditingController(text: 'Kiểm Tra Chuyên Đề IoT & Lập Trình Di Động');
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(editingQuestion != null ? 'Sửa Câu Hỏi ${editingQuestion.id}' : 'Thêm Câu Hỏi Mới'),
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
                  ),
                ),
                const SizedBox(height: 12),
                _buildOptionField('A', optACtrl),
                const SizedBox(height: 8),
                _buildOptionField('B', optBCtrl),
                const SizedBox(height: 8),
                _buildOptionField('C', optCCtrl),
                const SizedBox(height: 8),
                _buildOptionField('D', optDCtrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Đáp án đúng: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    ...['A', 'B', 'C', 'D'].map((opt) {
                      final isSelected = correctOpt == opt;
                      return GestureDetector(
                        onTap: () => setDlgState(() => correctOpt = opt),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppColors.secondary : Colors.white12,
                          ),
                          child: Text(opt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
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
              child: const Text('Lưu câu hỏi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white12),
          child: Text(optLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  void _showImportJsonDialog() {
    final jsonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.file_upload_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Nạp Câu Hỏi Từ JSON', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dán cấu trúc JSON ngân hàng câu hỏi hoặc nạp nhanh bộ mẫu:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: jsonCtrl,
                maxLines: 8,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: '[\n  {\n    "id": 1,\n    "content": "Câu hỏi?",\n    "options": [\n      {"id": "A", "text": "..."}\n    ],\n    "correct_option_id": "A"\n  }\n]',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.flash_on_rounded, size: 16, color: AppColors.rssiWarning),
                    label: const Text('Nạp mẫu 6 câu BLE', style: TextStyle(fontSize: 11, color: AppColors.rssiWarning)),
                    onPressed: () {
                      final sampleExam = ExamModel.sampleExam();
                      final sampleJson = jsonEncode(sampleExam.questions.map((q) => q.toJson()).toList());
                      jsonCtrl.text = sampleJson;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              try {
                final raw = jsonDecode(jsonCtrl.text.trim()) as List<dynamic>;
                final parsed = raw.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList();
                if (parsed.isNotEmpty) {
                  setState(() {
                    _questions.clear();
                    _questions.addAll(parsed);
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã nạp thành công ${parsed.length} câu hỏi!'), backgroundColor: AppColors.secondary),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('JSON không đúng định dạng: $e'), backgroundColor: AppColors.rssiCritical),
                );
              }
            },
            child: const Text('Nạp vào đề', style: TextStyle(color: Colors.white)),
          ),
        ],
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
        const SnackBar(content: Text('Vui lòng nhập Mã đề thi và Tên môn thi!'), backgroundColor: AppColors.rssiCritical),
      );
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đề thi phải có ít nhất 1 câu hỏi!'), backgroundColor: AppColors.rssiCritical),
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
      serverStartTime: DateTime.now(),
    );

    // Save locally offline first
    await LocalExamStorage.saveDownloadedExam(examModel);

    // Sync to Server if connected
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
      // If server unreachable, it is still stored locally offline
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã tạo đề thi "$title" (${_questions.length} câu) thành công!'),
        backgroundColor: AppColors.secondary,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Đề Thi Mới'),
        actions: [
          IconButton(
            tooltip: 'Nạp câu hỏi từ file JSON',
            icon: const Icon(Icons.file_upload_rounded),
            onPressed: _showImportJsonDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Config Card
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Cấu hình Thông Tin Bài Thi & Phòng BLE',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _idController,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Mã bài thi (Ví dụ: EXAM_CNTT_K18)',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Tên môn thi / Bài thi',
                        prefixIcon: Icon(Icons.title_rounded, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Mã PIN phòng thi',
                              prefixIcon: Icon(Icons.pin_rounded, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ngưỡng RSSI Geofence:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        DropdownButton<int>(
                          value: _rssiThreshold,
                          dropdownColor: AppColors.surfaceDark,
                          items: const [
                            DropdownMenuItem(value: -75, child: Text('-75 dBm (Phòng hẹp < 5m)')),
                            DropdownMenuItem(value: -80, child: Text('-80 dBm (Chuẩn 8-10m)')),
                            DropdownMenuItem(value: -85, child: Text('-85 dBm (Phòng rộng 12-15m)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _rssiThreshold = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Questions List Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    'Ngân hàng câu hỏi (${_questions.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_rounded, size: 16),
                        label: const Text('Nạp JSON', style: TextStyle(fontSize: 12)),
                        onPressed: _showImportJsonDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: const Text('Thêm câu', style: TextStyle(fontSize: 12, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => _showAddQuestionDialog(),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Questions List
              ..._questions.asMap().entries.map((entry) {
                final index = entry.key;
                final q = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Câu ${index + 1}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                              onPressed: () => _showAddQuestionDialog(editingQuestion: q, index: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.rssiCritical),
                              onPressed: () {
                                setState(() => _questions.removeAt(index));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          q.content,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: q.options.map((opt) {
                            final isCorrect = q.correctOptionId == opt.id;
                            return Text(
                              '${opt.id}. ${opt.text}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                color: isCorrect ? AppColors.secondary : AppColors.textSecondary,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Save Button
              NeumorphicButton(
                gradient: AppColors.emeraldGradient,
                isLoading: _isLoading,
                onPressed: _handleSaveExam,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'LƯU ĐỀ THI & SẴN SÀNG PHÁT BLE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
