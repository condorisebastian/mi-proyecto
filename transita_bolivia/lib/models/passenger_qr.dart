import 'dart:math';

/// Protocolo de IDENTIFICACIÓN de prueba para el lector ESP32-CAM.
/// No es una firma ni una autorización de cobro; no sustituye la sesión.
class PassengerQr {
  const PassengerQr({
    required this.userId,
    required this.backend,
    required this.expiresAt,
    required this.nonce,
  });
  static const lifetime = Duration(seconds: 15);
  final int userId;
  final String backend;
  final DateTime expiresAt;
  final String nonce;

  factory PassengerQr.create(
    int userId, {
    required String backend,
    DateTime? now,
  }) {
    if (userId <= 0 || !['F', 'P'].contains(backend)) {
      throw ArgumentError('Cuenta inválida');
    }
    final random = Random.secure();
    final nonce = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final expiry = (now ?? DateTime.now()).toUtc().add(lifetime);
    return PassengerQr(
      userId: userId,
      backend: backend,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiry.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      ),
      nonce: nonce,
    );
  }

  String encode() =>
      'MP-ID1:D:$backend:$userId:'
      '${expiresAt.millisecondsSinceEpoch ~/ 1000}:$nonce';

  static PassengerQr? tryParse(String raw, {DateTime? now}) {
    final parts = raw.split(':');
    if (parts.length != 6 ||
        parts[0] != 'MP-ID1' ||
        parts[1] != 'D' ||
        !['F', 'P'].contains(parts[2]) ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(parts[5])) {
      return null;
    }
    final id = int.tryParse(parts[3]);
    final timestamp = int.tryParse(parts[4]);
    if (id == null ||
        id <= 0 ||
        timestamp == null ||
        timestamp < 1 ||
        timestamp > 4102444800) {
      return null;
    }
    final expires = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    );
    final current = (now ?? DateTime.now()).toUtc();
    if (!expires.isAfter(current) || expires.difference(current) > lifetime) {
      return null;
    }
    return PassengerQr(
      userId: id,
      backend: parts[2],
      expiresAt: expires,
      nonce: parts[5],
    );
  }
}
