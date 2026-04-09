/// An independently onboarded doctor — not linked to any clinic at creation.
class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String? phone;
  final String? email;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    this.phone,
    this.email,
  });

  @override
  String toString() => '$name ($specialization)';
}
