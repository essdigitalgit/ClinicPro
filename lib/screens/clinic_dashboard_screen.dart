import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clinic.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import 'clinic_slot_management_screen.dart';
import 'doctor_assignment_screen.dart';

/// Hub screen for a single clinic: shows stats and leads to sub-flows.
class ClinicDashboardScreen extends StatefulWidget {
  final Clinic clinic;

  const ClinicDashboardScreen({super.key, required this.clinic});

  @override
  State<ClinicDashboardScreen> createState() => _ClinicDashboardScreenState();
}

class _ClinicDashboardScreenState extends State<ClinicDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ClinicProvider>();
      Future.wait([
        p.loadSlots(widget.clinic.id),
        p.loadAssignments(widget.clinic.id),
        p.loadAppointments(clinicId: widget.clinic.id),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<ClinicProvider>(builder: (context, provider, _) {
        final slotCount = provider.slots.length;
        final assignedCount = provider.assignments.length;
        final apptCount =
            provider.appointments.where((a) => a.clinicId == widget.clinic.id).length;

        return CustomScrollView(
          slivers: [
            // ── Gradient header ──────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: AppTheme.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                      gradient: AppTheme.headerGradient),
                  padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.local_hospital_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.clinic.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(widget.clinic.address,
                                    style: const TextStyle(
                                        color: Color(0xCCFFFFFF),
                                        fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Stats row ────────────────────────────────────────────
                    Row(
                      children: [
                        _StatBadge(
                          icon: Icons.schedule_rounded,
                          label: 'Slots',
                          value: slotCount,
                          color: AppTheme.primary,
                          bg: AppTheme.primaryContainer,
                        ),
                        const SizedBox(width: 10),
                        _StatBadge(
                          icon: Icons.people_rounded,
                          label: 'Assigned',
                          value: assignedCount,
                          color: AppTheme.success,
                          bg: AppTheme.successBg,
                        ),
                        const SizedBox(width: 10),
                        _StatBadge(
                          icon: Icons.event_rounded,
                          label: 'Bookings',
                          value: apptCount,
                          color: const Color(0xFFF59E0B),
                          bg: const Color(0xFFFEF3C7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Section label ─────────────────────────────────────────
                    const Text(
                      'Clinic Management',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 12),

                    // ── Action cards ──────────────────────────────────────────
                    _ActionCard(
                      icon: Icons.schedule_rounded,
                      iconBg: AppTheme.primaryContainer,
                      iconColor: AppTheme.primary,
                      title: 'Manage Slots',
                      subtitle:
                          'Define working windows for this clinic ($slotCount slot${slotCount == 1 ? '' : 's'})',
                      onTap: () {
                        final p = context.read<ClinicProvider>();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClinicSlotManagementScreen(
                                clinic: widget.clinic),
                          ),
                        ).then((_) {
                          p.loadSlots(widget.clinic.id);
                          p.loadAssignments(widget.clinic.id);
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    _ActionCard(
                      icon: Icons.assignment_ind_rounded,
                      iconBg: AppTheme.successBg,
                      iconColor: AppTheme.success,
                      title: 'Assign Doctors',
                      subtitle:
                          'Staff clinic slots with doctors ($assignedCount assignment${assignedCount == 1 ? '' : 's'})',
                      onTap: () {
                        final p = context.read<ClinicProvider>();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DoctorAssignmentScreen(clinic: widget.clinic),
                          ),
                        ).then((_) => p.loadAssignments(widget.clinic.id));
                      },
                    ),
                    const SizedBox(height: 10),

                    _ActionCard(
                      icon: Icons.event_available_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFF59E0B),
                      title: 'View Appointments',
                      subtitle:
                          '$apptCount appointment${apptCount == 1 ? '' : 's'} booked at this clinic',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _AppointmentsListScreen(clinic: widget.clinic),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Contact ───────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.borderLight, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.phone_rounded,
                                size: 18, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Contact',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textTertiary)),
                              Text(widget.clinic.phone,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Stat badge ────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color bg;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(value.toString(),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }
}

// ── Action card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textTertiary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inline appointments list ──────────────────────────────────────────────────

class _AppointmentsListScreen extends StatefulWidget {
  final Clinic clinic;
  const _AppointmentsListScreen({required this.clinic});

  @override
  State<_AppointmentsListScreen> createState() =>
      _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<_AppointmentsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicProvider>().loadAppointments(clinicId: widget.clinic.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            const Text('Appointments',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(widget.clinic.name,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textTertiary)),
          ],
        ),
      ),
      body: Consumer<ClinicProvider>(
        builder: (context, provider, _) {
          final appts = provider.appointments
              .where((a) => a.clinicId == widget.clinic.id)
              .toList()
            ..sort((a, b) =>
                a.appointmentDate.compareTo(b.appointmentDate));

          if (appts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.event_busy_rounded,
                        size: 40, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text('No appointments yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('Appointments booked at this clinic appear\nhere.',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textTertiary),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: appts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = appts[i];
              final doctor = provider.doctors
                  .where((d) => d.id == a.doctorId)
                  .firstOrNull;
              final dateStr =
                  '${a.appointmentDate.day}/${a.appointmentDate.month}/${a.appointmentDate.year}';
              final h = a.appointmentTime.hour;
              final m = a.appointmentTime.minute.toString().padLeft(2, '0');
              final period = h < 12 ? 'AM' : 'PM';
              final h12 = h % 12 == 0 ? 12 : h % 12;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppTheme.borderLight, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.successBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_rounded,
                          size: 22, color: AppTheme.success),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.patientName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            doctor != null
                                ? '${doctor.name} · ${doctor.specialization}'
                                : 'Doctor',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$h12:$m $period',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
