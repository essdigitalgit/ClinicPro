import 'package:flutter/material.dart';
import '../models/time_slot.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

/// A selectable chip representing a single 30-minute [TimeSlot].
class TimeSlotChip extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const TimeSlotChip({
    super.key,
    required this.slot,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = slot.isAvailable;

    Color bg, fg, borderColor;
    List<BoxShadow>? shadows;

    if (!available) {
      bg = const Color(0xFFF1F5F9);
      fg = AppTheme.textTertiary;
      borderColor = AppTheme.borderLight;
    } else if (isSelected) {
      bg = AppTheme.primary;
      fg = Colors.white;
      borderColor = AppTheme.primary;
      shadows = [
        BoxShadow(
          color: AppTheme.primary.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 3),
        )
      ];
    } else {
      bg = AppTheme.primaryContainer;
      fg = AppTheme.primary;
      borderColor = const Color(0xFFB8D8EF);
    }

    return GestureDetector(
      onTap: available ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: shadows,
        ),
        child: Text(
          TimeUtils.format12(slot.startTime),
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            decoration: available ? null : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }
}
