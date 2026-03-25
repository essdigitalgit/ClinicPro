/// Represents a doctor linked to a specific clinic.
class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String clinicId;

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.clinicId,
  });

  @override
  String toString() => '$name ($specialization)';
}
