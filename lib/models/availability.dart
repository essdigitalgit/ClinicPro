import 'package:flutter/material.dart';

/// Represents a doctor's availability block for a given day of the week.
class Availability {
  final String id;
  final String doctorId;

  /// Day of week: 1 = Monday … 7 = Sunday (ISO 8601).
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Availability({
    required this.id,
    required this.doctorId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  /// Returns the day name for display.
  String get dayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[(dayOfWeek - 1).clamp(0, 6)];
  }
}
