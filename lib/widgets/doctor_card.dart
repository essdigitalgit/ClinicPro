import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../theme/app_theme.dart';

/// Premium card widget displaying [Doctor] info with specialty badge.
class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback? onEdit;

  const DoctorCard({
    super.key,
    required this.doctor,
    this.onEdit,
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
                  color: Color.fromRGBO(
                    ac.r.toInt(), ac.g.toInt(), ac.b.toInt(), 0.12),
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
                        color: Color.fromRGBO(
                            ac.r.toInt(), ac.g.toInt(), ac.b.toInt(), 0.1),
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
              if (doctor.phone != null) ...[
                const Icon(Icons.phone_rounded, size: 14, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                  doctor.phone!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              const Spacer(),
              if (onEdit != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit'),
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
