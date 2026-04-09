import 'package:flutter/material.dart';

/// A patient appointment booked against a [ClinicSlot] with an assigned doctor.
class Appointment {
  final String id;
  final String clinicId;
  final String doctorId;
  final String slotId;
  final String patientName;
  final DateTime appointmentDate;
  final TimeOfDay appointmentTime;
  final String status; // 'confirmed' | 'cancelled' | 'completed'

  const Appointment({
    required this.id,
    required this.clinicId,
    required this.doctorId,
    required this.slotId,
    required this.patientName,
    required this.appointmentDate,
    required this.appointmentTime,
    this.status = 'confirmed',
  });
}
