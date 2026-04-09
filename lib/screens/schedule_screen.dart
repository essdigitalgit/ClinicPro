import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/clinic.dart';
import '../models/clinic_slot.dart';
import '../models/doctor.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODEL — stored in ScheduleProvider (in-memory)
// ═══════════════════════════════════════════════════════════════════════════════

enum ScheduleType { weekly, monthly, oneTime }
enum MonthlyMode { dateBased, dayPattern }

/// Represents a "Nth Weekday" pattern, e.g. 2nd Saturday.
class WeekDayPattern {
  /// 1 = 1st, 2 = 2nd, 3 = 3rd, 4 = 4th, 5 = last
  final int weekPosition;
  /// 1 = Monday … 7 = Sunday
  final int dayOfWeek;

  const WeekDayPattern({required this.weekPosition, required this.dayOfWeek});

  static const _posLabels = ['1st', '2nd', '3rd', '4th', 'Last'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String get label =>
      '${_posLabels[weekPosition - 1]} ${_dayLabels[dayOfWeek - 1]}';

  @override
  bool operator ==(Object other) =>
      other is WeekDayPattern &&
      weekPosition == other.weekPosition &&
      dayOfWeek == other.dayOfWeek;

  @override
  int get hashCode => Object.hash(weekPosition, dayOfWeek);

  /// Returns the actual calendar date for this pattern in [year]/[month],
  /// or null if the pattern doesn't exist that month (e.g. 5th Monday when
  /// there are only 4 Mondays).
  DateTime? dateInMonth(int year, int month) {
    if (weekPosition == 5) {
      // "Last" — find last occurrence
      final lastDay = DateTime(year, month + 1, 0).day;
      for (int d = lastDay; d >= 1; d--) {
        if (DateTime(year, month, d).weekday == dayOfWeek) {
          return DateTime(year, month, d);
        }
      }
      return null;
    }
    int count = 0;
    for (int d = 1; d <= DateTime(year, month + 1, 0).day; d++) {
      if (DateTime(year, month, d).weekday == dayOfWeek) {
        count++;
        if (count == weekPosition) return DateTime(year, month, d);
      }
    }
    return null;
  }
}

class ScheduledAssignment {
  final String id;
  final String clinicId;
  final String clinicName;
  final String doctorId;
  final String doctorName;
  final ScheduleType scheduleType;
  // Per-day slot mapping: weekday (1–7) → slotId
  // For weekly: each selected day can have its own slot
  // For monthly / oneTime: uses day 0 as a single slot key
  final Map<int, String> slotIdsPerDay;   // {dayOfWeek: slotId}
  final Map<int, String> slotLabelsPerDay; // {dayOfWeek: slotLabel}
  // weekly / oneTime
  final Set<int> selectedDays; // weekdays 1–7 or weekday for oneTime
  final DateTime? specificDate; // only for oneTime
  // monthly extras
  final MonthlyMode monthlyMode;
  final List<int> selectedDates;      // date-based: [1, 15, 31]
  final List<WeekDayPattern> weekDayPatterns; // pattern-based
  /// For recurring schedules (weekly / monthly) only.
  final DateTime? effectiveStartDate;

  const ScheduledAssignment({
    required this.id,
    required this.clinicId,
    required this.clinicName,
    required this.doctorId,
    required this.doctorName,
    required this.scheduleType,
    this.slotIdsPerDay = const {},
    this.slotLabelsPerDay = const {},
    this.selectedDays = const {},
    this.specificDate,
    this.monthlyMode = MonthlyMode.dateBased,
    this.selectedDates = const [],
    this.weekDayPatterns = const [],
    this.effectiveStartDate,
  });

  String get scheduleSummaryLabel {
    switch (scheduleType) {
      case ScheduleType.weekly:
        const map = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};
        final days = (selectedDays.toList()..sort()).map((d) => map[d]!).join(', ');
        final startW = effectiveStartDate == null ? '' : ' · from ${_fmtDate(effectiveStartDate!)}';
        return 'Weekly · $days$startW';
      case ScheduleType.monthly:
        String base;
        if (monthlyMode == MonthlyMode.dateBased) {
          if (selectedDates.isEmpty) return 'Monthly';
          final sorted = (List<int>.from(selectedDates)..sort());
          base = 'Every ${sorted.map(_ordinal).join(' & ')} of the month';
        } else {
          if (weekDayPatterns.isEmpty) return 'Monthly';
          base = 'Every ${weekDayPatterns.map((p) => p.label).join(' & ')}';
        }
        final startM = effectiveStartDate == null ? '' : ' · from ${_fmtDate(effectiveStartDate!)}';
        return '$base$startM';
      case ScheduleType.oneTime:
        if (specificDate == null) return 'One-time';
        final m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        return 'On ${m[specificDate!.month-1]} ${specificDate!.day}, ${specificDate!.year}';
    }
  }


  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  static String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  /// The first slotId assigned (used for backward-compat display)
  String? get slotId => slotIdsPerDay.values.firstOrNull;
  /// The first slotLabel assigned (used for backward-compat display)
  String? get slotLabel => slotLabelsPerDay.values.firstOrNull;

  bool conflictsWith(ScheduledAssignment other) {
    // Slot-level conflict: same clinic, and any per-day slot overlaps.
    if (clinicId == other.clinicId) {
      for (final entry in slotIdsPerDay.entries) {
        final otherId = other.slotIdsPerDay[entry.key];
        if (otherId != null && otherId == entry.value) return true;
      }
    }
    // Doctor-level conflict: same doctor, same clinic, overlapping days
    if (doctorId != other.doctorId) return false;
    if (scheduleType == ScheduleType.weekly &&
        other.scheduleType == ScheduleType.weekly) {
      return selectedDays.intersection(other.selectedDays).isNotEmpty;
    }
    if (scheduleType == ScheduleType.monthly &&
        other.scheduleType == ScheduleType.monthly) {
      if (monthlyMode == MonthlyMode.dateBased &&
          other.monthlyMode == MonthlyMode.dateBased) {
        return selectedDates
            .toSet()
            .intersection(other.selectedDates.toSet())
            .isNotEmpty;
      }
      if (monthlyMode == MonthlyMode.dayPattern &&
          other.monthlyMode == MonthlyMode.dayPattern) {
        return weekDayPatterns
            .any((p) => other.weekDayPatterns.contains(p));
      }
    }
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEDULE PROVIDER — manages in-memory scheduled assignments
// ═══════════════════════════════════════════════════════════════════════════════

class ScheduleProvider extends ChangeNotifier {
  static const _uuid = Uuid();
  final List<ScheduledAssignment> _schedules = [];

  List<ScheduledAssignment> get schedules => List.unmodifiable(_schedules);

  /// Returns the set of slotIds already occupied in a given clinic,
  /// optionally filtered to a specific weekday.
  Set<String> getOccupiedSlotIds(String clinicId, {int? dayOfWeek}) {
    final result = <String>{};
    for (final s in _schedules) {
      if (s.clinicId != clinicId) continue;
      if (dayOfWeek != null) {
        final id = s.slotIdsPerDay[dayOfWeek];
        if (id != null) result.add(id);
      } else {
        result.addAll(s.slotIdsPerDay.values);
      }
    }
    return result;
  }

  /// Returns null on success, error message on conflict / validation failure.
  Future<String?> save(ScheduledAssignment s) async {
    await Future.delayed(const Duration(milliseconds: 500));
    for (final existing in _schedules) {
      if (existing.conflictsWith(s)) {
        // Distinguish slot conflict from doctor-overlap conflict
        bool isSlotConflict = false;
        if (s.clinicId == existing.clinicId) {
          for (final entry in s.slotIdsPerDay.entries) {
            final otherId = existing.slotIdsPerDay[entry.key];
            if (otherId != null && otherId == entry.value) {
              isSlotConflict = true;
              break;
            }
          }
        }
        if (isSlotConflict) {
          return 'One or more time slots are already assigned to another doctor '
              '(${existing.doctorName}). Please choose different slots.';
        }
        return 'Conflict: ${s.doctorName} already has an overlapping '
            '${existing.scheduleSummaryLabel} schedule';
      }
    }
    _schedules.insert(0, ScheduledAssignment(
      id: _uuid.v4(),
      clinicId: s.clinicId,
      clinicName: s.clinicName,
      doctorId: s.doctorId,
      doctorName: s.doctorName,
      scheduleType: s.scheduleType,
      slotIdsPerDay: Map.unmodifiable(s.slotIdsPerDay),
      slotLabelsPerDay: Map.unmodifiable(s.slotLabelsPerDay),
      selectedDays: Set.unmodifiable(s.selectedDays),
      specificDate: s.specificDate,
      monthlyMode: s.monthlyMode,
      selectedDates: List.unmodifiable(s.selectedDates),
      weekDayPatterns: List.unmodifiable(s.weekDayPatterns),
      effectiveStartDate: s.effectiveStartDate,
    ));
    notifyListeners();
    return null;
  }

  void remove(String id) {
    _schedules.removeWhere((s) => s.id == id);
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATE FILTERING — pure function, no dependencies on time slots
// ═══════════════════════════════════════════════════════════════════════════════

/// Returns upcoming dates (starting from [today]) that satisfy both
/// [scheduleType]/[selectedDaysOrDates] *and* the doctor's availability
/// [doctorAvailableWeekdays].
///
/// Look-ahead window:
///  - Weekly  → [weeklyLookAheadDays] days (default 90, ~13 weeks)
///  - Monthly → [monthlyLookAheadMonths] calendar months (default 12)
///
/// [doctorAvailableWeekdays] — weekday ints (1=Mon…7=Sun) from clinic slots.
///   Pass an empty set to skip the availability check.
///
/// [weekDayPatterns] — only relevant for monthly day-pattern mode.
List<DateTime> getValidStartDates({
  required Set<int> doctorAvailableWeekdays,
  required ScheduleType scheduleType,
  required Set<int> selectedWeekdays,
  required List<int> selectedMonthDates,
  required List<WeekDayPattern> weekDayPatterns,
  DateTime? today,
  int weeklyLookAheadDays = 90,
  int monthlyLookAheadMonths = 12,
}) {
  final base =
      today ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final result = <DateTime>[];

  // Determine the end boundary
  final DateTime end;
  if (scheduleType == ScheduleType.monthly) {
    // Add monthlyLookAheadMonths calendar months
    int y = base.year + (base.month + monthlyLookAheadMonths - 1) ~/ 12;
    int m = (base.month + monthlyLookAheadMonths - 1) % 12 + 1;
    end = DateTime(y, m, base.day);
  } else {
    end = base.add(Duration(days: weeklyLookAheadDays));
  }

  DateTime candidate = base;
  while (!candidate.isAfter(end)) {
    final weekday = candidate.weekday; // 1–7

    // Availability check (skip if no availability data)
    if (doctorAvailableWeekdays.isNotEmpty &&
        !doctorAvailableWeekdays.contains(weekday)) {
      candidate = candidate.add(const Duration(days: 1));
      continue;
    }

    bool matchesPattern = false;
    switch (scheduleType) {
      case ScheduleType.weekly:
        matchesPattern = selectedWeekdays.contains(weekday);
      case ScheduleType.monthly:
        if (selectedMonthDates.isNotEmpty) {
          matchesPattern = selectedMonthDates.contains(candidate.day);
        } else if (weekDayPatterns.isNotEmpty) {
          for (final p in weekDayPatterns) {
            final d = p.dateInMonth(candidate.year, candidate.month);
            if (d != null && _sameDay(d, candidate)) {
              matchesPattern = true;
              break;
            }
          }
        }
      case ScheduleType.oneTime:
        break;
    }

    if (matchesPattern) result.add(candidate);
    candidate = candidate.add(const Duration(days: 1));
  }
  return result;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN STATE
// ═══════════════════════════════════════════════════════════════════════════════

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final p = context.read<ClinicProvider>();
    p.loadClinics();
    p.loadDoctors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Schedule',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3)),
                          Text('Assign recurring or one-time schedules',
                              style:
                                  TextStyle(color: Color(0xBDFFFFFF), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0x99FFFFFF),
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'New Schedule'),
                    Tab(text: 'All Schedules'),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _NewScheduleTab(),
                _ScheduleListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — NEW SCHEDULE FORM
// ═══════════════════════════════════════════════════════════════════════════════

class _NewScheduleTab extends StatefulWidget {
  const _NewScheduleTab();

  @override
  State<_NewScheduleTab> createState() => _NewScheduleTabState();
}

class _NewScheduleTabState extends State<_NewScheduleTab> {
  // Selections
  Clinic? _clinic;
  Doctor? _doctor;
  ScheduleType _type = ScheduleType.weekly;
  /// For weekly: maps weekday → chosen ClinicSlot.
  /// For monthly/oneTime: uses key 0 for a single slot.
  final Map<int, ClinicSlot> _selectedSlotPerDay = {};
  final Set<int> _selectedDays = {};   // weekly weekdays
  DateTime? _specificDate;             // oneTime
  DateTime? _effectiveStartDate;       // weekly + monthly
  // Monthly sub-state
  MonthlyMode _monthlyMode = MonthlyMode.dateBased;
  final List<int> _selectedDates = [];        // date-based
  final List<WeekDayPattern> _weekDayPatterns = []; // pattern-based

  // Computed: valid selectable start dates for recurring schedules
  List<DateTime> _validStartDates = [];

  // Derived
  bool _saving = false;
  String? _errorMsg;

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _reset() {
    setState(() {
      _clinic = null;
      _doctor = null;
      _type = ScheduleType.weekly;
      _selectedSlotPerDay.clear();
      _selectedDays.clear();
      _specificDate = null;
      _effectiveStartDate = null;
      _monthlyMode = MonthlyMode.dateBased;
      _selectedDates.clear();
      _weekDayPatterns.clear();
      _validStartDates = [];
      _errorMsg = null;
    });
  }

  void _onTypeChanged(ScheduleType t) {
    setState(() {
      _type = t;
      _selectedSlotPerDay.clear();
      _selectedDays.clear();
      _specificDate = null;
      _effectiveStartDate = null;
      _selectedDates.clear();
      _weekDayPatterns.clear();
      _validStartDates = [];
      _errorMsg = null;
    });
    _recomputeValidStartDates();
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
        _selectedSlotPerDay.remove(day); // clear slot for deselected day
      } else {
        _selectedDays.add(day);
      }
    });
    _recomputeValidStartDates();
  }

  /// Recomputes [_validStartDates] based on current doctor, type, and pattern.
  /// Ignores time slots — uses availability weekdays only.
  void _recomputeValidStartDates() {
    if (_type == ScheduleType.oneTime) {
      setState(() {
        _validStartDates = [];
        _effectiveStartDate = null;
      });
      return;
    }
    final cp = context.read<ClinicProvider>();
    // Doctor availability days = union of clinic slot weekdays when a doctor
    // is selected.  Since we don't have per-doctor slot filtering in the mock,
    // we use the *clinic* operating days as the availability constraint.
    final doctorAvailableWeekdays =
        cp.slots.map((s) => s.dayOfWeek).toSet();

    final dates = getValidStartDates(
      doctorAvailableWeekdays: doctorAvailableWeekdays,
      scheduleType: _type,
      selectedWeekdays: Set.from(_selectedDays),
      selectedMonthDates: List.from(_selectedDates),
      weekDayPatterns: List.from(_weekDayPatterns),
    );

    // If current effective start date is no longer valid, clear it
    DateTime? newEffective = _effectiveStartDate;
    if (newEffective != null &&
        !dates.any((d) => _sameDay(d, newEffective!))) {
      newEffective = null;
    }
    // Auto-select first valid date if none chosen yet
    if (newEffective == null && dates.isNotEmpty) {
      newEffective = dates.first;
    }

    setState(() {
      _validStartDates = dates;
      _effectiveStartDate = newEffective;
    });
  }

  void _selectEffectiveStartDate(DateTime d) {
    setState(() => _effectiveStartDate = d);
  }

  Future<void> _pickSpecificDate() async {
    final clinicSlots = context.read<ClinicProvider>().slots;
    final clinicWeekdays = clinicSlots.map((s) => s.dayOfWeek).toSet();

    // initialDate must satisfy selectableDayPredicate — advance until we
    // land on a clinic operating day (max 7 tries).
    DateTime initialDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    if (clinicWeekdays.isNotEmpty) {
      int tries = 0;
      while (!clinicWeekdays.contains(initialDate.weekday) && tries < 7) {
        initialDate = initialDate.add(const Duration(days: 1));
        tries++;
      }
    }

    final firstDate = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final d = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 730)),
      selectableDayPredicate: clinicWeekdays.isEmpty
          ? null
          : (date) => clinicWeekdays.contains(date.weekday),
      helpText: clinicWeekdays.isNotEmpty
          ? 'Only clinic slot days are selectable'
          : 'Select appointment date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx)
                .colorScheme
                .copyWith(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() {
        _specificDate = d;
        _selectedDays
          ..clear()
          ..add(d.weekday);
      });
    }
  }

  bool get _canSave {
    if (_clinic == null || _doctor == null) return false;
    if (_type == ScheduleType.weekly) {
      if (_selectedDays.isEmpty) return false;
      // Every selected day must have a slot chosen
      if (_selectedDays.any((d) => !_selectedSlotPerDay.containsKey(d))) return false;
      return _effectiveStartDate != null;
    }
    if (_type == ScheduleType.oneTime) {
      return _specificDate != null && _selectedSlotPerDay.containsKey(0);
    }
    // monthly
    final hasSelection = _monthlyMode == MonthlyMode.dateBased
        ? _selectedDates.isNotEmpty
        : _weekDayPatterns.isNotEmpty;
    return hasSelection && _effectiveStartDate != null && _selectedSlotPerDay.containsKey(0);
  }

  String? _validate() {
    if (_clinic == null) return 'Please select a clinic.';
    if (_doctor == null) return 'Please select a doctor.';
    if (_type == ScheduleType.weekly) {
      if (_selectedDays.isEmpty) return 'Please select at least one day of the week.';
      final missing = _selectedDays.where((d) => !_selectedSlotPerDay.containsKey(d)).toList();
      if (missing.isNotEmpty) {
        const names = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};
        final labels = missing.map((d) => names[d]!).join(', ');
        return 'Please select a time slot for: $labels.';
      }
    } else {
      if (!_selectedSlotPerDay.containsKey(0)) return 'Please select a time slot.';
    }
    if (_type == ScheduleType.oneTime && _specificDate == null) {
      return 'Please select a date for the one-time schedule.';
    }
    if (_type == ScheduleType.monthly) {
      if (_monthlyMode == MonthlyMode.dateBased && _selectedDates.isEmpty) {
        return 'Please select at least one date of the month.';
      }
      if (_monthlyMode == MonthlyMode.dayPattern && _weekDayPatterns.isEmpty) {
        return 'Please add at least one week-day pattern.';
      }
    }
    if (_type != ScheduleType.oneTime && _effectiveStartDate == null) {
      return 'Please select an effective start date for the recurring schedule.';
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _errorMsg = err);
      return;
    }
    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    final slotIdsMap = <int, String>{};
    final slotLabelsMap = <int, String>{};
    for (final entry in _selectedSlotPerDay.entries) {
      slotIdsMap[entry.key] = entry.value.id;
      slotLabelsMap[entry.key] =
          entry.value.label ?? '${entry.value.dayShort} Slot';
    }

    final assignment = ScheduledAssignment(
      id: '',
      clinicId: _clinic!.id,
      clinicName: _clinic!.name,
      doctorId: _doctor!.id,
      doctorName: _doctor!.name,
      scheduleType: _type,
      slotIdsPerDay: slotIdsMap,
      slotLabelsPerDay: slotLabelsMap,
      selectedDays: Set.from(_selectedDays),
      specificDate: _specificDate,
      monthlyMode: _monthlyMode,
      selectedDates: List.from(_selectedDates),
      weekDayPatterns: List.from(_weekDayPatterns),
      effectiveStartDate: _type != ScheduleType.oneTime ? _effectiveStartDate : null,
    );

    final result =
        await context.read<ScheduleProvider>().save(assignment);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      setState(() => _errorMsg = result);
      return;
    }

    _reset();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Schedule saved successfully!'),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicProvider>(
      builder: (ctx, cp, _) {
        final loading = cp.loadingClinics || cp.loadingDoctors;
        if (loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return LoadingOverlay(
          isLoading: _saving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Step 1 – Clinic ─────────────────────────────────────
                _SectionCard(
                  step: 1,
                  title: 'Select Clinic',
                  child: _DropdownSelector<Clinic>(
                    hint: 'Choose a clinic',
                    items: cp.clinics,
                    selected: _clinic,
                    labelOf: (c) => c.name,
                    subtitleOf: (c) => c.address,
                    iconData: Icons.local_hospital_rounded,
                    onSelect: (c) {
                      setState(() {
                        _clinic = c;
                        _selectedSlotPerDay.clear(); // slots belong to clinic
                        _selectedDays.clear();
                        _specificDate = null;
                        _errorMsg = null;
                      });
                      context.read<ClinicProvider>().loadSlots(c.id);
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ── Step 2 – Doctor ─────────────────────────────────────
                _SectionCard(
                  step: 2,
                  title: 'Select Doctor',
                  child: _DropdownSelector<Doctor>(
                    hint: 'Choose a doctor',
                    items: cp.doctors,
                    selected: _doctor,
                    labelOf: (d) => d.name,
                    subtitleOf: (d) => d.specialization,
                    iconData: Icons.person_rounded,
                    onSelect: (d) => setState(() {
                      _doctor = d;
                      _errorMsg = null;
                    }),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Step 3 – Schedule type ──────────────────────────────
                _SectionCard(
                  step: 3,
                  title: 'Schedule Type',
                  child: ScheduleTypeSelector(
                    selected: _type,
                    onSelect: _onTypeChanged,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Step 4 – Day / Date selection ────────────────────
                _SectionCard(
                  step: 4,
                  title: _type == ScheduleType.weekly
                      ? 'Days of the Week'
                      : _type == ScheduleType.monthly
                          ? 'Monthly Recurrence'
                          : 'Select Date',
                  child: _DayDatePicker(
                    type: _type,
                    selectedDays: _selectedDays,
                    specificDate: _specificDate,
                    clinicWeekdays: _clinic == null
                        ? const {}
                        : cp.slots.map((s) => s.dayOfWeek).toSet(),
                    onToggleDay: _toggleDay,
                    onPickDate: _pickSpecificDate,
                    monthlyMode: _monthlyMode,
                    selectedDates: _selectedDates,
                    weekDayPatterns: _weekDayPatterns,
                    onMonthlyModeChanged: (m) {
                      setState(() {
                        _monthlyMode = m;
                        _selectedDates.clear();
                        _weekDayPatterns.clear();
                        _effectiveStartDate = null;
                        _validStartDates = [];
                      });
                    },
                    onToggleDate: (date) {
                      setState(() {
                        if (_selectedDates.contains(date)) {
                          _selectedDates.remove(date);
                        } else {
                          _selectedDates.add(date);
                        }
                      });
                      _recomputeValidStartDates();
                    },
                    onTogglePattern: (pattern) {
                      setState(() {
                        if (_weekDayPatterns.contains(pattern)) {
                          _weekDayPatterns.remove(pattern);
                        } else {
                          _weekDayPatterns.add(pattern);
                        }
                      });
                      _recomputeValidStartDates();
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ── Step 5 – Time Slot(s) ──────────────────────────────
                _SectionCard(
                  step: 5,
                  title: _type == ScheduleType.weekly
                      ? 'Time Slots per Day'
                      : 'Select Time Slot',
                  child: Consumer<ScheduleProvider>(
                    builder: (ctx, sp, _) {
                      if (_type == ScheduleType.weekly) {
                        return _WeeklyDaySlotPicker(
                          allSlots: cp.slots,
                          occupiedSlotIdsByDay: _clinic == null
                              ? const {}
                              : {
                                  for (final d in _selectedDays)
                                    d: sp.getOccupiedSlotIds(
                                        _clinic!.id,
                                        dayOfWeek: d),
                                },
                          selectedDays: _selectedDays,
                          selectedSlotPerDay: _selectedSlotPerDay,
                          onSelectSlot: (day, slot) => setState(() {
                            _selectedSlotPerDay[day] = slot;
                            _errorMsg = null;
                          }),
                        );
                      }
                      // Monthly / one-time: single slot picker
                      return _SlotPicker(
                        slots: cp.slots,
                        occupiedSlotIds: _clinic == null
                            ? const {}
                            : sp.getOccupiedSlotIds(_clinic!.id),
                        selectedSlot: _selectedSlotPerDay[0],
                        onSelect: (slot) => setState(() {
                          _selectedSlotPerDay[0] = slot;
                          _errorMsg = null;
                        }),
                      );
                    },
                  ),
                ),

                // ── Step 6 – Effective Start Date (recurring only) ───
                if (_type != ScheduleType.oneTime) ...[
                  const SizedBox(height: 14),
                  _SectionCard(
                    step: 6,
                    title: 'Effective Start Date',
                    child: _EffectiveStartDatePicker(
                      selectedDate: _effectiveStartDate,
                      validDates: _validStartDates,
                      onSelect: _selectEffectiveStartDate,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // ── Error banner ────────────────────────────────────────
                if (_errorMsg != null)
                  _ErrorBanner(message: _errorMsg!),

                const SizedBox(height: 6),

                // ── Save button ─────────────────────────────────────────
                _SaveButton(
                  enabled: _canSave && !_saving,
                  onSave: _save,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — ALL SCHEDULES LIST
// ═══════════════════════════════════════════════════════════════════════════════

class _ScheduleListTab extends StatelessWidget {
  const _ScheduleListTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (ctx, sp, _) {
        if (sp.schedules.isEmpty) {
          return _EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No Schedules Yet',
            subtitle:
                'Create your first schedule using the\n"New Schedule" tab.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          itemCount: sp.schedules.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final s = sp.schedules[i];
            return _ScheduleCard(
              schedule: s,
              onDelete: () => sp.remove(s.id),
            );
          },
        );
      },
    );
  }
}

// ── Schedule card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final ScheduledAssignment schedule;
  final VoidCallback onDelete;

  const _ScheduleCard({required this.schedule, required this.onDelete});

  static String _fmtCardDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  static const _typeMeta = {
    ScheduleType.weekly: (
      icon: Icons.repeat_rounded,
      label: 'Weekly',
      color: Color(0xFF059669),
      bg: Color(0xFFD1FAE5),
    ),
    ScheduleType.monthly: (
      icon: Icons.calendar_month_rounded,
      label: 'Monthly',
      color: Color(0xFF7C3AED),
      bg: Color(0xFFEDE9FE),
    ),
    ScheduleType.oneTime: (
      icon: Icons.today_rounded,
      label: 'One-time',
      color: Color(0xFFF59E0B),
      bg: Color(0xFFFEF3C7),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta[schedule.scheduleType]!;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: const Border(
                  bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: meta.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(meta.icon, size: 12, color: meta.color),
                    const SizedBox(width: 5),
                    Text(meta.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: meta.color)),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(schedule.scheduleSummaryLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppTheme.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('Remove Schedule'),
                        content: Text(
                            'Remove ${schedule.doctorName}\'s schedule at ${schedule.clinicName}?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.error),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) onDelete();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clinic + Doctor
                Row(
                  children: [
                    Expanded(
                        child: _DetailRow(
                            icon: Icons.local_hospital_rounded,
                            text: schedule.clinicName)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _DetailRow(
                            icon: Icons.person_rounded,
                            text: schedule.doctorName)),
                  ],
                ),
                if (schedule.effectiveStartDate != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.play_circle_outline_rounded,
                    text: 'Starts ${_fmtCardDate(schedule.effectiveStartDate!)}',
                  ),
                ],
                if (schedule.slotLabelsPerDay.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...schedule.slotLabelsPerDay.entries.map((e) {
                    const dayNames = {
                      0: '', 1: 'Mon', 2: 'Tue', 3: 'Wed',
                      4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun',
                    };
                    final prefix = e.key == 0 ? '' : '${dayNames[e.key]}: ';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _DetailRow(
                        icon: Icons.access_time_rounded,
                        text: '$prefix${e.value}',
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textTertiary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ],
      );
}

// ── Weekly day-slot picker ────────────────────────────────────────────────────

/// For Weekly schedules: shows one section per selected day, each containing
/// only the clinic slots that fall on that day.  Occupied slots are greyed-out.
/// Days that have no clinic slots show a "Doctor not available" note.
class _WeeklyDaySlotPicker extends StatelessWidget {
  final List<ClinicSlot> allSlots;
  // {dayOfWeek: Set<occupiedSlotId>} — built from ScheduleProvider
  final Map<int, Set<String>> occupiedSlotIdsByDay;
  final Set<int> selectedDays;
  final Map<int, ClinicSlot> selectedSlotPerDay;
  final void Function(int day, ClinicSlot slot) onSelectSlot;

  const _WeeklyDaySlotPicker({
    required this.allSlots,
    required this.occupiedSlotIdsByDay,
    required this.selectedDays,
    required this.selectedSlotPerDay,
    required this.onSelectSlot,
  });

  static const _dayNames = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday',
    4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
  };

  static String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    if (selectedDays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.textTertiary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Select days in Step 4 first to see available time slots.',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    final sortedDays = (selectedDays.toList()..sort());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info hint: occupied slots
        Row(
          children: const [
            Icon(Icons.info_outline_rounded, size: 12, color: AppTheme.textTertiary),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Greyed-out slots are already assigned to another doctor',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // One section per selected day
        ...sortedDays.map((day) {
          final daySlots = allSlots.where((s) => s.dayOfWeek == day).toList();
          final occupied = occupiedSlotIdsByDay[day] ?? const <String>{};
          final selected = selectedSlotPerDay[day];

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _dayNames[day] ?? 'Day $day',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    if (selected != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        selected.label ?? '${_fmtTime(selected.startTime)} – ${_fmtTime(selected.endTime)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // No slots for this day
                if (daySlots.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.event_busy_rounded,
                            size: 14, color: AppTheme.error),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No clinic slots available on this day.',
                            style: TextStyle(fontSize: 12, color: AppTheme.error),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Slot chips for this day
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: daySlots.map((slot) {
                      final isOccupied = occupied.contains(slot.id);
                      final isSelected = selected?.id == slot.id;
                      return GestureDetector(
                        onTap: isOccupied ? null : () => onSelectSlot(day, slot),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: isOccupied
                                ? AppTheme.surfaceAlt
                                : isSelected
                                    ? AppTheme.primaryContainer
                                    : AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOccupied
                                  ? AppTheme.borderLight
                                  : isSelected
                                      ? AppTheme.primary
                                      : AppTheme.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: isOccupied
                                        ? AppTheme.textTertiary
                                        : isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_fmtTime(slot.startTime)} – ${_fmtTime(slot.endTime)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isOccupied
                                          ? AppTheme.textTertiary
                                          : isSelected
                                              ? AppTheme.primary
                                              : AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (isOccupied) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorBg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Assigned',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.error,
                                        ),
                                      ),
                                    ),
                                  ] else if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_rounded,
                                          size: 11, color: Colors.white),
                                    ),
                                  ],
                                ],
                              ),
                              if (slot.label != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  slot.label!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOccupied
                                        ? AppTheme.textTertiary
                                        : isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Slot picker ───────────────────────────────────────────────────────────────

/// Displays all clinic slots for the selected clinic.  Occupied slots (already
/// assigned in any existing schedule) are shown as disabled/greyed-out.
class _SlotPicker extends StatelessWidget {
  final List<ClinicSlot> slots;
  final Set<String> occupiedSlotIds;
  final ClinicSlot? selectedSlot;
  final void Function(ClinicSlot) onSelect;

  const _SlotPicker({
    required this.slots,
    required this.occupiedSlotIds,
    required this.selectedSlot,
    required this.onSelect,
  });

  static String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 16, color: AppTheme.textTertiary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No clinic slots available. Select a clinic first.',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Helper note
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 12, color: AppTheme.textTertiary),
            const SizedBox(width: 5),
            const Flexible(
              child: Text(
                'Greyed-out slots are already assigned to another doctor',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...slots.map((slot) {
          final isOccupied = occupiedSlotIds.contains(slot.id);
          final isSelected = selectedSlot?.id == slot.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: isOccupied ? null : () => onSelect(slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? AppTheme.surfaceAlt
                      : isSelected
                          ? AppTheme.primaryContainer
                          : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOccupied
                        ? AppTheme.borderLight
                        : isSelected
                            ? AppTheme.primary
                            : AppTheme.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Day pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOccupied
                            ? AppTheme.borderLight
                            : isSelected
                                ? AppTheme.primary
                                : AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        slot.dayShort,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOccupied
                              ? AppTheme.textTertiary
                              : isSelected
                                  ? Colors.white
                                  : AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Time range + label
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_fmtTime(slot.startTime)} – ${_fmtTime(slot.endTime)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isOccupied
                                  ? AppTheme.textTertiary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          if (slot.label != null)
                            Text(
                              slot.label!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isOccupied
                                    ? AppTheme.textTertiary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status / selection indicator
                    if (isOccupied)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.errorBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Assigned',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.error,
                          ),
                        ),
                      )
                    else if (isSelected)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 13, color: Colors.white),
                      )
                    else
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.border, width: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Effective start date picker ──────────────────────────────────────────────

/// Shows a calendar DatePicker filtered to only valid start dates derived from
/// the selected recurrence pattern and doctor availability (weekday-only,
/// ignoring time slots).  Invalid dates are greyed out / non-selectable.
class _EffectiveStartDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final List<DateTime> validDates;
  final void Function(DateTime) onSelect;

  const _EffectiveStartDatePicker({
    required this.selectedDate,
    required this.validDates,
    required this.onSelect,
  });

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  static const _weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  static String _fmtFull(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';

  Future<void> _openPicker(BuildContext context) async {
    if (validDates.isEmpty) return;

    // Advance initialDate to the first valid date
    final initial = (selectedDate != null &&
            validDates.any((d) => _sameDay(d, selectedDate!)))
        ? selectedDate!
        : validDates.first;

    final validSet = {
      for (final d in validDates)
        DateTime(d.year, d.month, d.day),
    };

    // Allow free navigation from today through the full look-ahead window
    // so the user can scroll between months; the predicate disables bad dates.
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final lastDate = validDates.last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: lastDate,
      helpText: 'Only valid dates based on recurrence and availability are selectable',
      selectableDayPredicate: (date) =>
          validSet.contains(DateTime(date.year, date.month, date.day)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;
    final hasValid = validDates.isNotEmpty;

    // ── No pattern selected yet ──────────────────────────────────────────
    if (!hasValid) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 18, color: AppTheme.textTertiary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No available start dates for selected pattern.\n'
                'Select days / dates in Step 4 first.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textTertiary, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    // ── Tap tile ─────────────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openPicker(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  hasDate ? AppTheme.primaryContainer : AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasDate ? AppTheme.primary : AppTheme.border,
                width: hasDate ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasDate ? AppTheme.primary : AppTheme.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_available_rounded,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasDate
                            ? _fmtFull(selectedDate!)
                            : 'Tap to select start date',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: hasDate
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: hasDate
                              ? AppTheme.textPrimary
                              : AppTheme.textTertiary,
                        ),
                      ),
                      Text(
                        hasDate
                            ? 'Recurring schedule begins from this date'
                            : 'Only available dates are selectable',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasDate
                      ? Icons.edit_calendar_rounded
                      : Icons.chevron_right_rounded,
                  color: hasDate ? AppTheme.primary : AppTheme.textTertiary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 12, color: AppTheme.textTertiary),
            const SizedBox(width: 4),
            Text(
              '${validDates.length} selectable date${validDates.length == 1 ? '' : 's'} '
              'within the next 90 days',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE FORM COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

// ── Section card────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final int step;
  final String title;
  final Widget child;
  const _SectionCard(
      {required this.step, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('$step',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Dropdown selector ─────────────────────────────────────────────────────────

class _DropdownSelector<T> extends StatelessWidget {
  final String hint;
  final List<T> items;
  final T? selected;
  final String Function(T) labelOf;
  final String Function(T) subtitleOf;
  final IconData iconData;
  final void Function(T) onSelect;

  const _DropdownSelector({
    required this.hint,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.subtitleOf,
    required this.iconData,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('No items available',
          style: const TextStyle(
              fontSize: 13, color: AppTheme.textTertiary));
    }
    return InputDecorator(
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          hint: Text(hint,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textTertiary)),
          isExpanded: true,
          itemHeight: 56,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(iconData,
                        size: 14, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(labelOf(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        Text(subtitleOf(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onSelect(v);
          },
        ),
      ),
    );
  }
}

// ── Schedule type selector ────────────────────────────────────────────────────

class ScheduleTypeSelector extends StatelessWidget {
  final ScheduleType selected;
  final void Function(ScheduleType) onSelect;
  const ScheduleTypeSelector(
      {super.key, required this.selected, required this.onSelect});

  static const _options = [
    (
      ScheduleType.weekly,
      Icons.repeat_rounded,
      'Recurring Weekly',
      'Repeat every week on selected days',
    ),
    (
      ScheduleType.monthly,
      Icons.calendar_month_rounded,
      'Recurring Monthly',
      'Repeat on selected dates each month',
    ),
    (
      ScheduleType.oneTime,
      Icons.today_rounded,
      'One-time Date',
      'Schedule for a single specific date',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _options.map((opt) {
        final (type, icon, label, subtitle) = opt;
        final isSel = selected == type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onSelect(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: isSel ? AppTheme.primaryContainer : AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? AppTheme.primary : AppTheme.borderLight,
                  width: isSel ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSel ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: isSel
                          ? null
                          : Border.all(color: AppTheme.borderLight),
                    ),
                    child: Icon(icon,
                        size: 20,
                        color: isSel ? Colors.white : AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSel
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? AppTheme.primary : Colors.transparent,
                      border: Border.all(
                        color: isSel ? AppTheme.primary : AppTheme.border,
                        width: 2,
                      ),
                    ),
                    child: isSel
                        ? const Icon(Icons.check_rounded,
                            size: 13, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Day / Date picker ─────────────────────────────────────────────────────────

class _DayDatePicker extends StatelessWidget {
  final ScheduleType type;
  // weekly
  final Set<int> selectedDays;
  final Set<int> clinicWeekdays;
  final void Function(int) onToggleDay;
  // oneTime
  final DateTime? specificDate;
  final VoidCallback onPickDate;
  // monthly
  final MonthlyMode monthlyMode;
  final List<int> selectedDates;
  final List<WeekDayPattern> weekDayPatterns;
  final void Function(MonthlyMode) onMonthlyModeChanged;
  final void Function(int) onToggleDate;
  final void Function(WeekDayPattern) onTogglePattern;

  const _DayDatePicker({
    required this.type,
    required this.selectedDays,
    required this.specificDate,
    required this.clinicWeekdays,
    required this.onToggleDay,
    required this.onPickDate,
    this.monthlyMode = MonthlyMode.dateBased,
    this.selectedDates = const [],
    this.weekDayPatterns = const [],
    required this.onMonthlyModeChanged,
    required this.onToggleDate,
    required this.onTogglePattern,
  });

  static const _weekAbbr = [
    (1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'),
    (5, 'Fri'), (6, 'Sat'), (7, 'Sun'),
  ];

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case ScheduleType.weekly:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (clinicWeekdays.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 12, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    const Flexible(
                      child: Text(
                        'Only clinic operating days are selectable',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekAbbr.map((d) {
                final (num, abbr) = d;
                final isSel = selectedDays.contains(num);
                final isEnabled =
                    clinicWeekdays.isEmpty || clinicWeekdays.contains(num);
                return GestureDetector(
                  onTap: isEnabled ? () => onToggleDay(num) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppTheme.primary
                          : isEnabled
                              ? AppTheme.surfaceAlt
                              : AppTheme.borderLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? AppTheme.primary
                            : isEnabled
                                ? AppTheme.border
                                : AppTheme.borderLight,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(abbr,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? Colors.white
                                  : isEnabled
                                      ? AppTheme.textSecondary
                                      : AppTheme.textTertiary)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );

      case ScheduleType.monthly:
        return _MonthlyPicker(
          monthlyMode: monthlyMode,
          selectedDates: selectedDates,
          weekDayPatterns: weekDayPatterns,
          onModeChanged: onMonthlyModeChanged,
          onToggleDate: onToggleDate,
          onTogglePattern: onTogglePattern,
        );

      case ScheduleType.oneTime:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (clinicWeekdays.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 13, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Only dates with clinic slots are selectable',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            GestureDetector(
              onTap: onPickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: specificDate != null
                      ? AppTheme.primaryContainer
                      : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: specificDate != null
                          ? AppTheme.primary
                          : AppTheme.border,
                      width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: specificDate != null
                            ? AppTheme.primary
                            : AppTheme.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_rounded,
                          size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            specificDate == null
                                ? 'Tap to select date'
                                : _fmtDate(specificDate!),
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: specificDate != null
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: specificDate != null
                                    ? AppTheme.textPrimary
                                    : AppTheme.textTertiary),
                          ),
                          if (specificDate == null)
                            const Text('Calendar will open',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textTertiary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textTertiary, size: 18),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  static String _fmtDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${w[d.weekday - 1]}, ${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Monthly picker (tabbed: date-based vs day-pattern) ────────────────────────

class _MonthlyPicker extends StatelessWidget {
  final MonthlyMode monthlyMode;
  final List<int> selectedDates;
  final List<WeekDayPattern> weekDayPatterns;
  final void Function(MonthlyMode) onModeChanged;
  final void Function(int) onToggleDate;
  final void Function(WeekDayPattern) onTogglePattern;

  const _MonthlyPicker({
    required this.monthlyMode,
    required this.selectedDates,
    required this.weekDayPatterns,
    required this.onModeChanged,
    required this.onToggleDate,
    required this.onTogglePattern,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Mode toggle ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              _ModeTab(
                label: 'By Date',
                icon: Icons.tag_rounded,
                selected: monthlyMode == MonthlyMode.dateBased,
                onTap: () => onModeChanged(MonthlyMode.dateBased),
              ),
              _ModeTab(
                label: 'By Pattern',
                icon: Icons.date_range_rounded,
                selected: monthlyMode == MonthlyMode.dayPattern,
                onTap: () => onModeChanged(MonthlyMode.dayPattern),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Content ────────────────────────────────────────────────────
        if (monthlyMode == MonthlyMode.dateBased)
          _DateOfMonthPicker(
            selectedDates: selectedDates,
            onToggleDate: onToggleDate,
          )
        else
          _DayPatternPicker(
            patterns: weekDayPatterns,
            onTogglePattern: onTogglePattern,
          ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.textTertiary),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date-of-month picker (1–31 chips grid) ────────────────────────────────────

class _DateOfMonthPicker extends StatelessWidget {
  final List<int> selectedDates;
  final void Function(int) onToggleDate;

  const _DateOfMonthPicker({
    required this.selectedDates,
    required this.onToggleDate,
  });

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = (List<int>.from(selectedDates)..sort());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid 1–31
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: List.generate(31, (i) {
            final date = i + 1;
            final isSel = selectedDates.contains(date);
            return GestureDetector(
              onTap: () => onToggleDate(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: isSel ? AppTheme.primary : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel ? AppTheme.primary : AppTheme.borderLight,
                    width: 1.5,
                  ),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color:
                                AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$date',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        // Helper note about short months
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 12, color: AppTheme.textTertiary),
            const SizedBox(width: 4),
            const Flexible(
              child: Text(
                'Dates not existing in a month (e.g. Feb 30) will be skipped',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
        // Selected chips
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: AppTheme.borderLight),
          const SizedBox(height: 10),
          // Preview text
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview_rounded,
                    size: 13, color: AppTheme.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Every ${sorted.map(_ordinal).join(' & ')} of the month',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: sorted.map((date) {
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      child: Text(
                        _ordinal(date),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onToggleDate(date),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(0, 6, 9, 6),
                        child: Icon(Icons.close_rounded,
                            size: 13, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Day-of-week pattern picker ────────────────────────────────────────────────

class _DayPatternPicker extends StatefulWidget {
  final List<WeekDayPattern> patterns;
  final void Function(WeekDayPattern) onTogglePattern;

  const _DayPatternPicker({
    required this.patterns,
    required this.onTogglePattern,
  });

  @override
  State<_DayPatternPicker> createState() => _DayPatternPickerState();
}

class _DayPatternPickerState extends State<_DayPatternPicker> {
  static const _posOptions = [
    (1, '1st'),
    (2, '2nd'),
    (3, '3rd'),
    (4, '4th'),
    (5, 'Last'),
  ];

  static const _dayOptions = [
    (1, 'Mon'),
    (2, 'Tue'),
    (3, 'Wed'),
    (4, 'Thu'),
    (5, 'Fri'),
    (6, 'Sat'),
    (7, 'Sun'),
  ];

  int _selPos = 1;
  int _selDay = 1;

  void _addPattern() {
    final p = WeekDayPattern(weekPosition: _selPos, dayOfWeek: _selDay);
    widget.onTogglePattern(p);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<WeekDayPattern>.from(widget.patterns);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Builder row ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a pattern',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Week position dropdown
                  Expanded(
                    child: _PillDropdown<int>(
                      value: _selPos,
                      items: _posOptions,
                      onChanged: (v) => setState(() => _selPos = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Day of week dropdown
                  Expanded(
                    child: _PillDropdown<int>(
                      value: _selDay,
                      items: _dayOptions,
                      onChanged: (v) => setState(() => _selDay = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add button
                  GestureDetector(
                    onTap: () {
                      final p = WeekDayPattern(
                          weekPosition: _selPos, dayOfWeek: _selDay);
                      if (!widget.patterns.contains(p)) _addPattern();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Preview of pending selection
              Text(
                'Will add: ${WeekDayPattern(weekPosition: _selPos, dayOfWeek: _selDay).label}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Added patterns ─────────────────────────────────────────────
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No patterns added yet. Select a position and day above.',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
          )
        else ...[
          // Preview text
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview_rounded,
                    size: 13, color: AppTheme.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Every ${sorted.map((p) => p.label).join(' & ')}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: sorted.map((pattern) {
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      child: Text(
                        pattern.label,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onTogglePattern(pattern),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(0, 6, 9, 6),
                        child: Icon(Icons.close_rounded,
                            size: 13, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Pill dropdown ─────────────────────────────────────────────────────────────

class _PillDropdown<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final void Function(T) onChanged;

  const _PillDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        isDense: true,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item.$1,
                    child: Text(item.$2),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}



// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSave;
  const _SaveButton({required this.enabled, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? onSave : null,
        icon: const Icon(Icons.save_rounded, size: 18),
        label: const Text('Save Schedule',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppTheme.primary,
          disabledBackgroundColor: AppTheme.border,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.error,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}
