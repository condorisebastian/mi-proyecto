const suggestedCities = [
  'Santa Cruz de la Sierra',
  'La Paz',
  'Cochabamba',
  'El Alto',
  'Sucre',
  'Oruro',
  'Potosí',
  'Tarija',
  'Trinidad',
  'Cobija',
];

String? normalizeCity(String value) {
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) return null;
  final city = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return city.length >= 2 && city.length <= 60 ? city : null;
}
