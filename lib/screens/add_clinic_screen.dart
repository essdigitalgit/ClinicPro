import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';

/// Form screen to create a new clinic.
class AddClinicScreen extends StatefulWidget {
  const AddClinicScreen({super.key});

  @override
  State<AddClinicScreen> createState() => _AddClinicScreenState();
}

class _AddClinicScreenState extends State<AddClinicScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ClinicProvider>();
    final error = await provider.addClinic(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Clinic added successfully!'),
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
            title: const Text('Add Clinic'),
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
                            gradient: AppTheme.headerGradient,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x300077B6),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                              Icons.local_hospital_rounded,
                              size: 36,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'New Clinic',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter the clinic details below',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: AppTheme.borderLight, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Clinic Name',
                            hintText: 'e.g. Apollo Clinic, Delhi',
                            prefixIcon: Icon(
                                Icons.local_hospital_rounded,
                                size: 20),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Clinic name is required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            hintText: 'Street, Area, City – PIN',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 26),
                              child: Icon(Icons.location_on_rounded, size: 20),
                            ),
                            alignLabelWithHint: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Address is required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+91 XXXXX XXXXX',
                            prefixIcon:
                                Icon(Icons.phone_rounded, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Phone is required';
                            }
                            if (!RegExp(r'^[+\d\s\-()]{7,}$')
                                .hasMatch(v.trim())) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('Create Clinic'),
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
