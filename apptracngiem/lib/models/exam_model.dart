import 'dart:convert';

class OptionModel {
  final String id;
  final String text;

  const OptionModel({
    required this.id,
    required this.text,
  });

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    return OptionModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
    };
  }

  OptionModel copyWith({String? id, String? text}) {
    return OptionModel(
      id: id ?? this.id,
      text: text ?? this.text,
    );
  }
}

class QuestionModel {
  final int id;
  final String content;
  final String? imageUrl;
  final List<OptionModel> options;
  final String? correctOptionId;

  const QuestionModel({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.options,
    this.correctOptionId,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => OptionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      correctOptionId: json['correct_option_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'image_url': imageUrl,
      'options': options.map((e) => e.toJson()).toList(),
      'correct_option_id': correctOptionId,
    };
  }

  QuestionModel copyWith({
    int? id,
    String? content,
    String? imageUrl,
    List<OptionModel>? options,
    String? correctOptionId,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      options: options ?? this.options,
      correctOptionId: correctOptionId ?? this.correctOptionId,
    );
  }
}

class ExamModel {
  final String examId;
  final String title;
  final int durationSeconds;
  final int rssiThreshold;
  final List<QuestionModel> questions;
  final DateTime? serverStartTime;

  const ExamModel({
    required this.examId,
    required this.title,
    required this.durationSeconds,
    this.rssiThreshold = -80,
    required this.questions,
    this.serverStartTime,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      examId: json['exam_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 1800,
      rssiThreshold: json['rssi_threshold'] as int? ?? -80,
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      serverStartTime: json['server_start_time'] != null
          ? DateTime.tryParse(json['server_start_time'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exam_id': examId,
      'title': title,
      'duration_seconds': durationSeconds,
      'rssi_threshold': rssiThreshold,
      'questions': questions.map((e) => e.toJson()).toList(),
      if (serverStartTime != null)
        'server_start_time': serverStartTime!.toIso8601String(),
    };
  }

  String toRawJson() => jsonEncode(toJson());

  factory ExamModel.fromRawJson(String raw) =>
      ExamModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// Generate a realistic sample exam for test & demonstration
  static ExamModel sampleExam() {
    return ExamModel(
      examId: 'EXAM_2026_09',
      title: 'Kiểm tra Chuyên đề Mạng Không Dây & BLE',
      durationSeconds: 1200, // 20 minutes
      rssiThreshold: -80,
      serverStartTime: DateTime.now(),
      questions: [
        const QuestionModel(
          id: 1,
          content: 'Giao thức Bluetooth Low Energy (BLE) hoạt động ở dải băng tần vô tuyến nào?',
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
          content: 'Giá trị RSSI (Received Signal Strength Indicator) đo bằng đơn vị nào?',
          options: [
            OptionModel(id: 'A', text: 'Milliwatt (mW)'),
            OptionModel(id: 'B', text: 'Decibel-milliwatts (dBm)'),
            OptionModel(id: 'C', text: 'Microvolt (μV)'),
            OptionModel(id: 'D', text: 'Hertz (Hz)'),
          ],
          correctOptionId: 'B',
        ),
        const QuestionModel(
          id: 3,
          content: 'Trong kiến trúc GATT của BLE, vai trò của thiết bị đóng vai trò lưu trữ cơ sở dữ liệu thuộc tính và phục vụ các yêu cầu đọc/ghi được gọi là gì?',
          options: [
            OptionModel(id: 'A', text: 'GATT Client / Central'),
            OptionModel(id: 'B', text: 'GATT Server / Peripheral'),
            OptionModel(id: 'C', text: 'Broadcaster Observer'),
            OptionModel(id: 'D', text: 'Master Beacon'),
          ],
          correctOptionId: 'B',
        ),
        const QuestionModel(
          id: 4,
          content: 'Kích thước gói tin mặc định ATT MTU trong chuẩn BLE 4.0/4.1 trước khi đàm phán mở rộng (MTU Exchange) là bao nhiêu bytes?',
          options: [
            OptionModel(id: 'A', text: '23 bytes (Payload thực tế 20 bytes)'),
            OptionModel(id: 'B', text: '64 bytes'),
            OptionModel(id: 'C', text: '128 bytes'),
            OptionModel(id: 'D', text: '512 bytes'),
          ],
          correctOptionId: 'A',
        ),
        const QuestionModel(
          id: 5,
          content: 'Khi mức tín hiệu RSSI suy giảm từ -70 dBm xuống -90 dBm, điều này phản ánh điều gì về mặt vật lý?',
          options: [
            OptionModel(id: 'A', text: 'Thiết bị đang tiến lại gần bộ phát sóng hơn'),
            OptionModel(id: 'B', text: 'Thiết bị đang di chuyển ra xa hoặc bị vật cản lớn che chắn'),
            OptionModel(id: 'C', text: 'Băng thông BLE đang được tự động tăng gấp đôi'),
            OptionModel(id: 'D', text: 'Pin của thiết bị sắp hết'),
          ],
          correctOptionId: 'B',
        ),
        const QuestionModel(
          id: 6,
          content: 'Mục đích của việc tính mã kiểm tra toàn vẹn CRC32/MD5 sau khi ghép các Chunk BLE là gì?',
          options: [
            OptionModel(id: 'A', text: 'Tăng tốc độ truyền tải gói tin qua không trung'),
            OptionModel(id: 'B', text: 'Đảm bảo dữ liệu nhận được không bị mất mát hay sai lệch bit trong quá trình truyền BLE'),
            OptionModel(id: 'C', text: 'Tự động sửa lỗi bit mà không cần truyền lại'),
            OptionModel(id: 'D', text: 'Xác thực sinh trắc học của thí sinh'),
          ],
          correctOptionId: 'B',
        ),
      ],
    );
  }
}
