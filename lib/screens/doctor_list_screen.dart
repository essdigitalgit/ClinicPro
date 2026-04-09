import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/doctor_card.dart';
import 'add_doctor_screen.dart';

/// Standalone screen listing all doctors across the organisation.
class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicProvider>().loadDoctors();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        automaticallyImplyLeading: false,
        title: const Text(
          'Doctors',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Consumer<ClinicProvider>(
        builder: (context, provider, _) {
          if (provider.loadingDoctors) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.doctors.isEmpty) {
            return _EmptyDoctors(
              onAdd: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
                );
                if (context.mounted) {
                  context.read<ClinicProvider>().loadDoctors();
                }
              },
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: provider.doctors.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              return DoctorCard(doctor: provider.doctors[i]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDoctorScreen()),
          );
          if (context.mounted) {
            context.read<ClinicProvider>().loadDoctors();
          }
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
              'Add doctors to start assigning them to clinic slots',
              style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
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

