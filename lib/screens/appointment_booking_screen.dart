import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/clinic.dart';
import '../models/doctor.dart';
import '../models/time_slot.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/time_slot_chip.dart';
import '../widgets/loading_overlay.dart';

/// Premium appointment booking screen.
/// Select clinic → doctor → date → time slot → patient name → confirm.
class AppointmentBookingScreen extends StatefulWidget {
  final Clinic? initialClinic;
  final Doctor? initialDoctor;

  const AppointmentBookingScreen({
    super.key,
    this.initialClinic,
    this.initialDoctor,
  });

  @override
  State<AppointmentBookingScreen> createState() =>
      _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState
    extends State<AppointmentBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();

  Clinic? _selectedClinic;
  Doctor? _selectedDoctor;
  DateTime? _selectedDate;
  TimeSlot? _selectedSlot;

  List<Clinic> _clinics = [];
  List<Doctor> _doctors = [];
  bool _loadingClinics = false;
  bool _loadingDoctors = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadClinics();
      if (widget.initialClinic != null) {
        setState(() => _selectedClinic = widget.initialClinic);
        await _loadDoctors(widget.initialClinic!.id);
        if (widget.initialDoctor != null) {
          setState(() => _selectedDoctor = widget.initialDoctor);
        }
      }
    });
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    super.dispose();
  }

  Future<void> _loadClinics() async {
    setState(() => _loadingClinics = true);
    final provider = context.read<ClinicProvider>();
    await provider.loadClinics();
    if (!mounted) return;
    setState(() {
      _clinics = provider.clinics.toList();
      _loadingClinics = false;
    });
  }

  Future<void> _loadDoctors(String clinicId) async {
    setState(() {
      _loadingDoctors = true;
      _selectedDoctor = null;
      _selectedDate = null;
      _selectedSlot = null;
    });
    context.read<ClinicProvider>().clearTimeSlots();
    final provider = context.read<ClinicProvider>();
    await provider.loadDoctors(clinicId);
    if (!mounted) return;
    setState(() {
      _doctors = provider.doctors.toList();
      _loadingDoctors = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null || _selectedDoctor == null) return;
    if (!mounted) return;
    setState(() {
      _selectedDate = picked;
      _selectedSlot = null;
    });
    await context
        .read<ClinicProvider>()
        .loadAvailableSlots(_selectedDoctor!.id, picked);
  }

  Future<void> _book() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClinic == null ||
        _selectedDoctor == null ||
        _selectedDate == null ||
        _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all steps before booking.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final patientName = _patientNameController.text.trim();
    final slotStart = _selectedSlot!.startTime;

    final error = await context.read<ClinicProvider>().bookAppointment(
          clinicId: _selectedClinic!.id,
          doctorId: _selectedDoctor!.id,
          patientName: patientName,
          date: _selectedDate!,
          startTime: slotStart,
        );

    if (!mounted) return;
    if (error == null) {
      final doctorName = _selectedDoctor!.name;
      final clinicName = _selectedClinic!.name;
      final date = _selectedDate!;
      setState(() => _selectedSlot = null);
      _patientNameController.clear();

      showDialog(
        context: context,
        builder: (_) => _BookingSuccessDialog(
          patientName: patientName,
          doctorName: doctorName,
          clinicName: clinicName,
          date: date,
          time: slotStart,
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicProvider>(
      builder: (context, provider, _) => LoadingOverlay(
        isLoading: provider.submitting,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Book Appointment'),
            backgroundColor: AppTheme.surface,
            automaticallyImplyLeading: widget.initialClinic != null,
            leading: widget.initialClinic != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // Step 1 – Clinic & Doctor
                _StepCard(
                  stepNumber: 1,
                  title: 'Clinic & Doctor',
                  icon: Icons.local_hospital_rounded,
                  child: Column(
                    children: [
                      _loadingClinics
                          ? _LoadingRow(label: 'Loading clinics…')
                          : DropdownButtonFormField<Clinic>(
                              key: ValueKey(_selectedClinic),
                              value: _selectedClinic,
                              decoration: const InputDecoration(
                                labelText: 'Select Clinic',
                                prefixIcon: Icon(
                                    Icons.local_hospital_outlined,
                                    size: 20),
                              ),
                              items: _clinics
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c.name,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14)),
                                      ))
                                  .toList(),
                              onChanged: (c) {
                                if (c == null) return;
                                setState(() => _selectedClinic = c);
                                _loadDoctors(c.id);
                              },
                              validator: (v) =>
                                  v == null ? 'Select a clinic' : null,
                            ),
                      const SizedBox(height: 12),
                      _loadingDoctors
                          ? _LoadingRow(label: 'Loading doctors…')
                          : DropdownButtonFormField<Doctor>(
                              key: ValueKey(_selectedDoctor),
                              value: _selectedDoctor,
                              decoration: const InputDecoration(
                                labelText: 'Select Doctor',
                                prefixIcon:
                                    Icon(Icons.person_outline, size: 20),
                              ),
                              items: _doctors
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(d.name,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            Text(d.specialization,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme
                                                        .textTertiary)),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (d) {
                                setState(() {
                                  _selectedDoctor = d;
                                  _selectedDate = null;
                                  _selectedSlot = null;
                                });
                                provider.clearTimeSlots();
                              },
                              validator: (v) =>
                                  v == null ? 'Select a doctor' : null,
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Step 2 – Date
                _StepCard(
                  stepNumber: 2,
                  title: 'Select Date',
                  icon: Icons.calendar_today_rounded,
                  child: GestureDetector(
                    onTap: _selectedDoctor != null ? _pickDate : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedDate != null
                            ? AppTheme.primaryContainer
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedDate != null
                              ? const Color(0xFFB8D8EF)
                              : AppTheme.border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 20,
                            color: _selectedDate != null
                                ? AppTheme.primary
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? _selectedDoctor == null
                                      ? 'Select a doctor first'
                                      : 'Tap to pick a date'
                                  : DateFormat('EEEE, d MMMM yyyy')
                                      .format(_selectedDate!),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedDate != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedDate != null
                                    ? AppTheme.primary
                                    : AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          if (_selectedDate != null)
                            const Icon(Icons.edit_calendar_rounded,
                                size: 16, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Step 3 – Time slots
                _StepCard(
                  stepNumber: 3,
                  title: 'Available Slots',
                  icon: Icons.access_time_rounded,
                  child: provider.loadingSlots
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child:
                              Center(child: CircularProgressIndicator()),
                        )
                      : provider.timeSlots.isEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              child: Column(
                                children: [
                                  Icon(
                                    _selectedDate == null
                                        ? Icons.touch_app_rounded
                                        : Icons.event_busy_rounded,
                                    size: 32,
                                    color: AppTheme.textTertiary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedDate == null
                                        ? 'Select a date to view available slots'
                                        : 'No available slots on this day',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textTertiary),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: provider.timeSlots
                                  .map((slot) => TimeSlotChip(
                                        slot: slot,
                                        isSelected: _selectedSlot == slot,
                                        onTap: slot.isAvailable
                                            ? () => setState(
                                                () => _selectedSlot = slot)
                                            : null,
                                      ))
                                  .toList(),
                            ),
                ),
                const SizedBox(height: 12),

                // Step 4 – Patient name
                _StepCard(
                  stepNumber: 4,
                  title: 'Patient Details',
                  icon: Icons.person_outline_rounded,
                  child: TextFormField(
                    controller: _patientNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Patient Full Name',
                      hintText: 'e.g. Rahul Mehta',
                      prefixIcon: Icon(Icons.person_rounded, size: 20),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Patient name is required'
                            : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Selected summary badge
                if (_selectedSlot != null &&
                    _selectedDate != null &&
                    _selectedDoctor != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.successBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.success.withOpacity(0.3),
                          width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: eighteen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDoctor!.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary),
                              ),
                              Text(
                                '${DateFormat('d MMM yyyy').format(_selectedDate!)} · ${TimeUtils.format12(_selectedSlot!.startTime)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Book button
                FilledButton.icon(
                  onPressed: _book,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Confirm Booking'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                    backgroundColor: _selectedSlot != null
                        ? AppTheme.primary
                        : AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: constant_identifier_names
const eighteen = 18.0;

// ── Section card ──────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final IconData icon;
  final Widget child;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    stepNumber.toString(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  final String label;

  const _LoadingRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textTertiary, fontSize: 13)),
      ],
    );
  }
}

// ── Success dialog ────────────────────────────────────────────────────────────

class _BookingSuccessDialog extends StatelessWidget {
  final String patientName;
  final String doctorName;
  final String clinicName;
  final DateTime date;
  final TimeOfDay time;

  const _BookingSuccessDialog({
    required this.patientName,
    required this.doctorName,
    required this.clinicName,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.successBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 40, color: AppTheme.success),
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Appointment booked for $patientName',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Doctor', value: doctorName),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Clinic', value: clinicName),
                  const SizedBox(height: 8),
                  _InfoRow(
                      label: 'Date',
                      value: DateFormat('EEE, d MMM yyyy').format(date)),
                  const SizedBox(height: 8),
                  _InfoRow(
                      label: 'Time', value: TimeUtils.format12(time)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ),
      ],
    );
  }
}
