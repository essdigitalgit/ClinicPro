import 'package:flutter/material.dart';

/// Represents a booked appointment.
class Appointment {
  final String id;
  final String clinicId;
  final String doctorId;
  final String patientName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Appointment({
    required this.id,
    required this.clinicId,
    required this.doctorId,
    required this.patientName,
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}
