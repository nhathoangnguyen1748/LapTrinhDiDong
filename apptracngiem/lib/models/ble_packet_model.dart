import 'dart:convert';

enum BlePacketType {
  handshake,
  heartbeat,
  ack,
  error,
}

class BlePacketModel {
  final BlePacketType type;
  final String senderId;
  final Map<String, dynamic> data;
  final int timestamp;

  const BlePacketModel({
    required this.type,
    required this.senderId,
    required this.data,
    required this.timestamp,
  });

  factory BlePacketModel.ack({
    required String examId,
    required String studentId,
    required bool isSuccess,
    String? message,
  }) {
    return BlePacketModel(
      type: BlePacketType.ack,
      senderId: 'HOST_PROCTOR',
      data: {
        'exam_id': examId,
        'student_id': studentId,
        'status': isSuccess ? 'SUCCESS' : 'FAILED',
        'message': message ?? 'Bài thi đã được Giám thị ghi nhận thành công.',
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory BlePacketModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'ack';
    final type = BlePacketType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => BlePacketType.ack,
    );

    return BlePacketModel(
      type: type,
      senderId: json['sender_id'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'sender_id': senderId,
      'data': data,
      'timestamp': timestamp,
    };
  }

  String toRawJson() => jsonEncode(toJson());

  factory BlePacketModel.fromRawJson(String str) =>
      BlePacketModel.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
