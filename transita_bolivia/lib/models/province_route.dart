class ProvinceRoute {
  const ProvinceRoute({
    required this.id,
    required this.destination,
    required this.province,
    required this.fareCents,
  });

  final String id;
  final String destination;
  final String province;
  final int? fareCents;
  bool get canCharge => fareCents != null;
  String get qrType => 'provincia_$id';
}
