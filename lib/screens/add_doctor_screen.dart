import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clinic.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';

/// Form screen to add a new doctor to a clinic.
class AddDoctorScreen extends StatefulWidget {
  final Clinic clinic;

  const AddDoctorScreen({super.key, required this.clinic});

  @override
  State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _specializationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ClinicProvider>();
    final error = await provider.addDoctor(
      name: _nameController.text.trim(),
      specialization: _specializationController.text.trim(),
      clinicId: widget.clinic.id,
    );

    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Doctor added successfully!'),
            ],
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
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
            title: const Text('Add Doctor'),
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x2005A66B),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_add_rounded,
                              size: 36, color: Color(0xFF059669)),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'New Doctor',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Adding to ${widget.clinic.name}',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clinic badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded,
                            size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.clinic.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppTheme.borderLight, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Doctor Name',
                            hintText: 'e.g. Dr. Priya Sharma',
                            prefixIcon:
                                Icon(Icons.person_rounded, size: 20),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _specializationController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Specialization',
                            hintText: 'e.g. Cardiologist, Paediatrician',
                            prefixIcon: Icon(
                                Icons.medical_services_rounded,
                                size: 20),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Specialization is required'
                                  : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Add Doctor'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
