import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/ble_rssi_helper.dart';

class RssiBadge extends StatelessWidget {
  final int? rssi;
  final bool showLabel;
  final bool isCompact;

  const RssiBadge({
    super.key,
    required this.rssi,
    this.showLabel = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = BleRssiHelper.getStatus(rssi);
    final statusColor = BleRssiHelper.getStatusColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSignalBars(status, statusColor),
          const SizedBox(width: 8),
          Text(
            rssi != null ? '$rssi dBm' : '-- dBm',
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: statusColor,
              letterSpacing: -0.2,
            ),
          ),
          if (showLabel && !isCompact) ...[
            const SizedBox(width: 6),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _getShortLabel(status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalBars(RssiStatus status, Color color) {
    int activeBars = 0;
    switch (status) {
      case RssiStatus.optimal:
        activeBars = 4;
        break;
      case RssiStatus.warning:
        activeBars = 2;
        break;
      case RssiStatus.critical:
        activeBars = 1;
        break;
      case RssiStatus.disconnected:
        activeBars = 0;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final height = 5.0 + (index * 3.5);
        final isActive = index < activeBars;
        return Container(
          width: 3.0,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1.0),
          decoration: BoxDecoration(
            color: isActive ? color : AppColors.rssiDisabled.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  String _getShortLabel(RssiStatus status) {
    switch (status) {
      case RssiStatus.optimal:
        return 'Ổn định';
      case RssiStatus.warning:
        return 'Yếu';
      case RssiStatus.critical:
        return 'Nguy hiểm';
      case RssiStatus.disconnected:
        return 'Mất sóng';
    }
  }
}
