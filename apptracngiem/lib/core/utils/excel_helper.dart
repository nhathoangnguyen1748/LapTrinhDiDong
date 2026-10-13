import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/exam_model.dart';
import '../../models/submission_model.dart';

class ExcelHelper {
  /// Parse danh sách câu hỏi từ mảng bytes của file .xlsx
  /// Cấu trúc cột mong đợi:
  /// Cột 0: STT (Số thứ tự hoặc Mã câu)
  /// Cột 1: Nội dung câu hỏi
  /// Cột 2: Phương án A
  /// Cột 3: Phương án B
  /// Cột 4: Phương án C
  /// Cột 5: Phương án D
  /// Cột 6: Đáp án đúng (A, B, C, D)
  static List<QuestionModel> parseQuestionsFromExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('File Excel rỗng hoặc không có bảng dữ liệu');
    }

    // Lấy sheet đầu tiên hoặc sheet có dữ liệu
    Sheet? targetSheet;
    for (final tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName];
      if (sheet != null && sheet.rows.isNotEmpty) {
        targetSheet = sheet;
        break;
      }
    }

    if (targetSheet == null || targetSheet.rows.isEmpty) {
      throw Exception('Không tìm thấy sheet nào có dữ liệu trong file Excel');
    }

    final questions = <QuestionModel>[];
    final rows = targetSheet.rows;

    // Xác định dòng bắt đầu (bỏ qua dòng tiêu đề nếu có)
    int startRow = 0;
    if (rows.isNotEmpty) {
      final firstRowText = rows[0]
          .map((c) => c?.value?.toString().toLowerCase().trim() ?? '')
          .join(' ');
      if (firstRowText.contains('câu') ||
          firstRowText.contains('question') ||
          firstRowText.contains('stt') ||
          firstRowText.contains('phương án') ||
          firstRowText.contains('đáp án')) {
        startRow = 1; // Dòng 0 là tiêu đề
      }
    }

    int questionId = 1;
    for (int r = startRow; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      // Đọc các ô dữ liệu
      String getCellText(int colIndex) {
        if (colIndex >= row.length) return '';
        final val = row[colIndex]?.value;
        if (val == null) return '';
        return val.toString().trim();
      }

      final col0 = getCellText(0);
      final col1 = getCellText(1);
      final col2 = getCellText(2);
      final col3 = getCellText(3);
      final col4 = getCellText(4);
      final col5 = getCellText(5);
      final col6 = getCellText(6);

      // Nếu chỉ có 6 cột (không có cột STT, câu hỏi ở cột 0)
      String content;
      String optA;
      String optB;
      String optC;
      String optD;
      String correctOpt;

      if (col6.isNotEmpty) {
        // Có 7 cột: [STT, Nội dung, A, B, C, D, Đáp án]
        content = col1;
        optA = col2;
        optB = col3;
        optC = col4;
        optD = col5;
        correctOpt = col6.toUpperCase().trim();
      } else {
        // Có thể là 6 cột: [Nội dung, A, B, C, D, Đáp án]
        content = col0;
        optA = col1;
        optB = col2;
        optC = col3;
        optD = col4;
        correctOpt = col5.toUpperCase().trim();
      }

      // Bỏ qua dòng trống
      if (content.isEmpty && optA.isEmpty && optB.isEmpty) continue;

      // Chuẩn hóa đáp án đúng: chỉ lấy chữ cái A, B, C, D
      final match = RegExp(r'[A-D]').firstMatch(correctOpt);
      final finalCorrect = match != null ? match.group(0)! : 'A';

      final options = <OptionModel>[
        OptionModel(id: 'A', text: optA.isNotEmpty ? optA : 'Phương án A'),
        OptionModel(id: 'B', text: optB.isNotEmpty ? optB : 'Phương án B'),
        OptionModel(id: 'C', text: optC.isNotEmpty ? optC : 'Phương án C'),
        OptionModel(id: 'D', text: optD.isNotEmpty ? optD : 'Phương án D'),
      ];

      questions.add(
        QuestionModel(
          id: questionId++,
          content: content.isNotEmpty ? content : 'Câu hỏi $questionId',
          options: options,
          correctOptionId: finalCorrect,
        ),
      );
    }

    if (questions.isEmpty) {
      throw Exception('Không đọc được câu hỏi nào từ file Excel. Vui lòng kiểm tra định dạng các cột.');
    }

    return questions;
  }

  /// Tạo file Excel mẫu (.xlsx) chứa câu hỏi mẫu chuẩn để giảng viên tải về soạn đề
  static Uint8List createQuestionTemplateExcel() {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[defaultSheet];

    // Tiêu đề các cột
    sheet.appendRow([
      TextCellValue('STT'),
      TextCellValue('Nội dung câu hỏi'),
      TextCellValue('Phương án A'),
      TextCellValue('Phương án B'),
      TextCellValue('Phương án C'),
      TextCellValue('Phương án D'),
      TextCellValue('Đáp án đúng (A/B/C/D)'),
    ]);

    // Dữ liệu câu hỏi mẫu
    sheet.appendRow([
      IntCellValue(1),
      TextCellValue('Giao thức Bluetooth Low Energy (BLE) hoạt động ở băng tần số nào?'),
      TextCellValue('2.4 GHz ISM Band'),
      TextCellValue('5.0 GHz UNII Band'),
      TextCellValue('900 MHz Sub-GHz'),
      TextCellValue('433 MHz RFID'),
      TextCellValue('A'),
    ]);

    sheet.appendRow([
      IntCellValue(2),
      TextCellValue('Đơn vị đo chuẩn của giá trị RSSI trong mạng không dây là gì?'),
      TextCellValue('Milliwatt (mW)'),
      TextCellValue('Decibel-milliwatts (dBm)'),
      TextCellValue('Microvolt (μV)'),
      TextCellValue('Hertz (Hz)'),
      TextCellValue('B'),
    ]);

    sheet.appendRow([
      IntCellValue(3),
      TextCellValue('Trong mô hình bảo mật đề thi LocalQuiz, thuật toán mã hóa đối xứng nào được sử dụng?'),
      TextCellValue('DES'),
      TextCellValue('RC4'),
      TextCellValue('AES-256-CBC'),
      TextCellValue('Blowfish'),
      TextCellValue('C'),
    ]);

    sheet.appendRow([
      IntCellValue(4),
      TextCellValue('Ngưỡng khoảng cách an toàn RSSI mặc định cảnh báo thí sinh ra khỏi phòng thi là bao nhiêu?'),
      TextCellValue('-50 dBm'),
      TextCellValue('-65 dBm'),
      TextCellValue('-75 dBm'),
      TextCellValue('-85 dBm'),
      TextCellValue('D'),
    ]);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Lỗi mã hóa file Excel mẫu');
    }
    return Uint8List.fromList(bytes);
  }

  /// Xuất danh sách bài nộp thi ra file Excel (.xlsx) bảng điểm chi tiết
  static Uint8List exportSubmissionsToExcel({
    required String examTitle,
    required String examId,
    required List<SubmissionModel> submissions,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['BangDiem'];
    // Chỉ lấy các kết quả nộp bài thực tế
    final validSubmissions = submissions.where((s) => s.studentId.trim().isNotEmpty).toList();

    // Tiêu đề các cột chuẩn
    sheet.appendRow([
      TextCellValue('STT'),
      TextCellValue('Mã Sinh Viên / SBD'),
      TextCellValue('Họ và Tên'),
      TextCellValue('Lớp'),
      TextCellValue('Số câu đúng'),
      TextCellValue('Tổng số câu'),
      TextCellValue('Điểm Hệ 10'),
      TextCellValue('Kết quả'),
      TextCellValue('Thời gian làm'),
      TextCellValue('Số lần vi phạm'),
      TextCellValue('Mã biên nhận (ACK)'),
      TextCellValue('Thời gian nộp'),
    ]);

    for (int i = 0; i < validSubmissions.length; i++) {
      final s = validSubmissions[i];
      final ratio = s.totalQuestions > 0 ? (s.score / s.totalQuestions) : 0.0;
      final score10 = (ratio * 10).toStringAsFixed(2);
      final isPassed = ratio >= 0.5;
      final minutes = s.timeTakenSeconds ~/ 60;
      final seconds = s.timeTakenSeconds % 60;

      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(s.studentId),
        TextCellValue(s.studentName),
        TextCellValue(s.classroom ?? 'Chưa phân lớp'),
        IntCellValue(s.score),
        IntCellValue(s.totalQuestions),
        DoubleCellValue(double.tryParse(score10) ?? 0.0),
        TextCellValue(isPassed ? 'ĐẠT' : 'CHƯA ĐẠT'),
        TextCellValue('${minutes}p ${seconds}s'),
        IntCellValue(s.violationCount),
        TextCellValue(s.receiptHash ?? 'N/A'),
        TextCellValue(s.submittedAt.toString().split('.')[0]),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Lỗi mã hóa file Excel kết quả');
    }
    return Uint8List.fromList(bytes);
  }

  /// Lưu file tạm và mở hộp thoại chia sẻ (Share sheet) để người dùng lưu vào máy hoặc gửi qua Zalo/Drive/Email
  static Future<void> shareOrSaveExcelFile({
    required Uint8List bytes,
    required String filename,
    required String title,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [
        XFile(
          filePath,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: filename,
        ),
      ],
      subject: title,
      text: title,
    );
  }
}
