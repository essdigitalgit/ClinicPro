import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/clinic.dart';
import '../models/doctor.dart';
import '../models/availability.dart';
import '../models/time_slot.dart';
import '../services/mock_data_service.dart';

/// Central state provider for the clinic management app.
/// Uses [ChangeNotifier] so widgets rebuild on state changes.
class ClinicProvider extends ChangeNotifier {
  final MockDataService _service = MockDataService();

  // ─── Clinics ───────────────────────────────────────────────────────────────
  List<Clinic> _clinics = [];
  List<Clinic> get clinics => _clinics;

  // ─── Doctors ──────────────────────────────────────────────────────────────
  List<Doctor> _doctors = [];
  List<Doctor> get doctors => _doctors;

  // ─── Availabilities ───────────────────────────────────────────────────────
  List<Availability> _availabilities = [];
  List<Availability> get availabilities => _availabilities;

  // ─── Time slots ───────────────────────────────────────────────────────────
  List<TimeSlot> _timeSlots = [];
  List<TimeSlot> get timeSlots => _timeSlots;

  // ─── Loading flags ────────────────────────────────────────────────────────
  bool _loadingClinics = false;
  bool _loadingDoctors = false;
  bool _loadingAvailability = false;
  bool _loadingSlots = false;
  bool _submitting = false;
  bool _loadingStats = false;

  bool get loadingClinics => _loadingClinics;
  bool get loadingDoctors => _loadingDoctors;
  bool get loadingAvailability => _loadingAvailability;
  bool get loadingSlots => _loadingSlots;
  bool get submitting => _submitting;
  bool get loadingStats => _loadingStats;

  // ─── Dashboard stats ──────────────────────────────────────────────────────
  List<Doctor> _allDoctors = [];
  List<Appointment> _appointments = [];

  int get allDoctorCount => _allDoctors.length;
  int get appointmentCount => _appointments.length;

  Future<void> loadDashboardStats() async {
    _loadingStats = true;
    notifyListeners();
    _clinics = await _service.getClinics();
    _allDoctors = await _service.getAllDoctors();
    _appointments = await _service.getAllAppointments();
    _loadingStats = false;
    notifyListeners();
  }

  // ─── Clinic methods ────────────────────────────────────────────────────────

  Future<void> loadClinics() async {
    _loadingClinics = true;
    notifyListeners();
    _clinics = await _service.getClinics();
    _loadingClinics = false;
    notifyListeners();
  }

  /// Returns null on success, or an error message.
  Future<String?> addClinic({
    required String name,
    required String address,
    required String phone,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.addClinic(name: name, address: address, phone: phone);
      await loadClinics();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ─── Doctor methods ────────────────────────────────────────────────────────

  Future<void> loadDoctors(String clinicId) async {
    _loadingDoctors = true;
    notifyListeners();
    _doctors = await _service.getDoctorsByClinic(clinicId);
    _loadingDoctors = false;
    notifyListeners();
  }

  Future<String?> addDoctor({
    required String name,
    required String specialization,
    required String clinicId,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.addDoctor(
        name: name,
        specialization: specialization,
        clinicId: clinicId,
      );
      await loadDoctors(clinicId);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ─── Availability methods ──────────────────────────────────────────────────

  Future<void> loadAvailability(String doctorId) async {
    _loadingAvailability = true;
    notifyListeners();
    _availabilities = await _service.getAvailabilityByDoctor(doctorId);
    _loadingAvailability = false;
    notifyListeners();
  }

  /// Returns null on success, or a validation/overlap error message.
  Future<String?> addAvailability({
    required String doctorId,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    _submitting = true;
    notifyListeners();
    final error = await _service.addAvailability(
      doctorId: doctorId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
    );
    if (error == null) {
      await loadAvailability(doctorId);
    }
    _submitting = false;
    notifyListeners();
    return error;
  }

  // ─── Time-slot / booking methods ──────────────────────────────────────────

  Future<void> loadAvailableSlots(String doctorId, DateTime date) async {
    _loadingSlots = true;
    _timeSlots = [];
    notifyListeners();
    _timeSlots = await _service.getAvailableSlots(doctorId, date);
    _loadingSlots = false;
    notifyListeners();
  }

  void clearTimeSlots() {
    _timeSlots = [];
    notifyListeners();
  }

  Future<String?> bookAppointment({
    required String clinicId,
    required String doctorId,
    required String patientName,
    required DateTime date,
    required TimeOfDay startTime,
  }) async {
    _submitting = true;
    notifyListeners();
    final error = await _service.bookAppointment(
      clinicId: clinicId,
      doctorId: doctorId,
      patientName: patientName,
      date: date,
      startTime: startTime,
    );
    // Refresh slots after booking so the booked slot disappears
    if (error == null) {
      await loadAvailableSlots(doctorId, date);
    }
    _submitting = false;
    notifyListeners();
    return error;
  }
}
