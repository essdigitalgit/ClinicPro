import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/clinic.dart';
import '../models/doctor.dart';
import '../models/availability.dart';
import '../models/appointment.dart';
import '../models/time_slot.dart';

/// In-memory mock data service that simulates a backend API.
/// All public methods return [Future]s with a short delay to mimic network calls.
class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal() {
    _seedData();
  }

  static const _uuid = Uuid();
  static const _delay = Duration(milliseconds: 400);

  // ─── In-memory stores ──────────────────────────────────────────────────────
  final List<Clinic> _clinics = [];
  final List<Doctor> _doctors = [];
  final List<Availability> _availabilities = [];
  final List<Appointment> _appointments = [];

  // ─── Seed with realistic India demo data ──────────────────────────────────
  void _seedData() {
    final c1 = Clinic(
      id: 'c1',
      name: 'Apollo Clinic',
      address: '12 MG Road, Connaught Place, New Delhi – 110001',
      phone: '+91-11-4600-1234',
    );
    final c2 = Clinic(
      id: 'c2',
      name: 'Fortis Healthsquare',
      address: '78 Linking Road, Bandra West, Mumbai – 400050',
      phone: '+91-22-6600-5678',
    );
    _clinics.addAll([c1, c2]);

    final d1 = Doctor(
      id: 'd1',
      name: 'Dr. Priya Sharma',
      specialization: 'General Physician',
      clinicId: 'c1',
    );
    final d2 = Doctor(
      id: 'd2',
      name: 'Dr. Rajesh Iyer',
      specialization: 'Cardiologist',
      clinicId: 'c1',
    );
    final d3 = Doctor(
      id: 'd3',
      name: 'Dr. Meena Nair',
      specialization: 'Paediatrician',
      clinicId: 'c2',
    );
    final d4 = Doctor(
      id: 'd4',
      name: 'Dr. Arjun Verma',
      specialization: 'Orthopaedic Surgeon',
      clinicId: 'c2',
    );
    _doctors.addAll([d1, d2, d3, d4]);

    // Monday 9:00–12:00 for Dr. Sharma
    _availabilities.add(Availability(
      id: 'a1',
      doctorId: 'd1',
      dayOfWeek: 1,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 12, minute: 0),
    ));
    // Wednesday 14:00–17:00 for Dr. Sharma
    _availabilities.add(Availability(
      id: 'a2',
      doctorId: 'd1',
      dayOfWeek: 3,
      startTime: const TimeOfDay(hour: 14, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ));
    // Tuesday 10:00–13:00 for Dr. Iyer
    _availabilities.add(Availability(
      id: 'a3',
      doctorId: 'd2',
      dayOfWeek: 2,
      startTime: const TimeOfDay(hour: 10, minute: 0),
      endTime: const TimeOfDay(hour: 13, minute: 0),
    ));
    // Friday 9:00–12:00 for Dr. Iyer
    _availabilities.add(Availability(
      id: 'a5',
      doctorId: 'd2',
      dayOfWeek: 5,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 12, minute: 0),
    ));
    // Thursday 9:00–11:00 for Dr. Nair
    _availabilities.add(Availability(
      id: 'a4',
      doctorId: 'd3',
      dayOfWeek: 4,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 11, minute: 0),
    ));
    // Saturday 10:00–13:00 for Dr. Verma
    _availabilities.add(Availability(
      id: 'a6',
      doctorId: 'd4',
      dayOfWeek: 6,
      startTime: const TimeOfDay(hour: 10, minute: 0),
      endTime: const TimeOfDay(hour: 13, minute: 0),
    ));
  }

  // ─── Clinic methods ────────────────────────────────────────────────────────

  Future<List<Clinic>> getClinics() async {
    await Future.delayed(_delay);
    return List.unmodifiable(_clinics);
  }

  Future<Clinic> addClinic({
    required String name,
    required String address,
    required String phone,
  }) async {
    await Future.delayed(_delay);
    final clinic = Clinic(
      id: _uuid.v4(),
      name: name,
      address: address,
      phone: phone,
    );
    _clinics.add(clinic);
    return clinic;
  }

  // ─── Doctor methods ────────────────────────────────────────────────────────

  Future<List<Doctor>> getDoctorsByClinic(String clinicId) async {
    await Future.delayed(_delay);
    return _doctors.where((d) => d.clinicId == clinicId).toList();
  }

  Future<List<Doctor>> getAllDoctors() async {
    await Future.delayed(_delay);
    return List.unmodifiable(_doctors);
  }

  Future<Doctor> addDoctor({
    required String name,
    required String specialization,
    required String clinicId,
  }) async {
    await Future.delayed(_delay);
    final doctor = Doctor(
      id: _uuid.v4(),
      name: name,
      specialization: specialization,
      clinicId: clinicId,
    );
    _doctors.add(doctor);
    return doctor;
  }

  // ─── Availability methods ──────────────────────────────────────────────────

  Future<List<Availability>> getAvailabilityByDoctor(String doctorId) async {
    await Future.delayed(_delay);
    return _availabilities
        .where((a) => a.doctorId == doctorId)
        .toList();
  }

  /// Adds an availability slot, returning an error message on overlap or null on success.
  Future<String?> addAvailability({
    required String doctorId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    await Future.delayed(_delay);

    // Validate time order
    if (_toMinutes(startTime) >= _toMinutes(endTime)) {
      return 'Start time must be before end time.';
    }

    // Check for overlaps with existing slots on the same day
    final existing = _availabilities
        .where((a) => a.doctorId == doctorId && a.dayOfWeek == dayOfWeek);
    for (final a in existing) {
      if (_timesOverlap(startTime, endTime, a.startTime, a.endTime)) {
        return 'This slot overlaps with an existing availability (${_formatTime(a.startTime)} – ${_formatTime(a.endTime)}).';
      }
    }

    _availabilities.add(Availability(
      id: _uuid.v4(),
      doctorId: doctorId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
    ));
    return null; // success
  }

  // ─── Appointment / time-slot methods ──────────────────────────────────────

  /// Returns available 30-minute [TimeSlot]s for [doctorId] on [date].
  Future<List<TimeSlot>> getAvailableSlots(
    String doctorId,
    DateTime date,
  ) async {
    await Future.delayed(_delay);

    // ISO weekday: 1=Monday … 7=Sunday
    final dayOfWeek = date.weekday;

    final blocks = _availabilities
        .where((a) => a.doctorId == doctorId && a.dayOfWeek == dayOfWeek)
        .toList();

    if (blocks.isEmpty) return [];

    // Already booked slots for this doctor on this date
    final booked = _appointments
        .where((a) =>
            a.doctorId == doctorId &&
            a.date.year == date.year &&
            a.date.month == date.month &&
            a.date.day == date.day)
        .map((a) => _toMinutes(a.startTime))
        .toSet();

    final slots = <TimeSlot>[];
    for (final block in blocks) {
      int current = _toMinutes(block.startTime);
      final end = _toMinutes(block.endTime);
      while (current + 30 <= end) {
        final slotStart = _fromMinutes(current);
        final slotEnd = _fromMinutes(current + 30);
        slots.add(TimeSlot(
          startTime: slotStart,
          endTime: slotEnd,
          isAvailable: !booked.contains(current),
        ));
        current += 30;
      }
    }
    return slots;
  }

  /// Books an appointment. Returns an error message or null on success.
  Future<String?> bookAppointment({
    required String clinicId,
    required String doctorId,
    required String patientName,
    required DateTime date,
    required TimeOfDay startTime,
  }) async {
    await Future.delayed(_delay);

    final endTime = _fromMinutes(_toMinutes(startTime) + 30);

    // Check double booking
    final conflict = _appointments.any((a) =>
        a.doctorId == doctorId &&
        a.date.year == date.year &&
        a.date.month == date.month &&
        a.date.day == date.day &&
        _toMinutes(a.startTime) == _toMinutes(startTime));
    if (conflict) {
      return 'This slot has already been booked.';
    }

    _appointments.add(Appointment(
      id: _uuid.v4(),
      clinicId: clinicId,
      doctorId: doctorId,
      patientName: patientName,
      date: date,
      startTime: startTime,
      endTime: endTime,
    ));
    return null; // success
  }

  Future<List<Appointment>> getAllAppointments() async {
    await Future.delayed(_delay);
    return List.unmodifiable(_appointments);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay _fromMinutes(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  bool _timesOverlap(
    TimeOfDay s1,
    TimeOfDay e1,
    TimeOfDay s2,
    TimeOfDay e2,
  ) {
    final start1 = _toMinutes(s1);
    final end1 = _toMinutes(e1);
    final start2 = _toMinutes(s2);
    final end2 = _toMinutes(e2);
    return start1 < end2 && start2 < end1;
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
