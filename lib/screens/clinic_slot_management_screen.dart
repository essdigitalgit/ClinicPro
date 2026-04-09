import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clinic.dart';
import '../models/clinic_slot.dart';
import '../models/doctor_assignment.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/loading_overlay.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Clinic Slot Management Screen
// ═══════════════════════════════════════════════════════════════════════════════

/// Modern, calendar-style weekly slot management for a clinic.
class ClinicSlotManagementScreen extends StatefulWidget {
  final Clinic clinic;

  const ClinicSlotManagementScreen({super.key, required this.clinic});

  @override
  State<ClinicSlotManagementScreen> createState() =>
      _ClinicSlotManagementScreenState();
}

class _ClinicSlotManagementScreenState
    extends State<ClinicSlotManagementScreen> {
  // Default to today's weekday (Mon=1...Sun=7).
  int _selectedDay = DateTime.now().weekday.clamp(1, 7);

  static const _dayFull = [
    'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicProvider>().loadSlots(widget.clinic.id);
    });
  }

  // ── Add / Edit sheet ────────────────────────────────────────────────────────

  Future<void> _openEditor({ClinicSlot? edit, int? dayOverride}) async {
    final provider = context.read<ClinicProvider>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SlotEditorSheet(
        clinicId: widget.clinic.id,
        initialDay: dayOverride ?? _selectedDay,
        existingSlot: edit,
        existingSlots: provider.slots,
      ),
    );
  }

  // ── Delete confirmation ─────────────────────────────────────────────────────

  Future<void> _deleteSlot(ClinicSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Slot',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(children: [
                const Icon(Icons.schedule_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${slot.dayName}  ·  ${TimeUtils.format12(slot.startTime)} – ${TimeUtils.format12(slot.endTime)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            const Text(
              'This also removes associated doctor assignments and future appointments.',
              style:
                  TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final p = context.read<ClinicProvider>();
    await p.deleteClinicSlot(slot.id, widget.clinic.id);
    if (!mounted) return;
    _showSnackbar('Slot removed', AppTheme.success);
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicProvider>(
      builder: (context, provider, _) {
        // Build sorted day → slots map.
        final grouped = <int, List<ClinicSlot>>{};
        for (final s in provider.slots) {
          grouped.putIfAbsent(s.dayOfWeek, () => []).add(s);
        }
        for (final list in grouped.values) {
          list.sort((a, b) {
            final aM = a.startTime.hour * 60 + a.startTime.minute;
            final bM = b.startTime.hour * 60 + b.startTime.minute;
            return aM.compareTo(bM);
          });
        }

        final daySlots = grouped[_selectedDay] ?? [];
        final totalSlots = provider.slots.length;
        final staffed = provider.slots
            .where(
                (s) => provider.assignments.any((a) => a.slotId == s.id))
            .length;

        return LoadingOverlay(
          isLoading: provider.submitting,
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Gradient header ─────────────────────────────────────────
                  _ScheduleHeader(
                    clinic: widget.clinic,
                    totalSlots: totalSlots,
                    staffedCount: staffed,
                    onBack: () => Navigator.pop(context),
                  ),

                  // ── Day selector ────────────────────────────────────────────
                  _DaySelector(
                    selectedDay: _selectedDay,
                    slotCounts: {
                      for (final e in grouped.entries) e.key: e.value.length,
                    },
                    onChanged: (d) => setState(() => _selectedDay = d),
                  ),

                  // ── Slot panel for selected day ─────────────────────────────
                  Expanded(
                    child: provider.loadingSlots
                        ? const Center(child: CircularProgressIndicator())
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.06, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOut)),
                                child: child,
                              ),
                            ),
                            child: _DayPanel(
                              key: ValueKey(_selectedDay),
                              dayName: _dayFull[_selectedDay - 1],
                              slots: daySlots,
                              assignments: provider.assignments,
                              onDelete: _deleteSlot,
                              onEdit: (s) => _openEditor(edit: s),
                              onAddForDay: () =>
                                  _openEditor(dayOverride: _selectedDay),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: AppTheme.primary,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Add Slot',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Header
// ═══════════════════════════════════════════════════════════════════════════════

class _ScheduleHeader extends StatelessWidget {
  final Clinic clinic;
  final int totalSlots;
  final int staffedCount;
  final VoidCallback onBack;

  const _ScheduleHeader({
    required this.clinic,
    required this.totalSlots,
    required this.staffedCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white),
                onPressed: onBack,
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5),
                  ),
                  child: const Icon(Icons.local_hospital_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clinic.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 3),
                      const Text('Manage weekly schedule',
                          style: TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HeaderBadge(
                        value: totalSlots.toString(),
                        label: 'total slots'),
                    const SizedBox(height: 6),
                    _HeaderBadge(
                        value: staffedCount.toString(),
                        label: 'staffed',
                        valueColor: const Color(0xFF6EE7B7)),
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
  final String value;
  final String label;
  final Color valueColor;

  const _HeaderBadge({
    required this.value,
    required this.label,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Day Selector
// ═══════════════════════════════════════════════════════════════════════════════

class _DaySelector extends StatelessWidget {
  final int selectedDay;
  final Map<int, int> slotCounts;
  final ValueChanged<int> onChanged;

  static const _abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  const _DaySelector({
    required this.selectedDay,
    required this.slotCounts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: List.generate(7, (i) {
                final day = i + 1;
                final isSel = selectedDay == day;
                final isWeekend = day >= 6;
                final count = slotCounts[day] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => onChanged(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppTheme.primary
                            : (isWeekend
                                ? const Color(0xFFF8FAFC)
                                : AppTheme.surface),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? AppTheme.primary
                              : (isWeekend
                                  ? AppTheme.borderLight
                                  : AppTheme.border),
                          width: 1.5,
                        ),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _abbr[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? Colors.white
                                  : (isWeekend
                                      ? AppTheme.textTertiary
                                      : AppTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 7),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isSel
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : (count > 0
                                      ? AppTheme.primaryContainer
                                      : AppTheme.surfaceAlt),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSel
                                      ? Colors.white
                                      : (count > 0
                                          ? AppTheme.primary
                                          : AppTheme.textTertiary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderLight),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Day Panel
// ═══════════════════════════════════════════════════════════════════════════════

class _DayPanel extends StatelessWidget {
  final String dayName;
  final List<ClinicSlot> slots;
  final List<DoctorAssignment> assignments;
  final void Function(ClinicSlot) onDelete;
  final void Function(ClinicSlot) onEdit;
  final VoidCallback onAddForDay;

  const _DayPanel({
    super.key,
    required this.dayName,
    required this.slots,
    required this.assignments,
    required this.onDelete,
    required this.onEdit,
    required this.onAddForDay,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return _EmptyDayState(dayName: dayName, onAdd: onAddForDay);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: slots.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: AppTheme.primary),
                  const SizedBox(width: 5),
                  Text(dayName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                ]),
              ),
              const SizedBox(width: 10),
              Text('${slots.length} slot${slots.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textTertiary)),
            ]),
          );
        }

        final slot = slots[index - 1];
        final isAssigned = assignments.any((a) => a.slotId == slot.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SlotTimeBlock(
            slot: slot,
            isAssigned: isAssigned,
            onDelete: () => onDelete(slot),
            onEdit: () => onEdit(slot),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Slot Time Block — calendar-event style card
// ═══════════════════════════════════════════════════════════════════════════════

class _SlotTimeBlock extends StatelessWidget {
  final ClinicSlot slot;
  final bool isAssigned;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _SlotTimeBlock({
    required this.slot,
    required this.isAssigned,
    required this.onDelete,
    required this.onEdit,
  });

  Color get _accent {
    final h = slot.startTime.hour;
    if (h < 12) return const Color(0xFF0077B6);
    if (h < 17) return const Color(0xFF0EA5A0);
    return const Color(0xFF6366F1);
  }

  Color get _accentBg {
    final h = slot.startTime.hour;
    if (h < 12) return const Color(0xFFDCEEF8);
    if (h < 17) return const Color(0xFFCCFBF1);
    return const Color(0xFFEDE9FE);
  }

  String get _period {
    final h = slot.startTime.hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  IconData get _periodIcon {
    final h = slot.startTime.hour;
    if (h < 12) return Icons.wb_sunny_outlined;
    if (h < 17) return Icons.wb_cloudy_outlined;
    return Icons.nights_stay_outlined;
  }

  String _dur() {
    final m = slot.durationMinutes;
    final h = m ~/ 60;
    final rem = m % 60;
    if (h == 0) return '${rem}m';
    if (rem == 0) return '${h}h';
    return '${h}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final ac = _accent;
    final bg = _accentBg;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored accent strip
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [ac, ac.withValues(alpha: 0.5)],
                  ),
                ),
              ),

              // Main content
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period badge + staffed badge
                      Row(children: [
                        _PeriodChip(
                            icon: _periodIcon,
                            label: _period,
                            color: ac,
                            bg: bg),
                        const Spacer(),
                        _StaffedBadge(isAssigned: isAssigned),
                      ]),
                      const SizedBox(height: 12),

                      // Large time range
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 16, color: ac),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${TimeUtils.format12(slot.startTime)}  –  ${TimeUtils.format12(slot.endTime)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),

                      // Info chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _InfoChip(
                              icon: Icons.timelapse_rounded,
                              label: _dur(),
                              color: AppTheme.textTertiary),
                          _InfoChip(
                              icon: Icons.event_available_rounded,
                              label: '${slot.appointmentCount} appts',
                              color: AppTheme.textTertiary),
                          if (slot.label != null)
                            _InfoChip(
                                icon: Icons.label_rounded,
                                label: slot.label!,
                                color: ac,
                                bg: bg,
                                prominent: true),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const Divider(
                          height: 1, color: AppTheme.borderLight),
                      const SizedBox(height: 10),

                      // Action row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _ActionBtn(
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            color: AppTheme.primary,
                            bg: AppTheme.primaryContainer,
                            onTap: onEdit,
                          ),
                          const SizedBox(width: 8),
                          _ActionBtn(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete',
                            color: AppTheme.error,
                            bg: AppTheme.errorBg,
                            onTap: onDelete,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small reusable card widgets ────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  const _PeriodChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}

class _StaffedBadge extends StatelessWidget {
  final bool isAssigned;
  const _StaffedBadge({required this.isAssigned});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isAssigned ? AppTheme.successBg : AppTheme.warningBg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            isAssigned
                ? Icons.person_rounded
                : Icons.person_outline_rounded,
            size: 12,
            color: isAssigned ? AppTheme.success : AppTheme.warning),
        const SizedBox(width: 4),
        Text(
          isAssigned ? 'Staffed' : 'Open',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isAssigned ? AppTheme.success : AppTheme.warning),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bg;
  final bool prominent;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.bg,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: prominent
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
          : EdgeInsets.zero,
      decoration: prominent && bg != null
          ? BoxDecoration(
              color: bg!, borderRadius: BorderRadius.circular(6))
          : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  prominent ? FontWeight.w600 : FontWeight.w400,
              color: color,
            )),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Empty Day State
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyDayState extends StatelessWidget {
  final String dayName;
  final VoidCallback onAdd;

  const _EmptyDayState({required this.dayName, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.event_busy_rounded,
                  size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'No slots on $dayName',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'This day has no working windows yet.\nTap add below to schedule a slot.',
              style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Schedule $dayName'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Slot Editor Bottom Sheet  (Add / Edit)
// ═══════════════════════════════════════════════════════════════════════════════

class _SlotEditorSheet extends StatefulWidget {
  final String clinicId;
  final int initialDay;
  final ClinicSlot? existingSlot;
  final List<ClinicSlot> existingSlots;

  const _SlotEditorSheet({
    required this.clinicId,
    required this.initialDay,
    this.existingSlot,
    required this.existingSlots,
  });

  @override
  State<_SlotEditorSheet> createState() => _SlotEditorSheetState();
}

class _SlotEditorSheetState extends State<_SlotEditorSheet> {
  late int _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late TextEditingController _labelCtrl;
  bool _saving = false;

  static const _abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _full = [
    'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  bool get _isEdit => widget.existingSlot != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingSlot;
    _day = s?.dayOfWeek ?? widget.initialDay;
    _start = s?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    _end = s?.endTime ?? const TimeOfDay(hour: 12, minute: 0);
    _labelCtrl = TextEditingController(text: s?.label ?? '');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  bool get _hasOverlap {
    final sM = _start.hour * 60 + _start.minute;
    final eM = _end.hour * 60 + _end.minute;
    for (final s in widget.existingSlots) {
      if (widget.existingSlot?.id == s.id) continue;
      if (s.dayOfWeek != _day) continue;
      final ssM = s.startTime.hour * 60 + s.startTime.minute;
      final seM = s.endTime.hour * 60 + s.endTime.minute;
      if (sM < seM && eM > ssM) return true;
    }
    return false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<ClinicProvider>();
    final label =
        _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim();

    if (_isEdit) {
      await provider.deleteClinicSlot(
          widget.existingSlot!.id, widget.clinicId);
    }

    final err = await provider.addClinicSlot(
      clinicId: widget.clinicId,
      dayOfWeek: _day,
      startTime: _start,
      endTime: _end,
      label: label,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(_isEdit
              ? 'Slot updated for ${_full[_day - 1]}'
              : 'Slot added for ${_full[_day - 1]}'),
        ]),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final startM = _start.hour * 60 + _start.minute;
    final endM = _end.hour * 60 + _end.minute;
    final durMin = endM - startM;
    final isValidDur = durMin >= 30;
    final canSave = isValidDur && !_hasOverlap && !_saving;

    final durText = durMin > 0
        ? '${durMin ~/ 60 > 0 ? '${durMin ~/ 60}h ' : ''}${durMin % 60 > 0 ? '${durMin % 60}m' : ''}'
            .trim()
        : '–';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 22),

              // Sheet title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isEdit
                        ? Icons.edit_calendar_rounded
                        : Icons.add_alarm_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEdit ? 'Edit Slot' : 'New Slot',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    const Text(
                      'Recurring weekly working window',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 26),

              // ── Day of week ─────────────────────────────────────────────────
              const _SectionLabel('DAY OF WEEK'),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(7, (i) {
                    final d = i + 1;
                    final sel = _day == d;
                    final isWeekend = d >= 6;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _day = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.primary
                                : AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? AppTheme.primary
                                  : AppTheme.border,
                              width: 1.5,
                            ),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            _abbr[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : (isWeekend
                                      ? AppTheme.textTertiary
                                      : AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // ── Time range ──────────────────────────────────────────────────
              const _SectionLabel('TIME RANGE'),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _TimePickerCard(
                      label: 'Start Time',
                      time: _start,
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: [
                      const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: AppTheme.textTertiary),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isValidDur
                              ? AppTheme.successBg
                              : AppTheme.warningBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          durText,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isValidDur
                                  ? AppTheme.success
                                  : AppTheme.warning),
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: _TimePickerCard(
                      label: 'End Time',
                      time: _end,
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),

              // Validation banners
              if (!isValidDur && endM > 0) ...[
                const SizedBox(height: 10),
                _ValidationBanner(
                  icon: Icons.warning_amber_rounded,
                  message: 'Slot must be at least 30 minutes long',
                  color: AppTheme.warning,
                  bg: AppTheme.warningBg,
                ),
              ] else if (_hasOverlap) ...[
                const SizedBox(height: 10),
                _ValidationBanner(
                  icon: Icons.error_outline_rounded,
                  message:
                      'This overlaps with an existing slot on the same day',
                  color: AppTheme.error,
                  bg: AppTheme.errorBg,
                ),
              ] else if (isValidDur) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event_available_rounded,
                        size: 15, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Fits ${durMin ~/ 30} × 30-min appointments',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              // ── Label ───────────────────────────────────────────────────────
              const _SectionLabel('LABEL (OPTIONAL)'),
              const SizedBox(height: 10),
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Morning OPD, Specialist Hours',
                  prefixIcon:
                      Icon(Icons.label_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 26),

              // ── Save button ─────────────────────────────────────────────────
              FilledButton.icon(
                onPressed: canSave ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isEdit
                        ? Icons.check_rounded
                        : Icons.add_rounded),
                label: Text(
                  _isEdit
                      ? 'Save Changes'
                      : 'Add ${_full[_day - 1]} Slot',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                  disabledBackgroundColor: AppTheme.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting sheet widgets ──────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textTertiary,
          letterSpacing: 0.8,
        ));
  }
}

class _TimePickerCard extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerCard(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 13, color: AppTheme.textTertiary),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 6),
            Text(
              TimeUtils.format12(time),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: -0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Color bg;

  const _ValidationBanner(
      {required this.icon,
      required this.message,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
