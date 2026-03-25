/// Represents a clinic entity.
class Clinic {
  final String id;
  final String name;
  final String address;
  final String phone;

  Clinic({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
  });

  @override
  String toString() => name;
}
