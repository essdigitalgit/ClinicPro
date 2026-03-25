import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/doctor.dart';
import '../models/availability.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/loading_overlay.dart';

/// Screen for managing a doctor's weekly availability.
class AvailabilityScreen extends StatefulWidget {
  final Doctor doctor;

  const AvailabilityScreen({super.key, required this.doctor});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  static const _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const _dayFull = [
    'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicProvider>().loadAvailability(widget.doctor.id);
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) _startTime = picked;
      else _endTime = picked;
    });
  }

  Future<void> _addSlot() async {
    final error = await context.read<ClinicProvider>().addAvailability(
      doctorId: widget.doctor.id,
      dayOfWeek: _selectedDay,
      startTime: _startTime,
      endTime: _endTime,
    );
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability slot added!'),
          backgroundColor: AppTheme.success,
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
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Availability',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                Text(
                  widget.doctor.name,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Doctor banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.headerGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.doctor.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          Text(widget.doctor.specialization,
                              style: const TextStyle(
                                  color: Color(0xCCFFFFFF), fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Add slot card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppTheme.borderLight, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.add_circle_rounded,
                            size: 18, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text('Add Availability Slot',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                      ]),
                      const SizedBox(height: 16),

                      // Day chips
                      const Text('Day of Week',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(7, (i) {
                            final day = i + 1;
                            final sel = _selectedDay == day;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedDay = day),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppTheme.primary
                                        : AppTheme.surfaceAlt,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel
                                          ? AppTheme.primary
                                          : AppTheme.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    _dayLabels[i],
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? Colors.white
                                            : AppTheme.textSecondary),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Time pickers
                      const Text('Time Range',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeTile(
                              label: 'Start',
                              time: _startTime,
                              icon: Icons.play_arrow_rounded,
                              onTap: () => _pickTime(isStart: true),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 18, color: AppTheme.textTertiary),
                          ),
                          Expanded(
                            child: _TimeTile(
                              label: 'End',
                              time: _endTime,
                              icon: Icons.stop_rounded,
                              onTap: () => _pickTime(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      FilledButton.icon(
                        onPressed: _addSlot,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                            'Add ${_dayFull[_selectedDay - 1]} Slot'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Weekly schedule
                Row(
                  children: [
                    const Text('Weekly Schedule',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const Spacer(),
                    if (!provider.loadingAvailability &&
                        provider.availabilities.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${provider.availabilities.length} slot${provider.availabilities.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (provider.loadingAvailability)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                else if (provider.availabilities.isEmpty)
                  const _EmptySchedule()
                else
                  ...provider.availabilities.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AvailabilitySlotCard(availability: a),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8D8EF), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500)),
                Text(
                  TimeUtils.format12(time),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilitySlotCard extends StatelessWidget {
  final Availability availability;

  const _AvailabilitySlotCard({required this.availability});

  int get _slotCount {
    final mins =
        (availability.endTime.hour * 60 + availability.endTime.minute) -
            (availability.startTime.hour * 60 +
                availability.startTime.minute);
    return mins ~/ 30;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 22, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(availability.dayName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${TimeUtils.format12(availability.startTime)} \u2013 ${TimeUtils.format12(availability.endTime)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 12, color: AppTheme.success),
                const SizedBox(width: 4),
                Text(
                  '$_slotCount slot${_slotCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 28, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          const Text('No availability set',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Add slots above to define when this doctor is available',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
