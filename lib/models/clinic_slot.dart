import 'package:flutter/material.dart';

/// A recurring weekly working window belonging to a [Clinic].
class ClinicSlot {
  final String id;
  final String clinicId;
  final int dayOfWeek; // 1 = Monday … 7 = Sunday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? label;

  const ClinicSlot({
    required this.id,
    required this.clinicId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.label,
  });

  String get dayName {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return days[dayOfWeek - 1];
  }

  String get dayShort {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayOfWeek - 1];
  }

  int get durationMinutes {
    final endMins = endTime.hour * 60 + endTime.minute;
    final startMins = startTime.hour * 60 + startTime.minute;
    return endMins - startMins;
  }

  /// Number of 30-minute appointment intervals this slot can hold.
  int get appointmentCount => durationMinutes ~/ 30;
}
