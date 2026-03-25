import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clinic.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/doctor_card.dart';
import 'add_doctor_screen.dart';
import 'availability_screen.dart';
import 'appointment_booking_screen.dart';

/// Screen listing all doctors for a given [clinic].
class DoctorListScreen extends StatefulWidget {
  final Clinic clinic;

  const DoctorListScreen({super.key, required this.clinic});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicProvider>().loadDoctors(widget.clinic.id);
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
            const Text('Doctors',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            Text(
              widget.clinic.name,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Consumer<ClinicProvider>(
        builder: (context, provider, _) {
          if (provider.loadingDoctors) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.doctors.isEmpty) {
            return _EmptyDoctors(
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AddDoctorScreen(clinic: widget.clinic)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: provider.doctors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doctor = provider.doctors[i];
              return DoctorCard(
                doctor: doctor,
                onManageAvailability: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AvailabilityScreen(doctor: doctor)),
                ),
                onBookAppointment: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppointmentBookingScreen(
                      initialClinic: widget.clinic,
                      initialDoctor: doctor,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    AddDoctorScreen(clinic: widget.clinic)),
          );
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Doctor'),
      ),
    );
  }
}

class _EmptyDoctors extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyDoctors({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.people_outline_rounded,
                  size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No doctors yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add doctors to this clinic to start managing appointments',
              style:
                  TextStyle(fontSize: 13, color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Doctor'),
            ),
          ],
        ),
      ),
    );
  }
}
