import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/clinic.dart';
import '../providers/clinic_provider.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/loading_overlay.dart';

/// Step-by-step appointment booking:
///  1. Select clinic
///  2. Select date
///  3. Browse available slots (grouped by clinic slot)
///  4. Pick time + patient name → confirm
class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() =>
      _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  Clinic? _selectedClinic;
  DateTime _selectedDate = DateTime.now();
  BookingOption? _selectedOption;
  TimeOfDay? _selectedTime;
  final _patientNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicProvider>().loadClinics();
    });
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _selectedOption = null;
      _selectedTime = null;
    });
    if (_selectedClinic != null) _loadOptions();
  }

  void _loadOptions() {
    if (_selectedClinic == null) return;
    context.read<ClinicProvider>().loadBookingOptions(
          clinicId: _selectedClinic!.id,
          date: _selectedDate,
        );
    setState(() {
      _selectedOption = null;
      _selectedTime = null;
    });
  }

  Future<void> _book() async {
    if (!_formKey.currentState!.validate()) { return; }
    if (_selectedClinic == null ||
        _selectedOption == null ||
        _selectedTime == null) { return; }

    final err = await context.read<ClinicProvider>().bookAppointment(
          clinicId: _selectedClinic!.id,
          doctorId: _selectedOption!.doctor.id,
          slotId: _selectedOption!.slot.id,
          patientName: _patientNameController.text.trim(),
          date: _selectedDate,
          time: _selectedTime!,
        );
    if (!mounted) return;

    if (err == null) {
      // Reload options to reflect newly booked time
      _loadOptions();
      setState(() {
        _selectedOption = null;
        _selectedTime = null;
        _patientNameController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                  'Appointment confirmed with ${_selectedOption?.doctor.name ?? ''}!'),
            ],
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicProvider>(
      builder: (context, provider, _) {
        return LoadingOverlay(
          isLoading: provider.submitting,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppTheme.surface,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Book Appointment',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Find a doctor & reserve your slot',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textTertiary)),
                ],
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Step 1: Select clinic ─────────────────────────────────
                  _SectionHeader(
                    step: '1',
                    title: 'Select Clinic',
                    isDone: _selectedClinic != null,
                  ),
                  const SizedBox(height: 10),
                  _ClinicSelector(
                    clinics: provider.clinics,
                    selected: _selectedClinic,
                    onSelect: (c) {
                      setState(() {
                        _selectedClinic = c;
                        _selectedOption = null;
                        _selectedTime = null;
                      });
                      _loadOptions();
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Step 2: Select date ───────────────────────────────────
                  _SectionHeader(
                    step: '2',
                    title: 'Select Date',
                    isDone: true,
                  ),
                  const SizedBox(height: 10),
                  _DateButton(
                    date: _selectedDate,
                    onTap: _pickDate,
                  ),

                  if (_selectedClinic != null) ...[
                    const SizedBox(height: 20),

                    // ── Step 3: Available slots ─────────────────────────────
                    _SectionHeader(
                      step: '3',
                      title: 'Available Slots',
                      isDone: _selectedOption != null,
                    ),
                    const SizedBox(height: 10),

                    if (provider.loadingBooking)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ))
                    else if (provider.bookingOptions.isEmpty)
                      _NoSlotsCard(
                        clinicName: _selectedClinic!.name,
                        date: _selectedDate,
                      )
                    else
                      ...provider.bookingOptions.map(
                        (opt) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BookingOptionCard(
                            option: opt,
                            isSelected: _selectedOption == opt,
                            selectedTime: _selectedOption == opt
                                ? _selectedTime
                                : null,
                            onSelectTime: (t) {
                              setState(() {
                                _selectedOption = opt;
                                _selectedTime = t;
                              });
                            },
                          ),
                        ),
                      ),
                  ],

                  // ── Step 4: Patient name + book ───────────────────────────
                  if (_selectedOption != null && _selectedTime != null) ...[
                    const SizedBox(height: 20),
                    _SectionHeader(
                      step: '4',
                      title: 'Patient Details',
                      isDone: false,
                    ),
                    const SizedBox(height: 10),

                    // Summary card
                    _BookingSummaryCard(
                      option: _selectedOption!,
                      time: _selectedTime!,
                      date: _selectedDate,
                    ),
                    const SizedBox(height: 14),

                    // Patient form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _patientNameController,
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Patient name is required'
                                    : null,
                            decoration: const InputDecoration(
                              labelText: 'Patient Name',
                              hintText: 'Enter full name',
                              prefixIcon: Icon(Icons.person_outline_rounded,
                                  size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _book,
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: const Text('Confirm Booking'),
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String step;
  final String title;
  final bool isDone;

  const _SectionHeader(
      {required this.step, required this.title, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isDone ? AppTheme.success : AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white)
                : Text(step,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

// ── Clinic selector ───────────────────────────────────────────────────────────

class _ClinicSelector extends StatelessWidget {
  final List<Clinic> clinics;
  final Clinic? selected;
  final void Function(Clinic) onSelect;

  const _ClinicSelector(
      {required this.clinics, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (clinics.isEmpty) {
      return const _EmptyCard(
          message: 'No clinics found. Add a clinic first.');
    }
    return Column(
      children: [
        for (int i = 0; i < clinics.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _ClinicCard(
            clinic: clinics[i],
            isSelected: selected?.id == clinics[i].id,
            onTap: () => onSelect(clinics[i]),
          ),
        ],
      ],
    );
  }
}

class _ClinicCard extends StatelessWidget {
  final Clinic clinic;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClinicCard({
    required this.clinic,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.borderLight,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.20)
                    : AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.local_hospital_rounded,
                size: 24,
                color: isSelected ? Colors.white : AppTheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          clinic.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.80)
                                : AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : AppTheme.borderLight,
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: AppTheme.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date button ───────────────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final fmt = DateFormat('EEE, d MMM yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  size: 20, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? 'Today' : fmt.format(date),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                  if (!isToday)
                    Text('Tap to change',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textTertiary))
                  else
                    Text(fmt.format(date),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_rounded,
                size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Booking option card ───────────────────────────────────────────────────────

class _BookingOptionCard extends StatelessWidget {
  final BookingOption option;
  final bool isSelected;
  final TimeOfDay? selectedTime;
  final void Function(TimeOfDay) onSelectTime;

  const _BookingOptionCard({
    required this.option,
    required this.isSelected,
    required this.selectedTime,
    required this.onSelectTime,
  });

  @override
  Widget build(BuildContext context) {
    final slot = option.slot;
    final doctor = option.doctor;
    final available = option.availableTimes;
    final booked = option.bookedTimes;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary.withAlpha(120)
              : AppTheme.borderLight,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot + doctor header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded,
                    size: 22, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctor.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    Text(doctor.specialization,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textTertiary)),
                  ],
                ),
              ),
              // Slot window badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${TimeUtils.format12(slot.startTime)}\n\u2013 ${TimeUtils.format12(slot.endTime)}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Available/booked counts
          Row(children: [
            _ChipCount(
                label: '${available.length} available',
                color: AppTheme.success,
                bg: AppTheme.successBg),
            const SizedBox(width: 8),
            if (booked.isNotEmpty)
              _ChipCount(
                  label: '${booked.length} booked',
                  color: AppTheme.error,
                  bg: AppTheme.errorBg),
          ]),
          const SizedBox(height: 12),

          if (available.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_rounded,
                      size: 16, color: AppTheme.error),
                  SizedBox(width: 8),
                  Text('All time slots fully booked',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.error)),
                ],
              ),
            )
          else ...[
            const Text('Select Time',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...available.map((t) {
                  final isSel =
                      isSelected && selectedTime?.hour == t.hour &&
                          selectedTime?.minute == t.minute;
                  return GestureDetector(
                    onTap: () => onSelectTime(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppTheme.primary
                            : AppTheme.successBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel
                              ? AppTheme.primary
                              : AppTheme.success.withAlpha(60),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        TimeUtils.format12(t),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? Colors.white
                                : AppTheme.success),
                      ),
                    ),
                  );
                }),
                ...booked.map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.border, width: 1.5),
                      ),
                      child: Text(
                        TimeUtils.format12(t),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.border,
                            decoration: TextDecoration.lineThrough),
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Booking summary card ──────────────────────────────────────────────────────

class _BookingSummaryCard extends StatelessWidget {
  final BookingOption option;
  final TimeOfDay time;
  final DateTime date;

  const _BookingSummaryCard(
      {required this.option, required this.time, required this.date});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.event_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.doctor.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(option.doctor.specialization,
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(TimeUtils.format12(time),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(fmt.format(date),
                  style: const TextStyle(
                      color: Color(0xCCFFFFFF), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── No slots card ─────────────────────────────────────────────────────────────

class _NoSlotsCard extends StatelessWidget {
  final String clinicName;
  final DateTime date;

  const _NoSlotsCard({required this.clinicName, required this.date});

  @override
  Widget build(BuildContext context) {
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 32, color: AppTheme.warning),
          ),
          const SizedBox(height: 14),
          const Text('No Available Slots',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            '$clinicName has no bookable slots on ${days[date.weekday - 1]}s, or all slots are unassigned.\nTry a different date.',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

class _ChipCount extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _ChipCount(
      {required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 20, color: AppTheme.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textTertiary)),
          ),
        ],
      ),
    );
  }
}
