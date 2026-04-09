import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/clinic.dart';
import '../models/doctor.dart';
import '../models/clinic_slot.dart';
import '../models/doctor_assignment.dart';
import '../models/appointment.dart';

/// All data is stored in-memory. Every public method simulates async I/O.
class MockDataService {
  static const _uuid = Uuid();

  // ── In-memory stores ───────────────────────────────────────────────────────
  final List<Clinic> _clinics = [];
  final List<Doctor> _doctors = [];
  final List<ClinicSlot> _slots = [];
  final List<DoctorAssignment> _assignments = [];
  final List<Appointment> _appointments = [];

  MockDataService() {
    _seed();
  }

  // ── Seeding ────────────────────────────────────────────────────────────────
  void _seed() {
    // Clinics
    _clinics.addAll(const [
      Clinic(
        id: 'clinic1',
        name: 'Apollo Clinic',
        address: 'A-12, Connaught Place, New Delhi',
        phone: '+91-11-4987-6543',
      ),
      Clinic(
        id: 'clinic2',
        name: 'Fortis Healthsquare',
        address: 'Linking Road, Bandra West, Mumbai',
        phone: '+91-22-6789-0123',
      ),
      Clinic(
        id: 'clinic3',
        name: 'Manipal Hospital',
        address: 'Old Airport Road, Bengaluru',
        phone: '+91-80-5890-1234',
      ),
    ]);

    // Doctors — onboarded independently
    _doctors.addAll(const [
      Doctor(
        id: 'doc1',
        name: 'Dr. Priya Sharma',
        specialization: 'General Physician',
        phone: '+91-98765-43210',
        email: 'priya.sharma@apollo.in',
      ),
      Doctor(
        id: 'doc2',
        name: 'Dr. Rajesh Iyer',
        specialization: 'Cardiologist',
        phone: '+91-98765-43211',
        email: 'rajesh.iyer@fortis.in',
      ),
      Doctor(
        id: 'doc3',
        name: 'Dr. Meena Nair',
        specialization: 'Paediatrician',
        phone: '+91-98765-43212',
      ),
      Doctor(
        id: 'doc4',
        name: 'Dr. Arjun Verma',
        specialization: 'Orthopaedic Surgeon',
        phone: '+91-98765-43213',
      ),
      Doctor(
        id: 'doc5',
        name: 'Dr. Sunita Patel',
        specialization: 'Dermatologist',
        phone: '+91-88001-23456',
        email: 'sunita.patel@fortis.in',
      ),
      Doctor(
        id: 'doc6',
        name: 'Dr. Arun Kumar',
        specialization: 'Neurologist',
        phone: '+91-88001-23457',
      ),
    ]);

    // Clinic Slots — Apollo (clinic1)
    _slots.addAll(const [
      ClinicSlot(
        id: 'cs1',
        clinicId: 'clinic1',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 12, minute: 0),
        label: 'Morning OPD',
      ),
      ClinicSlot(
        id: 'cs2',
        clinicId: 'clinic1',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        label: 'Afternoon OPD',
      ),
      ClinicSlot(
        id: 'cs3',
        clinicId: 'clinic1',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 12, minute: 0),
        label: 'Wednesday OPD',
      ),
      ClinicSlot(
        id: 'cs4',
        clinicId: 'clinic1',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 0),
        label: 'Friday Morning',
      ),
      ClinicSlot(
        id: 'cs5',
        clinicId: 'clinic1',
        dayOfWeek: 6,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 0),
        label: 'Saturday OPD',
      ),
    ]);

    // Clinic Slots — Fortis (clinic2)
    _slots.addAll(const [
      ClinicSlot(
        id: 'cs6',
        clinicId: 'clinic2',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 0),
        label: 'Tuesday Morning',
      ),
      ClinicSlot(
        id: 'cs7',
        clinicId: 'clinic2',
        dayOfWeek: 4,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        label: 'Thursday Evening',
      ),
      ClinicSlot(
        id: 'cs8',
        clinicId: 'clinic2',
        dayOfWeek: 6,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 12, minute: 0),
        label: 'Saturday Special',
      ),
    ]);

    // Clinic Slots — Manipal (clinic3)
    _slots.addAll(const [
      ClinicSlot(
        id: 'cs9',
        clinicId: 'clinic3',
        dayOfWeek: 1,
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 0),
        label: 'Monday OPD',
      ),
      ClinicSlot(
        id: 'cs10',
        clinicId: 'clinic3',
        dayOfWeek: 3,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
        label: 'Wednesday OPD',
      ),
      ClinicSlot(
        id: 'cs11',
        clinicId: 'clinic3',
        dayOfWeek: 5,
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 0),
        label: 'Friday Morning',
      ),
    ]);

    // Doctor Assignments — intentionally empty on app start.
    // All clinic slots begin in the "Unassigned" state.

    // Appointments — empty on app start (no assignments seeded).
  }

  // ── CRUD: Clinics ──────────────────────────────────────────────────────────
  Future<List<Clinic>> getClinics() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_clinics);
  }

  Future<void> addClinic(Clinic clinic) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _clinics.add(clinic);
  }

  Future<void> updateClinic(Clinic clinic) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _clinics.indexWhere((c) => c.id == clinic.id);
    if (idx != -1) _clinics[idx] = clinic;
  }

  // ── CRUD: Doctors ──────────────────────────────────────────────────────────
  Future<List<Doctor>> getDoctors() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_doctors);
  }

  Future<void> addDoctor(Doctor doctor) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _doctors.add(doctor);
  }

  Future<void> updateDoctor(Doctor doctor) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _doctors.indexWhere((d) => d.id == doctor.id);
    if (idx != -1) _doctors[idx] = doctor;
  }

  // ── CRUD: Clinic Slots ────────────────────────────────────────────────────
  Future<List<ClinicSlot>> getSlotsByClinic(String clinicId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _slots.where((s) => s.clinicId == clinicId).toList()
      ..sort((a, b) {
        if (a.dayOfWeek != b.dayOfWeek) return a.dayOfWeek - b.dayOfWeek;
        final aStart = a.startTime.hour * 60 + a.startTime.minute;
        final bStart = b.startTime.hour * 60 + b.startTime.minute;
        return aStart - bStart;
      });
  }

  Future<String?> addClinicSlot({
    required String clinicId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? label,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final startMins = startTime.hour * 60 + startTime.minute;
    final endMins = endTime.hour * 60 + endTime.minute;
    if (endMins <= startMins) return 'End time must be after start time';
    if (endMins - startMins < 30) return 'Slot must be at least 30 minutes';

    final conflict = _slots.where(
      (s) => s.clinicId == clinicId && s.dayOfWeek == dayOfWeek,
    ).any((s) {
      final sStart = s.startTime.hour * 60 + s.startTime.minute;
      final sEnd = s.endTime.hour * 60 + s.endTime.minute;
      return startMins < sEnd && endMins > sStart;
    });
    if (conflict) return 'This overlaps with an existing slot on that day';

    _slots.add(ClinicSlot(
      id: _uuid.v4(),
      clinicId: clinicId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      label: label,
    ));
    return null;
  }

  Future<void> deleteClinicSlot(String slotId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _slots.removeWhere((s) => s.id == slotId);
    _assignments.removeWhere((a) => a.slotId == slotId);
    // Cancel future appointments for this slot
    _appointments.removeWhere(
      (a) => a.slotId == slotId && a.appointmentDate.isAfter(DateTime.now()),
    );
  }

  // ── Doctor Assignments ────────────────────────────────────────────────────
  Future<List<DoctorAssignment>> getAssignmentsByClinic(String clinicId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _assignments.where((a) => a.clinicId == clinicId).toList();
  }

  /// Validates and persists a [DoctorAssignment].
  /// Returns an error string on conflict, or null on success.
  Future<String?> saveAssignment(DoctorAssignment assignment) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Slot must exist
    final slotExists = _slots.any((s) => s.id == assignment.slotId);
    if (!slotExists) return 'Slot not found';

    // For one-time assignments: slot can have at most one permanent assignment
    if (assignment.assignmentType == AssignmentType.oneTime &&
        assignment.startDate == null) {
      final existing = _assignments.where((a) =>
          a.slotId == assignment.slotId &&
          a.assignmentType == AssignmentType.oneTime &&
          a.startDate == null);
      if (existing.isNotEmpty) {
        return 'This slot already has a permanent one-time assignment';
      }
    }

    _assignments.add(assignment);
    return null;
  }

  Future<void> removeDoctorAssignment(String assignmentId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _assignments.removeWhere((a) => a.id == assignmentId);
  }

  Future<void> updateAssignment(DoctorAssignment updated) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _assignments.indexWhere((a) => a.id == updated.id);
    if (idx != -1) _assignments[idx] = updated;
  }

  // ── Booking ───────────────────────────────────────────────────────────────
  Future<List<BookingOption>> getAvailableBookingOptions({
    required String clinicId,
    required DateTime date,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final dayOfWeek = date.weekday;
    final daySlots = _slots
        .where((s) => s.clinicId == clinicId && s.dayOfWeek == dayOfWeek)
        .toList()
      ..sort((a, b) {
        final aS = a.startTime.hour * 60 + a.startTime.minute;
        final bS = b.startTime.hour * 60 + b.startTime.minute;
        return aS - bS;
      });

    final options = <BookingOption>[];
    for (final slot in daySlots) {
      // Find an assignment that is active on [date]
      final assignment = _assignments
          .where((a) => a.slotId == slot.id && a.isActiveOn(date))
          .firstOrNull;
      if (assignment == null) continue; // Only bookable if a doctor is assigned

      final doctor = _doctors.firstWhere((d) => d.id == assignment.doctorId);

      // Generate 30-min intervals
      final allTimes = <TimeOfDay>[];
      int cur = slot.startTime.hour * 60 + slot.startTime.minute;
      final end = slot.endTime.hour * 60 + slot.endTime.minute;
      while (cur + 30 <= end) {
        allTimes.add(TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
        cur += 30;
      }

      final bookedKeys = _appointments
          .where((a) =>
              a.slotId == slot.id &&
              a.doctorId == assignment.doctorId &&
              _sameDate(a.appointmentDate, date))
          .map((a) => '${a.appointmentTime.hour}:${a.appointmentTime.minute}')
          .toSet();

      options.add(BookingOption(
        slot: slot,
        assignment: assignment,
        doctor: doctor,
        availableTimes:
            allTimes.where((t) => !bookedKeys.contains('${t.hour}:${t.minute}')).toList(),
        bookedTimes:
            allTimes.where((t) => bookedKeys.contains('${t.hour}:${t.minute}')).toList(),
      ));
    }
    return options;
  }

  Future<String?> bookAppointment({
    required String clinicId,
    required String doctorId,
    required String slotId,
    required String patientName,
    required DateTime date,
    required TimeOfDay time,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (patientName.trim().isEmpty) return 'Patient name is required';

    final duplicate = _appointments.any((a) =>
        a.doctorId == doctorId &&
        a.slotId == slotId &&
        _sameDate(a.appointmentDate, date) &&
        a.appointmentTime.hour == time.hour &&
        a.appointmentTime.minute == time.minute);
    if (duplicate) return 'This time slot is already booked';

    _appointments.add(Appointment(
      id: _uuid.v4(),
      clinicId: clinicId,
      doctorId: doctorId,
      slotId: slotId,
      patientName: patientName.trim(),
      appointmentDate: date,
      appointmentTime: time,
    ));
    return null;
  }

  Future<List<Appointment>> getAppointments({String? clinicId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (clinicId != null) {
      return _appointments.where((a) => a.clinicId == clinicId).toList();
    }
    return List.unmodifiable(_appointments);
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  // ── Doctor schedule (cross-clinic) ────────────────────────────────────
  Future<List<DoctorAssignment>> getAssignmentsByDoctor(String doctorId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _assignments.where((a) => a.doctorId == doctorId).toList();
  }

  /// Returns the [ClinicSlot] for a given [slotId], or null.
  ClinicSlot? getSlotById(String slotId) =>
      _slots.where((s) => s.id == slotId).firstOrNull;
  // ── Stats ─────────────────────────────────────────────────────────────────
  int get clinicCount => _clinics.length;
  int get doctorCount => _doctors.length;
  int get slotCount => _slots.length;
  int get assignmentCount => _assignments.length;
  int get appointmentCount => _appointments.length;
}

/// Aggregated booking data for one slot on a given date.
class BookingOption {
  final ClinicSlot slot;
  final DoctorAssignment assignment;
  final Doctor doctor;
  final List<TimeOfDay> availableTimes;
  final List<TimeOfDay> bookedTimes;

  const BookingOption({
    required this.slot,
    required this.assignment,
    required this.doctor,
    required this.availableTimes,
    required this.bookedTimes,
  });
}
