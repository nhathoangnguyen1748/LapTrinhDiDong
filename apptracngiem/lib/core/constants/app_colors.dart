import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds (Giao diện sáng thanh lịch, dịu mắt, chống mỏi)
  static const Color background = Color(0xFFF8FAFC);         // Slate 50: Nền chính dịu mát
  static const Color backgroundSecondary = Color(0xFFFFFFFF);// Trắng tinh khôi: Nền phụ / Appbar / Dialog
  static const Color surfaceDark = Color(0xFFF1F5F9);         // Slate 100: Khối input, track bar, unselected
  static const Color surfaceCard = Color(0xFFFFFFFF);         // Pure white: Card nổi bật

  // Glassmorphism & Borders
  static Color glassSurface = Colors.white.withOpacity(0.92);
  static const Color glassBorder = Color(0xFFE2E8F0);        // Slate 200: Viền tinh tế, sắc nét
  static Color glassBorderBright = const Color(0xFF0284C7).withOpacity(0.35);

  // Neumorphism Shadows (Hiệu ứng bóng đổ nhẹ trên nền sáng)
  static const Color neuDarkShadow = Color(0x120F172A);      // Bóng mờ xám dịu
  static const Color neuLightShadow = Color(0x90FFFFFF);     // Ánh sáng nổi viền

  // Accent Colors (Xanh biển công nghệ và Xanh ngọc tươi sáng)
  static const Color primary = Color(0xFF0284C7);            // Sky 600: Tương phản xuất sắc trên nền sáng
  static const Color primaryLight = Color(0xFF38BDF8);       // Sky 400
  static const Color secondary = Color(0xFF059669);          // Emerald 600: Xanh ngọc thành công
  static const Color secondaryLight = Color(0xFF10B981);     // Emerald 500
  static const Color accentIndigo = Color(0xFF4F46E5);       // Indigo 600

  // Status & RSSI Colors (Chuẩn WCAG trên nền sáng)
  static const Color rssiGood = Color(0xFF059669);          // Emerald
  static const Color rssiWarning = Color(0xFFD97706);       // Amber 600: Dễ nhìn hơn vàng nhạt
  static const Color rssiCritical = Color(0xFFDC2626);      // Red 600: Đỏ cảnh báo sắc nét
  static const Color rssiDisabled = Color(0xFF94A3B8);      // Slate 400

  // Text Colors (Độ tương phản cao, chữ đen than sắc sảo)
  static const Color textPrimary = Color(0xFF0F172A);        // Slate 900: Đen than cực kỳ rõ nét
  static const Color textSecondary = Color(0xFF475569);      // Slate 600: Xám đậm cho thông tin phụ
  static const Color textMuted = Color(0xFF64748B);          // Slate 500: Gợi ý, thời gian, placeholder

  // Gradients (Màu chuyển tiếp tươi sáng, hiện đại)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient criticalGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
