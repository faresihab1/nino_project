class Pediatrician {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final double latitude;
  final double longitude;

  const Pediatrician({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.latitude,
    required this.longitude,
  });
}
