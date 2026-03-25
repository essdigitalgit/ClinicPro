import 'package:flutter/material.dart';

/// Shared time formatting helpers used across screens.
class TimeUtils {
  TimeUtils._();

  /// Formats [TimeOfDay] to "HH:MM" (24-hour).
  static String format24(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formats [TimeOfDay] to "hh:MM AM/PM".
  static String format12(TimeOfDay t) {
    final period = t.hour < 12 ? 'AM' : 'PM';
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$hour:$m $period';
  }

  /// Day name from ISO weekday integer (1=Monday … 7=Sunday).
  static String dayName(int isoWeekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return names[(isoWeekday - 1).clamp(0, 6)];
  }
}
