import 'package:flutter/material.dart';

/// Represents a single 30-minute time slot for appointment booking.
class TimeSlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isAvailable;

  const TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
  });
}
