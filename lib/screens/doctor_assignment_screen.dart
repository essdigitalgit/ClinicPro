import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/clinic.dart';
import '../models/clinic_slot.dart';
import '../models/doctor.dart';
import '../models/doctor_assignment.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/loading_overlay.dart';

// ── Main screen ───────────────────────────────────────────────────────────────

class DoctorAssignmentScreen extends StatefulWidget {
  final Clinic clinic;
  const DoctorAssignmentScreen({super.key, required this.clinic});

  @override
  State<DoctorAssignmentScreen> createState() =>
      _DoctorAssignmentScreenState();
}

class _DoctorAssignmentScreenState extends State<DoctorAssignmentScreen> {
  int _selectedDay = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    final p = context.read<ClinicProvider>();
    Future.wait([
      p.loadSlots(widget.clinic.id),
      p.loadAssignments(widget.clinic.id),
      p.loadDoctors(),
    ]);
  }

  Future<void> _openScheduler(ClinicSlot slot) async {
    final provider = context.read<ClinicProvider>();
    if (provider.doctors.isEmpty) {
      if (!mounted) return;
      _showSnack('No doctors available. Add doctors first.', AppTheme.warning);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SchedulerSheet(
        clinic: widget.clinic,
        slot: slot,
        doctors: provider.doctors,
      ),
    );
    if (mounted) await provider.loadAssignments(widget.clinic.id);
  }

  Future<void> _removeAssignment(
      DoctorAssignment assignment, Doctor doctor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Assignment'),
        content: Text(
            'Remove ${doctor.name}\'s "${assignment.scheduleSummary}" assignment?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context
        .read<ClinicProvider>()
        .removeDoctorAssignment(assignment.id, widget.clinic.id);
    if (!mounted) return;
    _showSnack('Assignment removed', AppTheme.success);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicProvider>(
      builder: (context, provider, _) {
        final slots = provider.slots;
        final assignments = provider.assignments;
        final doctors = provider.doctors;
        final isLoading = provider.loadingSlots ||
            provider.loadingAssignments ||
            provider.loadingDoctors;

        return LoadingOverlay(
          isLoading: provider.submitting,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: Column(
              children: [
                _AssignmentHeader(
                  clinic: widget.clinic,
                  slots: slots,
                  assignments: assignments,
                  onBack: () => Navigator.pop(context),
                ),
                if (isLoading)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else if (slots.isEmpty)
                  const Expanded(child: _EmptyScreen())
                else ...[
                  _DaySelector(
                    slots: slots,
                    assignments: assignments,
                    selectedDay: _selectedDay,
                    onDaySelected: (d) =>
                        setState(() => _selectedDay = d),
                  ),
                  Expanded(
                    child: _AssignmentPanel(
                      selectedDay: _selectedDay,
                      slots: slots,
                      assignments: assignments,
                      doctors: doctors,
                      onSchedule: _openScheduler,
                      onRemove: _removeAssignment,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _AssignmentHeader extends StatelessWidget {
  final Clinic clinic;
  final List<ClinicSlot> slots;
  final List<DoctorAssignment> assignments;
  final VoidCallback onBack;

  const _AssignmentHeader({
    required this.clinic,
    required this.slots,
    required this.assignments,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final assignedSlots =
        slots.where((s) => assignments.any((a) => a.slotId == s.id)).length;
    final unassigned = slots.length - assignedSlots;
    final top = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
      padding: EdgeInsets.fromLTRB(16, top + 14, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 17, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.assignment_ind_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assign Doctors',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(clinic.name,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _HeaderBadge(
                        label: '${slots.length} slots',
                        color: Colors.white.withValues(alpha: 0.9),
                        bg: Colors.white.withValues(alpha: 0.18)),
                    _HeaderBadge(
                        label: '$assignedSlots assigned',
                        color: const Color(0xFF6EE7B7),
                        bg: const Color(0xFF059669).withValues(alpha: 0.30)),
                    _HeaderBadge(
                        label: '$unassigned open',
                        color: const Color(0xFFFDE68A),
                        bg: const Color(0xFFF59E0B).withValues(alpha: 0.30)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _HeaderBadge(
      {required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Day selector ──────────────────────────────────────────────────────────────

class _DaySelector extends StatelessWidget {
  static const _abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final List<ClinicSlot> slots;
  final List<DoctorAssignment> assignments;
  final int selectedDay;
  final void Function(int) onDaySelected;

  const _DaySelector({
    required this.slots,
    required this.assignments,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (i) {
            final day = i + 1;
            final daySlots =
                slots.where((s) => s.dayOfWeek == day).toList();
            final assignedCount = daySlots
                .where((s) => assignments.any((a) => a.slotId == s.id))
                .length;
            final unassignedCount = daySlots.length - assignedCount;
            final isSelected = selectedDay == day;
            final isWeekend = day >= 6;
            final hasSlots = daySlots.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => onDaySelected(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.borderLight,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary
                                  .withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_abbr[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : isWeekend
                                    ? AppTheme.textTertiary
                                    : AppTheme.textPrimary,
                          )),
                      const SizedBox(height: 6),
                      if (!hasSlots)
                        Container(
                          width: 28,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.20)
                                : AppTheme.borderLight,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text('--',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white
                                            .withValues(alpha: 0.70)
                                        : AppTheme.textTertiary)),
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (assignedCount > 0)
                              _DayBubble(
                                count: assignedCount,
                                color: isSelected
                                    ? const Color(0xFF6EE7B7)
                                    : AppTheme.success,
                                bg: isSelected
                                    ? const Color(0xFF059669)
                                        .withValues(alpha: 0.40)
                                    : AppTheme.successBg,
                              ),
                            if (assignedCount > 0 &&
                                unassignedCount > 0)
                              const SizedBox(width: 4),
                            if (unassignedCount > 0)
                              _DayBubble(
                                count: unassignedCount,
                                color: isSelected
                                    ? const Color(0xFFFDE68A)
                                    : AppTheme.warning,
                                bg: isSelected
                                    ? const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.40)
                                    : AppTheme.warningBg,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _DayBubble extends StatelessWidget {
  final int count;
  final Color color;
  final Color bg;
  const _DayBubble(
      {required this.count, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 18,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(9)),
      child: Center(
          child: Text('$count',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color))),
    );
  }
}

// ── Assignment panel ──────────────────────────────────────────────────────────

class _AssignmentPanel extends StatelessWidget {
  final int selectedDay;
  final List<ClinicSlot> slots;
  final List<DoctorAssignment> assignments;
  final List<Doctor> doctors;
  final Future<void> Function(ClinicSlot) onSchedule;
  final Future<void> Function(DoctorAssignment, Doctor) onRemove;

  const _AssignmentPanel({
    required this.selectedDay,
    required this.slots,
    required this.assignments,
    required this.doctors,
    required this.onSchedule,
    required this.onRemove,
  });

  static String _dayName(int day) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    return names[day - 1];
  }

  @override
  Widget build(BuildContext context) {
    final daySlots = slots
        .where((s) => s.dayOfWeek == selectedDay)
        .toList()
      ..sort((a, b) => a.startTime.hour != b.startTime.hour
          ? a.startTime.hour.compareTo(b.startTime.hour)
          : a.startTime.minute.compareTo(b.startTime.minute));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: daySlots.isEmpty
          ? _EmptyDayPanel(
              key: ValueKey('empty_$selectedDay'),
              dayName: _dayName(selectedDay))
          : ListView.separated(
              key: ValueKey('list_$selectedDay'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: daySlots.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final slot = daySlots[i];
                final slotAssignments =
                    assignments.where((a) => a.slotId == slot.id).toList();
                return _SlotAssignmentCard(
                  slot: slot,
                  slotAssignments: slotAssignments,
                  doctors: doctors,
                  onSchedule: () => onSchedule(slot),
                  onRemove: onRemove,
                );
              },
            ),
    );
  }
}

// ── Slot card ─────────────────────────────────────────────────────────────────

class _SlotAssignmentCard extends StatelessWidget {
  final ClinicSlot slot;
  final List<DoctorAssignment> slotAssignments;
  final List<Doctor> doctors;
  final VoidCallback onSchedule;
  final Future<void> Function(DoctorAssignment, Doctor) onRemove;

  const _SlotAssignmentCard({
    required this.slot,
    required this.slotAssignments,
    required this.doctors,
    required this.onSchedule,
    required this.onRemove,
  });

  static String _periodLabel(TimeOfDay t) {
    if (t.hour < 12) return '\u2600\ufe0f Morning';
    if (t.hour < 17) return '\u26c5 Afternoon';
    return '\ud83c\udf19 Evening';
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignments = slotAssignments.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAssignments
              ? AppTheme.success.withValues(alpha: 0.25)
              : AppTheme.warning.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: hasAssignments
                      ? const [Color(0xFF059669), Color(0xFF34D399)]
                      : const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PeriodChip(
                            label: _periodLabel(slot.startTime)),
                        const Spacer(),
                        _StatusBadge(isAssigned: hasAssignments),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${TimeUtils.format12(slot.startTime)} \u2013 ${TimeUtils.format12(slot.endTime)}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                            icon: Icons.timer_outlined,
                            label: '${slot.durationMinutes} min'),
                        if (slot.label != null)
                          _InfoChip(
                              icon: Icons.label_outline_rounded,
                              label: slot.label!),
                      ],
                    ),
                    if (hasAssignments) ...[
                      const SizedBox(height: 12),
                      const Divider(
                          height: 1,
                          color: AppTheme.borderLight,
                          thickness: 1),
                      const SizedBox(height: 10),
                      ...slotAssignments.map((a) {
                        final doc = doctors
                            .where((d) => d.id == a.doctorId)
                            .firstOrNull;
                        if (doc == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AssignmentRow(
                            assignment: a,
                            doctor: doc,
                            onRemove: () => onRemove(a, doc),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 10),
                    const Divider(
                        height: 1,
                        color: AppTheme.borderLight,
                        thickness: 1),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onSchedule,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(hasAssignments
                          ? 'Add Another Schedule'
                          : 'Assign Doctor'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(
                            color: AppTheme.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Assignment row ────────────────────────────────────────────────────────────

class _AssignmentRow extends StatelessWidget {
  final DoctorAssignment assignment;
  final Doctor doctor;
  final VoidCallback onRemove;

  const _AssignmentRow({
    required this.assignment,
    required this.doctor,
    required this.onRemove,
  });

  static const List<Color> _palette = [
    Color(0xFF0077B6), Color(0xFF059669), Color(0xFF7C3AED),
    Color(0xFFD97706), Color(0xFFDB2777), Color(0xFF0096C7),
  ];

  Color get _specColor =>
      _palette[doctor.specialization.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _specColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(Icons.person_rounded, size: 18, color: _specColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _TypeBadge(type: assignment.assignmentType),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        assignment.scheduleSummary,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.errorBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final AssignmentType type;
  const _TypeBadge({required this.type});

  static const _labels = {
    AssignmentType.oneTime: 'One-time',
    AssignmentType.dateRange: 'Range',
    AssignmentType.weekly: 'Weekly',
    AssignmentType.monthly: 'Monthly',
  };
  static const _colors = {
    AssignmentType.oneTime: AppTheme.primary,
    AssignmentType.dateRange: Color(0xFF0096C7),
    AssignmentType.weekly: AppTheme.success,
    AssignmentType.monthly: Color(0xFF7C3AED),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[type] ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_labels[type] ?? '',
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Micro widgets ─────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  const _PeriodChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary)),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool isAssigned;
  const _StatusBadge({required this.isAssigned});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isAssigned ? AppTheme.successBg : AppTheme.warningBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: isAssigned ? AppTheme.success : AppTheme.warning,
                  shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(isAssigned ? 'Staffed' : 'Open',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isAssigned ? AppTheme.success : AppTheme.warning)),
        ]),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: AppTheme.textTertiary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary)),
        ]),
      );
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyDayPanel extends StatelessWidget {
  final String dayName;
  const _EmptyDayPanel({super.key, required this.dayName});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.event_busy_rounded,
                  size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text('No slots on $dayName',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Add clinic slots for this day from\nthe Slot Management screen.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textTertiary,
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
}

class _EmptyScreen extends StatelessWidget {
  const _EmptyScreen();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.schedule_rounded,
                  size: 44, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('No Slots Defined',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Create clinic slots first, then\nassign doctors to each slot.',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textTertiary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════
// SCHEDULER SHEET
// ═══════════════════════════════════════════════════════════════════════

class _SchedulerSheet extends StatefulWidget {
  final Clinic clinic;
  final ClinicSlot slot;
  final List<Doctor> doctors;

  const _SchedulerSheet({
    required this.clinic,
    required this.slot,
    required this.doctors,
  });

  @override
  State<_SchedulerSheet> createState() => _SchedulerSheetState();
}

class _SchedulerSheetState extends State<_SchedulerSheet> {
  static const _uuid = Uuid();

  Doctor? _doctor;
  AssignmentType _type = AssignmentType.oneTime;
  DateTime? _startDate;
  DateTime? _endDate;
  Set<int> _daysOfWeek = {};
  MonthlyPattern? _monthlyPattern;
  String? _errorMsg;
  bool _saving = false;

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 730)),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx)
                  .colorScheme
                  .copyWith(primary: AppTheme.primary)),
          child: child!,
        ),
      );

  String _previewText() {
    final name = _doctor?.name ?? 'The doctor';
    switch (_type) {
      case AssignmentType.oneTime:
        if (_startDate == null) return '$name will be assigned permanently';
        return '$name will be assigned on ${_fmtDate(_startDate!)}';
      case AssignmentType.dateRange:
        if (_startDate == null || _endDate == null) return 'Select start and end dates';
        return '$name: ${_fmtDate(_startDate!)} to ${_fmtDate(_endDate!)}';
      case AssignmentType.weekly:
        if (_daysOfWeek.isEmpty) return 'Select at least one day of the week';
        final days = (_daysOfWeek.toList()..sort())
            .map((d) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d-1])
            .join(', ');
        final until = _endDate != null ? ' until ${_fmtDate(_endDate!)}' : '';
        return '$name every $days$until';
      case AssignmentType.monthly:
        if (_monthlyPattern == null) return 'Select a monthly pattern';
        final until = _endDate != null ? ' until ${_fmtDate(_endDate!)}' : '';
        return '$name every $_monthlyPattern$until';
    }
  }

  bool get _isValid {
    if (_doctor == null) return false;
    switch (_type) {
      case AssignmentType.oneTime:
        return true;
      case AssignmentType.dateRange:
        return _startDate != null &&
            _endDate != null &&
            !_endDate!.isBefore(_startDate!);
      case AssignmentType.weekly:
        return _daysOfWeek.isNotEmpty;
      case AssignmentType.monthly:
        return _monthlyPattern != null;
    }
  }

  Future<void> _save() async {
    if (!_isValid) {
      setState(() => _errorMsg = 'Please complete all required fields.');
      return;
    }
    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    final assignment = DoctorAssignment(
      id: _uuid.v4(),
      clinicId: widget.clinic.id,
      doctorId: _doctor!.id,
      slotId: widget.slot.id,
      assignmentType: _type,
      startDate: _startDate,
      endDate: _endDate,
      daysOfWeek: Set.unmodifiable(_daysOfWeek),
      monthlyPattern: _monthlyPattern,
    );

    final err = await context.read<ClinicProvider>().saveAssignment(assignment);
    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      setState(() => _errorMsg = err);
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_doctor!.name} scheduled successfully'),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  static String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            _SlotBanner(slot: widget.slot),
            const SizedBox(height: 20),
            const _SheetLabel(label: 'DOCTOR'),
            const SizedBox(height: 8),
            _DoctorSelector(
              doctors: widget.doctors,
              selected: _doctor,
              onSelect: (d) => setState(() => _doctor = d),
            ),
            const SizedBox(height: 20),
            const _SheetLabel(label: 'SCHEDULE TYPE'),
            const SizedBox(height: 10),
            _TypeSelector(
              selected: _type,
              onSelect: (t) => setState(() {
                _type = t;
                _startDate = null;
                _endDate = null;
                _daysOfWeek = {};
                _monthlyPattern = null;
              }),
            ),
            const SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _buildFields(),
            ),
            if (_doctor != null) ...[
              _PreviewBanner(text: _previewText()),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 16),
            if (_errorMsg != null) ...[
              _ErrorBanner(message: _errorMsg!),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Assignment',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFields() {
    switch (_type) {
      case AssignmentType.oneTime:
        return _OneTimeFields(
          date: _startDate,
          onPickDate: () async {
            final d = await _pickDate(_startDate);
            if (d != null) setState(() => _startDate = d);
          },
          onClearDate: () => setState(() => _startDate = null),
        );
      case AssignmentType.dateRange:
        return _DateRangeFields(
          startDate: _startDate,
          endDate: _endDate,
          onPickStart: () async {
            final d = await _pickDate(_startDate);
            if (d != null) {
              setState(() {
                _startDate = d;
                if (_endDate != null && _endDate!.isBefore(d)) _endDate = null;
              });
            }
          },
          onPickEnd: () async {
            final d = await _pickDate(_endDate ?? _startDate);
            if (d != null) setState(() => _endDate = d);
          },
        );
      case AssignmentType.weekly:
        return _WeeklyFields(
          selectedDays: _daysOfWeek,
          endDate: _endDate,
          onToggleDay: (day) => setState(() {
            final updated = Set<int>.from(_daysOfWeek);
            if (updated.contains(day)) {
              updated.remove(day);
            } else {
              updated.add(day);
            }
            _daysOfWeek = updated;
          }),
          onPickEndDate: () async {
            final d = await _pickDate(_endDate);
            if (d != null) setState(() => _endDate = d);
          },
          onClearEndDate: () => setState(() => _endDate = null),
        );
      case AssignmentType.monthly:
        return _MonthlyFields(
          pattern: _monthlyPattern,
          endDate: _endDate,
          onPickPattern: (p) => setState(() => _monthlyPattern = p),
          onPickEndDate: () async {
            final d = await _pickDate(_endDate);
            if (d != null) setState(() => _endDate = d);
          },
          onClearEndDate: () => setState(() => _endDate = null),
        );
    }
  }
}

// ── Slot banner ───────────────────────────────────────────────────────────────

class _SlotBanner extends StatelessWidget {
  final ClinicSlot slot;
  const _SlotBanner({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077B6), Color(0xFF0096C7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.schedule_rounded,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${TimeUtils.format12(slot.startTime)} \u2013 ${TimeUtils.format12(slot.endTime)}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              if (slot.label != null)
                Text(slot.label!,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.80))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sheet helpers ─────────────────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  final String label;
  const _SheetLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textTertiary,
          letterSpacing: 0.8));
}

// ── Doctor selector ───────────────────────────────────────────────────────────

class _DoctorSelector extends StatefulWidget {
  final List<Doctor> doctors;
  final Doctor? selected;
  final void Function(Doctor) onSelect;
  const _DoctorSelector(
      {required this.doctors, required this.selected, required this.onSelect});

  @override
  State<_DoctorSelector> createState() => _DoctorSelectorState();
}

class _DoctorSelectorState extends State<_DoctorSelector> {
  String _q = '';

  static const List<Color> _palette = [
    Color(0xFF0077B6), Color(0xFF059669), Color(0xFF7C3AED),
    Color(0xFFD97706), Color(0xFFDB2777), Color(0xFF0096C7),
  ];
  Color _color(String s) => _palette[s.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? widget.doctors
        : widget.doctors
            .where((d) =>
                d.name.toLowerCase().contains(_q) ||
                d.specialization.toLowerCase().contains(_q))
            .toList();

    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => _q = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search by name or specialization\u2026',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            filled: true,
            fillColor: AppTheme.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No doctors found.',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textTertiary)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppTheme.borderLight),
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final isSelected = widget.selected?.id == d.id;
                    final c = _color(d.specialization);
                    return InkWell(
                      onTap: () => widget.onSelect(d),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.person_rounded,
                                  size: 20, color: c),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(d.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary)),
                                  Text(d.specialization,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textTertiary)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  size: 18, color: AppTheme.primary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Type selector ─────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final AssignmentType selected;
  final void Function(AssignmentType) onSelect;

  const _TypeSelector({required this.selected, required this.onSelect});

  static const _types = [
    (AssignmentType.oneTime, Icons.today_rounded, 'One-time'),
    (AssignmentType.dateRange, Icons.date_range_rounded, 'Date Range'),
    (AssignmentType.weekly, Icons.repeat_rounded, 'Weekly'),
    (AssignmentType.monthly, Icons.calendar_month_rounded, 'Monthly'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _types.map((t) {
        final (type, icon, label) = t;
        final isSel = selected == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSel ? AppTheme.primary : AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? AppTheme.primary : AppTheme.borderLight,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 18,
                      color: isSel ? Colors.white : AppTheme.textSecondary),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color:
                              isSel ? Colors.white : AppTheme.textSecondary),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Field groups ──────────────────────────────────────────────────────────────

class _OneTimeFields extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  const _OneTimeFields({
    required this.date,
    required this.onPickDate,
    required this.onClearDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetLabel(
            label: 'DATE (optional \u2014 blank = permanent assignment)'),
        const SizedBox(height: 8),
        _DateTile(
          label: date == null
              ? 'All occurrences (no specific date)'
              : _SchedulerSheetState._fmtDate(date!),
          icon: Icons.event_rounded,
          highlighted: date != null,
          onTap: onPickDate,
          trailing: date != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textTertiary),
                  onPressed: onClearDate)
              : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _DateRangeFields extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DateRangeFields({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetLabel(label: 'START DATE *'),
        const SizedBox(height: 8),
        _DateTile(
          label: startDate == null
              ? 'Select start date'
              : _SchedulerSheetState._fmtDate(startDate!),
          icon: Icons.play_arrow_rounded,
          highlighted: startDate != null,
          onTap: onPickStart,
        ),
        const SizedBox(height: 10),
        const _SheetLabel(label: 'END DATE *'),
        const SizedBox(height: 8),
        _DateTile(
          label: endDate == null
              ? 'Select end date'
              : _SchedulerSheetState._fmtDate(endDate!),
          icon: Icons.stop_rounded,
          highlighted: endDate != null,
          enabled: startDate != null,
          onTap: onPickEnd,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _WeeklyFields extends StatelessWidget {
  final Set<int> selectedDays;
  final DateTime? endDate;
  final void Function(int) onToggleDay;
  final VoidCallback onPickEndDate;
  final VoidCallback onClearEndDate;

  const _WeeklyFields({
    required this.selectedDays,
    required this.endDate,
    required this.onToggleDay,
    required this.onPickEndDate,
    required this.onClearEndDate,
  });

  static const _days = [
    (1, 'Mon'), (2, 'Tue'), (3, 'Wed'),
    (4, 'Thu'), (5, 'Fri'), (6, 'Sat'), (7, 'Sun'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetLabel(label: 'DAYS OF THE WEEK *'),
        const SizedBox(height: 8),
        Row(
          children: _days.map((d) {
            final (num, abbr) = d;
            final isSel = selectedDays.contains(num);
            final isWeekend = num >= 6;
            return Expanded(
              child: GestureDetector(
                onTap: () => onToggleDay(num),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primary : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isSel ? AppTheme.primary : AppTheme.borderLight,
                      width: 1.5,
                    ),
                  ),
                  child: Text(abbr,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSel
                              ? Colors.white
                              : isWeekend
                                  ? AppTheme.textTertiary
                                  : AppTheme.textPrimary),
                      textAlign: TextAlign.center),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        const _SheetLabel(label: 'REPEAT UNTIL (optional)'),
        const SizedBox(height: 8),
        _DateTile(
          label: endDate == null
              ? 'No end date \u2014 repeats indefinitely'
              : _SchedulerSheetState._fmtDate(endDate!),
          icon: Icons.event_repeat_rounded,
          highlighted: endDate != null,
          onTap: onPickEndDate,
          trailing: endDate != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textTertiary),
                  onPressed: onClearEndDate)
              : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MonthlyFields extends StatelessWidget {
  final MonthlyPattern? pattern;
  final DateTime? endDate;
  final void Function(MonthlyPattern) onPickPattern;
  final VoidCallback onPickEndDate;
  final VoidCallback onClearEndDate;

  const _MonthlyFields({
    required this.pattern,
    required this.endDate,
    required this.onPickPattern,
    required this.onPickEndDate,
    required this.onClearEndDate,
  });

  static const _weekOptions = [
    (1, '1st'), (2, '2nd'), (3, '3rd'), (4, '4th'), (-1, 'Last'),
  ];
  static const _dayOptions = [
    (1, 'Monday'), (2, 'Tuesday'), (3, 'Wednesday'),
    (4, 'Thursday'), (5, 'Friday'), (6, 'Saturday'), (7, 'Sunday'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetLabel(label: 'MONTHLY PATTERN *'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: pattern?.week,
                hint: const Text('Week'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.border)),
                ),
                items: _weekOptions
                    .map((w) => DropdownMenuItem(
                        value: w.$1, child: Text(w.$2)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onPickPattern(MonthlyPattern(
                      week: v, dayOfWeek: pattern?.dayOfWeek ?? 1));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                initialValue: pattern?.dayOfWeek,
                hint: const Text('Day of week'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.border)),
                ),
                items: _dayOptions
                    .map((d) => DropdownMenuItem(
                        value: d.$1, child: Text(d.$2)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onPickPattern(MonthlyPattern(
                      week: pattern?.week ?? 1, dayOfWeek: v));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _SheetLabel(label: 'REPEAT UNTIL (optional)'),
        const SizedBox(height: 8),
        _DateTile(
          label: endDate == null
              ? 'No end date \u2014 repeats indefinitely'
              : _SchedulerSheetState._fmtDate(endDate!),
          icon: Icons.event_repeat_rounded,
          highlighted: endDate != null,
          onTap: onPickEndDate,
          trailing: endDate != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textTertiary),
                  onPressed: onClearEndDate)
              : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Date tile ─────────────────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlighted;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DateTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              highlighted ? AppTheme.primaryContainer : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? AppTheme.primary : AppTheme.borderLight,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: highlighted
                    ? AppTheme.primary
                    : enabled
                        ? AppTheme.textSecondary
                        : AppTheme.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          highlighted ? FontWeight.w600 : FontWeight.w400,
                      color: highlighted
                          ? AppTheme.textPrimary
                          : enabled
                              ? AppTheme.textSecondary
                              : AppTheme.textTertiary)),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ── Preview & error banners ───────────────────────────────────────────────────

class _PreviewBanner extends StatelessWidget {
  final String text;
  const _PreviewBanner({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4)),
            ),
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorBg,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.error.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 16, color: AppTheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.error, height: 1.4)),
            ),
          ],
        ),
      );
}
