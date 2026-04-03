import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_text_styles.dart';

enum CrowdLevel { low, medium, high }

class CrowdDensityBadge extends StatelessWidget {
  final int queueCount;
  final bool showLabel;

  const CrowdDensityBadge({
    super.key,
    required this.queueCount,
    this.showLabel = true,
  });

  CrowdLevel get _level {
    if (queueCount <= AppConstants.crowdLowMax) return CrowdLevel.low;
    if (queueCount <= AppConstants.crowdMediumMax) return CrowdLevel.medium;
    return CrowdLevel.high;
  }

  Color get _color {
    switch (_level) {
      case CrowdLevel.low:
        return AppColors.crowdLow;
      case CrowdLevel.medium:
        return AppColors.crowdMedium;
      case CrowdLevel.high:
        return AppColors.crowdHigh;
    }
  }

  String get _label {
    switch (_level) {
      case CrowdLevel.low:
        return 'LOW';
      case CrowdLevel.medium:
        return 'MEDIUM';
      case CrowdLevel.high:
        return 'HIGH';
    }
  }

  String get _emoji {
    switch (_level) {
      case CrowdLevel.low:
        return '🟢';
      case CrowdLevel.medium:
        return '🟡';
      case CrowdLevel.high:
        return '🔴';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: _color.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _color.withOpacity(0.8),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              _label,
              style: AppTextStyles.labelSmall.copyWith(color: _color),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Crowd Bar Indicator ─────────────────────────────────────────
class CrowdBar extends StatelessWidget {
  final int current;
  final int max;

  const CrowdBar({super.key, required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final ratio = (current / max).clamp(0.0, 1.0);
    final color = ratio < 0.3
        ? AppColors.crowdLow
        : ratio < 0.7
            ? AppColors.crowdMedium
            : AppColors.crowdHigh;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Queue Load', style: AppTextStyles.bodySmall),
            Text('$current / $max', style: AppTextStyles.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}