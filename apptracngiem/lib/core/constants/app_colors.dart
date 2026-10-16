import 'package:flutter/material.dart';

/// Bảng màu giao diện Sáng / Trắng (Light Mode Theme) hiện đại, tinh tế và tương phản cao
class AppColors {
  // Light Backgrounds
  static const Color background = Color(0xFFF8FAFC); // Slate-50: Trắng ánh xám dịu mắt, cao cấp
  static const Color backgroundSecondary = Color(0xFFFFFFFF); // Trắng tinh khiết cho thanh điều hướng, bottom bar
  static const Color surfaceDark = Color(0xFFFFFFFF); // Nền trắng sạch cho Modals & Dialogs
  static const Color surfaceCard = Color(0xFFFFFFFF); // Thẻ card trắng tinh tế

  // Glassmorphism & Viền trong suốt hiện đại
  static Color glassSurface = const Color(0xFFFFFFFF).withOpacity(0.92);
  static Color glassBorder = const Color(0xFFE2E8F0); // Slate-200: Viền sắc nét, chống chìm card trên nền trắng
  static Color glassBorderBright = const Color(0xFF0284C7).withOpacity(0.35);

  // Hiệu ứng đổ bóng Neumorphism dịu mắt (Light Shadow)
  static const Color neuDarkShadow = Color(0x140F172A); // Đổ bóng slate 8%
  static const Color neuLightShadow = Color(0xFFFFFFFF); // Viền sáng trắng

  // Màu thương hiệu chính (High-contrast Accent Colors)
  static const Color primary = Color(0xFF0284C7); // Sky-600 / Ocean Blue (Đậm, nổi bật trên nền trắng)
  static const Color primaryLight = Color(0xFF38BDF8); // Sky-400
  static const Color secondary = Color(0xFF059669); // Emerald-600 (Xanh ngọc lục bảo sắc nét)
  static const Color secondaryLight = Color(0xFF10B981); // Emerald-500
  static const Color accentIndigo = Color(0xFF4F46E5); // Indigo-600

  // Trạng thái & Đo mức sóng RSSI Geofencing
  static const Color rssiGood = Color(0xFF059669); // Emerald
  static const Color rssiWarning = Color(0xFFD97706); // Amber-600
  static const Color rssiCritical = Color(0xFFDC2626); // Red-600
  static const Color rssiDisabled = Color(0xFF94A3B8); // Slate-400

  // Màu chữ (Typography) tương phản cao trên nền trắng
  static const Color textPrimary = Color(0xFF0F172A); // Slate-900: Đen ánh xanh than, cực kỳ rõ nét
  static const Color textSecondary = Color(0xFF475569); // Slate-600: Chữ phụ, dễ đọc
  static const Color textMuted = Color(0xFF94A3B8); // Slate-400: Gợi ý, chú thích

  // Các dải màu Gradient rực rỡ, trang nhã
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
