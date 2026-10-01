import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/ble_rssi_helper.dart';
import '../../providers/proximity_geofence_provider.dart';
import 'glass_card.dart';
import 'rssi_badge.dart';

/// Lớp hiển thị lớp phủ (Overlay) cảnh báo khi thí sinh ra khỏi vùng thi (vượt ngưỡng RSSI)
class OutOfBoundsOverlay extends ConsumerWidget {
  const OutOfBoundsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lắng nghe trạng thái Geofence từ provider
    final geofence = ref.watch(geofenceProvider);

    // Nếu vẫn ở trong vùng an toàn, không hiển thị gì cả
    if (!geofence.isOutOfBounds) {
      return const SizedBox.shrink();
    }

    // Hiển thị lớp phủ làm mờ và chặn mọi thao tác UI bên dưới
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withOpacity(0.75),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          alignment: Alignment.center,
          child: SingleChildScrollView( // Bọc trong ScrollView chống overflow màn hình nhỏ
            child: GlassCard(
              blur: 24,
              borderColor: AppColors.rssiCritical.withOpacity(0.6),
              color: const Color(0xFF1E1015).withOpacity(0.85),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Biểu tượng cảnh báo với hiệu ứng nhấp nháy liên tục
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.rssiCritical.withOpacity(0.15),
                      border: Border.all(
                        color: AppColors.rssiCritical.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.fmd_bad_rounded,
                      color: AppColors.rssiCritical,
                      size: 40,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),

                  const SizedBox(height: 20),

                  // Tiêu đề
                  const Text(
                    'VI PHẠM PHẠM VI PHÒNG THI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.rssiCritical,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Lời giải thích tương ứng với trạng thái (Mất kết nối hoặc Sóng yếu)
                  Text(
                    geofence.status == RssiStatus.disconnected
                        ? 'Đã mất kết nối BLE với máy Giám thị quá 10 giây!\nĐồng hồ làm bài đã TẠM DỪNG và màn hình bị KHÓA BẢO VỆ.'
                        : 'Cường độ sóng BLE (${geofence.rssi} dBm) dưới ngưỡng quy định (-85 dBm)!\nBạn đang ở quá xa vị trí thi chuẩn. Đồng hồ làm bài đã TẠM DỪNG.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Hiển thị huy hiệu mức độ sóng thực tế
                  RssiBadge(rssi: geofence.rssi, showLabel: true),

                  const SizedBox(height: 24),

                  // Gợi ý cách khắc phục
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.near_me_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Vui lòng di chuyển lại gần máy Giám thị để tự động mở khóa tiếp tục làm bài.',
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Khối thanh trượt mô phỏng để test trên máy tính
                  const SizedBox(height: 16),
                  _buildSimulatorRecoverySlider(ref, geofence),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Trả về widget thanh trượt mô phỏng RSSI giúp kiểm thử trên PC/Emulator
  Widget _buildSimulatorRecoverySlider(WidgetRef ref, GeofenceState geofence) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kiểm thử RSSI (Simulator):',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            Text(
              '${geofence.rssi ?? -90} dBm',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            thumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            overlayColor: AppColors.primary.withOpacity(0.2),
            trackHeight: 3,
          ),
          child: Slider(
            min: -100,
            max: -50,
            value: (geofence.rssi ?? -90).toDouble().clamp(-100, -50),
            onChanged: (val) {
              // Gửi mức sóng ảo về cho provider
              ref.read(geofenceProvider.notifier).setManualRssi(val.toInt());
            },
          ),
        ),
      ],
    );
  }
}
