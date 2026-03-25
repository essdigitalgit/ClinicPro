import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../theme/app_theme.dart';

/// Premium card widget displaying [Doctor] info with specialty badge.
class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onManageAvailability;
  final VoidCallback onBookAppointment;

  const DoctorCard({
    super.key,
    required this.doctor,
    required this.onManageAvailability,
    required this.onBookAppointment,
  });

  Color _accentColor() {
    final s = doctor.specialization.toLowerCase();
    if (s.contains('cardio')) return const Color(0xFFEF4444);
    if (s.contains('paedia') || s.contains('pedia')) return const Color(0xFFF59E0B);
    if (s.contains('ortho')) return const Color(0xFF8B5CF6);
    if (s.contains('general') || s.contains('physician')) return AppTheme.primary;
    if (s.contains('neuro')) return const Color(0xFF0EA5E9);
    if (s.contains('derma')) return const Color(0xFFEC4899);
    return const Color(0xFF059669);
  }

  @override
  Widget build(BuildContext context) {
    final ac = _accentColor();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: ac.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_rounded, size: 28, color: ac),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ac.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doctor.specialization,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ac,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.borderLight, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_rounded, size: 15),
                  label: const Text('Availability'),
                  onPressed: onManageAvailability,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                  label: const Text('Book Appt.'),
                  onPressed: onBookAppointment,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
