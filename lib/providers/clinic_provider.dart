import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/clinic.dart';
import '../models/doctor.dart';
import '../models/clinic_slot.dart';
import '../models/doctor_assignment.dart';
import '../models/appointment.dart';
import '../services/mock_data_service.dart';

class ClinicProvider extends ChangeNotifier {
  static const _uuid = Uuid();
  final MockDataService _service = MockDataService();

  // ── State ──────────────────────────────────────────────────────────────────
  List<Clinic> _clinics = [];
  List<Doctor> _doctors = [];
  List<ClinicSlot> _slots = [];
  List<DoctorAssignment> _assignments = [];
  List<Appointment> _appointments = [];
  List<BookingOption> _bookingOptions = [];

  bool _loadingClinics = false;
  bool _loadingDoctors = false;
  bool _loadingSlots = false;
  bool _loadingAssignments = false;
  bool _loadingBooking = false;
  bool _submitting = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Clinic> get clinics => _clinics;
  List<Doctor> get doctors => _doctors;
  List<ClinicSlot> get slots => _slots;
  List<DoctorAssignment> get assignments => _assignments;
  List<Appointment> get appointments => _appointments;
  List<BookingOption> get bookingOptions => _bookingOptions;

  bool get loadingClinics => _loadingClinics;
  bool get loadingDoctors => _loadingDoctors;
  bool get loadingSlots => _loadingSlots;
  bool get loadingAssignments => _loadingAssignments;
  bool get loadingBooking => _loadingBooking;
  bool get submitting => _submitting;
  String? get error => _error;

  int get clinicCount => _clinics.length;
  int get doctorCount => _doctors.length;
  int get appointmentCount => _appointments.length;

  // ── Dashboard / bulk load ─────────────────────────────────────────────────
  Future<void> loadDashboardStats() async {
    _loadingClinics = true;
    _error = null;
    notifyListeners();
    try {
      await Future.wait([
        _service.getClinics().then((v) => _clinics = v),
        _service.getDoctors().then((v) => _doctors = v),
        _service.getAppointments().then((v) => _appointments = v),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingClinics = false;
      notifyListeners();
    }
  }

  // ── Clinics ────────────────────────────────────────────────────────────────
  Future<void> loadClinics() async {
    _loadingClinics = true;
    _error = null;
    notifyListeners();
    try {
      _clinics = await _service.getClinics();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingClinics = false;
      notifyListeners();
    }
  }

  Future<void> addClinic({
    required String name,
    required String address,
    required String phone,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.addClinic(Clinic(
        id: _uuid.v4(),
        name: name,
        address: address,
        phone: phone,
      ));
      _clinics = await _service.getClinics();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> updateClinic(Clinic clinic) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.updateClinic(clinic);
      _clinics = await _service.getClinics();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ── Doctors ────────────────────────────────────────────────────────────────
  Future<void> loadDoctors() async {
    _loadingDoctors = true;
    _error = null;
    notifyListeners();
    try {
      _doctors = await _service.getDoctors();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingDoctors = false;
      notifyListeners();
    }
  }

  Future<String?> addDoctor({
    required String name,
    required String specialization,
    String? phone,
    String? email,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.addDoctor(Doctor(
        id: _uuid.v4(),
        name: name,
        specialization: specialization,
        phone: phone?.isEmpty == true ? null : phone,
        email: email?.isEmpty == true ? null : email,
      ));
      _doctors = await _service.getDoctors();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<String?> updateDoctor(Doctor doctor) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.updateDoctor(doctor);
      _doctors = await _service.getDoctors();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ── Clinic Slots ───────────────────────────────────────────────────────────
  Future<void> loadSlots(String clinicId) async {
    _loadingSlots = true;
    _error = null;
    notifyListeners();
    try {
      _slots = await _service.getSlotsByClinic(clinicId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingSlots = false;
      notifyListeners();
    }
  }

  Future<String?> addClinicSlot({
    required String clinicId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? label,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      final err = await _service.addClinicSlot(
        clinicId: clinicId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        label: label,
      );
      if (err == null) _slots = await _service.getSlotsByClinic(clinicId);
      return err;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> deleteClinicSlot(String slotId, String clinicId) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.deleteClinicSlot(slotId);
      _slots = await _service.getSlotsByClinic(clinicId);
      _assignments = await _service.getAssignmentsByClinic(clinicId);
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ── Assignments ────────────────────────────────────────────────────────────
  Future<void> loadAssignments(String clinicId) async {
    _loadingAssignments = true;
    _error = null;
    notifyListeners();
    try {
      _assignments = await _service.getAssignmentsByClinic(clinicId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingAssignments = false;
      notifyListeners();
    }
  }

  Future<String?> saveAssignment(DoctorAssignment assignment) async {
    _submitting = true;
    notifyListeners();
    try {
      final err = await _service.saveAssignment(assignment);
      if (err == null) {
        _assignments = await _service.getAssignmentsByClinic(assignment.clinicId);
      }
      return err;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> removeDoctorAssignment(
      String assignmentId, String clinicId) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.removeDoctorAssignment(assignmentId);
      _assignments = await _service.getAssignmentsByClinic(clinicId);
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ── Doctor schedule (cross-clinic) ────────────────────────────────────
  List<DoctorAssignment> _doctorSchedule = [];
  bool _loadingDoctorSchedule = false;

  List<DoctorAssignment> get doctorSchedule => _doctorSchedule;
  bool get loadingDoctorSchedule => _loadingDoctorSchedule;

  Future<void> loadDoctorSchedule(String doctorId) async {
    _loadingDoctorSchedule = true;
    notifyListeners();
    try {
      _doctorSchedule = await _service.getAssignmentsByDoctor(doctorId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingDoctorSchedule = false;
      notifyListeners();
    }
  }

  /// Check if [doctorId] has a conflicting permanent assignment on [dayOfWeek]
  /// that overlaps with [start]–[end].
  bool isDoctorBusy(String doctorId, int dayOfWeek, TimeOfDay start, TimeOfDay end) {
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    for (final a in _doctorSchedule) {
      if (a.doctorId != doctorId) continue;
      final slot = _service.getSlotById(a.slotId);
      if (slot == null) continue;
      if (slot.dayOfWeek != dayOfWeek) continue;
      final sStart = slot.startTime.hour * 60 + slot.startTime.minute;
      final sEnd = slot.endTime.hour * 60 + slot.endTime.minute;
      if (startMin < sEnd && endMin > sStart) return true;
    }
    return false;
  }

  // ── Appointments / Booking ─────────────────────────────────────────────────
  Future<void> loadAppointments({String? clinicId}) async {
    _loadingClinics = true;
    notifyListeners();
    try {
      _appointments = await _service.getAppointments(clinicId: clinicId);
    } finally {
      _loadingClinics = false;
      notifyListeners();
    }
  }

  Future<void> loadBookingOptions({
    required String clinicId,
    required DateTime date,
  }) async {
    _loadingBooking = true;
    notifyListeners();
    try {
      _bookingOptions = await _service.getAvailableBookingOptions(
        clinicId: clinicId,
        date: date,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingBooking = false;
      notifyListeners();
    }
  }

  Future<String?> bookAppointment({
    required String clinicId,
    required String doctorId,
    required String slotId,
    required String patientName,
    required DateTime date,
    required TimeOfDay time,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      return await _service.bookAppointment(
        clinicId: clinicId,
        doctorId: doctorId,
        slotId: slotId,
        patientName: patientName,
        date: date,
        time: time,
      );
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
