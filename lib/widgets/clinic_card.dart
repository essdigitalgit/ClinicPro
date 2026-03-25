import 'package:flutter/material.dart';
import '../models/clinic.dart';
import '../theme/app_theme.dart';

/// Premium card widget displaying [Clinic] info.
class ClinicCard extends StatelessWidget {
  final Clinic clinic;
  final VoidCallback onTap;

  const ClinicCard({super.key, required this.clinic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.softGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: AppTheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: AppTheme.textTertiary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          clinic.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textTertiary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded,
                          size: 13, color: AppTheme.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        clinic.phone,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
