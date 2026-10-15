import 'dart:math';

/// El QR identifica un cobro, sin contener el PIN ni el saldo del pasajero.
class TripQr {
  const TripQr({
    required this.conductorId,
    required this.tipo,
    required this.puntos,
    required this.reference,
    this.cantidad = 1,
  });

  static const fares = {
    'estudiante': 1,
    'civil': 3,
    'adulto_mayor': 1,
    'discapacitado': 1,
  };

  final int conductorId;
  final String tipo;
  final int puntos;
  final String reference;
  final int cantidad;
  static const maxPassengers = 50;

  static String newReference() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join()}';
  }

  String encode() =>
      'CONDUCTOR:$conductorId:$tipo:$puntos:$reference:$cantidad';

  static TripQr? tryParse(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 4 || parts.length > 6 || parts[0] != 'CONDUCTOR') {
      return null;
    }
    final id = int.tryParse(parts[1]);
    final puntos = int.tryParse(parts[3]);
    final cantidad = parts.length == 6 ? int.tryParse(parts[5]) : 1;
    if (id == null ||
        id <= 0 ||
        puntos == null ||
        puntos <= 0 ||
        !fares.containsKey(parts[2]) ||
        cantidad == null ||
        cantidad < 1 ||
        cantidad > maxPassengers ||
        (fares[parts[2]] ?? 0) * cantidad != puntos) {
      return null;
    }
    final reference = parts.length >= 5 ? parts[4] : newReference();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(reference)) return null;
    return TripQr(
      conductorId: id,
      tipo: parts[2],
      puntos: puntos,
      reference: reference,
      cantidad: cantidad,
    );
  }
}
