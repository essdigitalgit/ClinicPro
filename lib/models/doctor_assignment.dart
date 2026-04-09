/// How a doctor is scheduled for a slot.
enum AssignmentType { oneTime, dateRange, weekly, monthly }

/// Pattern for monthly recurrences ("1st Monday", "2nd Tuesday", etc.).
class MonthlyPattern {
  /// Which occurrence: 1 = first, 2 = second, 3 = third, 4 = fourth, -1 = last.
  final int week;

  /// Day of week: 1 = Monday … 7 = Sunday.
  final int dayOfWeek;

  const MonthlyPattern({required this.week, required this.dayOfWeek});

  @override
  String toString() {
    const weekLabels = {1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'};
    const dayLabels = {
      1: 'Monday', 2: 'Tuesday', 3: 'Wednesday',
      4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday',
    };
    return '${weekLabels[week]} ${dayLabels[dayOfWeek]}';
  }

  @override
  bool operator ==(Object other) =>
      other is MonthlyPattern && other.week == week && other.dayOfWeek == dayOfWeek;

  @override
  int get hashCode => Object.hash(week, dayOfWeek);
}

/// Links a [Doctor] to a [ClinicSlot] with flexible scheduling support.
class DoctorAssignment {
  final String id;
  final String clinicId;
  final String doctorId;
  final String slotId;
  final AssignmentType assignmentType;

  /// Relevant for all types: the first effective date.
  final DateTime? startDate;

  /// For [AssignmentType.dateRange]: the last effective date (inclusive).
  /// For [AssignmentType.weekly] / [AssignmentType.monthly]: optional cutoff.
  final DateTime? endDate;

  /// For [AssignmentType.weekly]: set of weekday numbers (1 = Mon … 7 = Sun).
  final Set<int> daysOfWeek;

  /// For [AssignmentType.monthly].
  final MonthlyPattern? monthlyPattern;

  const DoctorAssignment({
    required this.id,
    required this.clinicId,
    required this.doctorId,
    required this.slotId,
    this.assignmentType = AssignmentType.oneTime,
    this.startDate,
    this.endDate,
    this.daysOfWeek = const {},
    this.monthlyPattern,
  });

  /// Human-readable summary of this assignment's recurrence.
  String get scheduleSummary {
    switch (assignmentType) {
      case AssignmentType.oneTime:
        if (startDate == null) return 'Permanent (all occurrences)';
        final d = startDate!;
        return 'On ${_fmt(d)}';
      case AssignmentType.dateRange:
        final s = startDate != null ? _fmt(startDate!) : '?';
        final e = endDate != null ? _fmt(endDate!) : '?';
        return '$s – $e';
      case AssignmentType.weekly:
        final days = _sortedDayNames(daysOfWeek);
        final until = endDate != null ? ' until ${_fmt(endDate!)}' : '';
        return 'Every $days$until';
      case AssignmentType.monthly:
        final p = monthlyPattern?.toString() ?? '?';
        final until = endDate != null ? ' until ${_fmt(endDate!)}' : '';
        return '$p of every month$until';
    }
  }

  static String _fmt(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _sortedDayNames(Set<int> days) {
    const names = {
      1: 'Mon', 2: 'Tue', 3: 'Wed',
      4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun',
    };
    final sorted = days.toList()..sort();
    return sorted.map((d) => names[d]!).join(', ');
  }

  /// Returns true if this assignment is active on [date].
  bool isActiveOn(DateTime date) {
    final day = date.weekday; // 1 = Mon … 7 = Sun
    switch (assignmentType) {
      case AssignmentType.oneTime:
        if (startDate == null) return true;
        return _sameDay(date, startDate!);
      case AssignmentType.dateRange:
        final s = startDate;
        final e = endDate;
        if (s == null || e == null) return false;
        final d = DateTime(date.year, date.month, date.day);
        return !d.isBefore(DateTime(s.year, s.month, s.day)) &&
            !d.isAfter(DateTime(e.year, e.month, e.day));
      case AssignmentType.weekly:
        if (!daysOfWeek.contains(day)) return false;
        if (startDate != null &&
            date.isBefore(DateTime(
                startDate!.year, startDate!.month, startDate!.day))) {
          return false;
        }
        if (endDate != null &&
            date.isAfter(
                DateTime(endDate!.year, endDate!.month, endDate!.day))) {
          return false;
        }
        return true;
      case AssignmentType.monthly:
        final p = monthlyPattern;
        if (p == null) return false;
        if (day != p.dayOfWeek) return false;
        if (endDate != null &&
            date.isAfter(
                DateTime(endDate!.year, endDate!.month, endDate!.day))) {
          return false;
        }
        return _isNthWeekdayOfMonth(date, p.week, p.dayOfWeek);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isNthWeekdayOfMonth(DateTime date, int week, int targetDay) {
    if (date.weekday != targetDay) return false;
    if (week == -1) {
      // Last occurrence
      final nextWeek = date.add(const Duration(days: 7));
      return nextWeek.month != date.month;
    }
    // Count how many times this weekday has occurred in the month up to [date].
    int count = 0;
    for (int d = 1; d <= date.day; d++) {
      final candidate = DateTime(date.year, date.month, d);
      if (candidate.weekday == targetDay) count++;
    }
    return count == week;
  }
}
