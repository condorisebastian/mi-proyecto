import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/passenger_qr.dart';

class PassengerQrWindow {
  const PassengerQrWindow({required this.nextGenerationAt, this.qr});
  final DateTime nextGenerationAt;
  final PassengerQr? qr;

  int remaining(DateTime now) =>
      ((nextGenerationAt.difference(now).inMilliseconds + 999) ~/ 1000).clamp(
        0,
        PassengerQr.lifetime.inSeconds,
      );
}

/// Una sola generación por cuenta/backend en cada ventana de 15 segundos.
/// Es un control del prototipo local, no una autorización financiera.
class PassengerQrWindowStore {
  PassengerQrWindowStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  static final instance = PassengerQrWindowStore();
  final DateTime Function() _clock;
  final Map<int, Future<PassengerQrWindow>> _pending = {};
  DateTime get now => _clock().toUtc();
  String get _backend => AppConfig.useFirebase ? 'F' : 'P';
  String _key(int userId) => 'passenger_qr.window.$_backend.$userId';

  PassengerQrWindow _read(SharedPreferences prefs, int userId) {
    try {
      final raw = prefs.getString(_key(userId));
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final deadline = DateTime.fromMillisecondsSinceEpoch(
          data['next'] as int,
          isUtc: true,
        );
        if (deadline.isAfter(now) &&
            deadline.difference(now) <= PassengerQr.lifetime) {
          final payload = data['payload'];
          final qr = payload is String
              ? PassengerQr.tryParse(payload, now: now)
              : null;
          return PassengerQrWindow(
            nextGenerationAt: deadline,
            qr: qr?.userId == userId && qr?.backend == _backend ? qr : null,
          );
        }
      }
    } catch (_) {
      /* Un registro inválido no recupera códigos ajenos. */
    }
    return PassengerQrWindow(nextGenerationAt: now);
  }

  Future<PassengerQrWindow> issue(int userId) {
    if (userId <= 0) throw ArgumentError('Cuenta inválida');
    return _pending[userId] ??= _issue(userId).whenComplete(() {
      _pending.remove(userId);
    });
  }

  Future<PassengerQrWindow> _issue(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _read(prefs, userId);
    if (current.nextGenerationAt.isAfter(now)) return current;
    final issuedAt = now;
    final qr = PassengerQr.create(userId, backend: _backend, now: issuedAt);
    final deadline = issuedAt.add(PassengerQr.lifetime);
    if (!await prefs.setString(
      _key(userId),
      jsonEncode({
        'next': deadline.millisecondsSinceEpoch,
        'payload': qr.encode(),
      }),
    )) {
      throw StateError('No se pudo preparar el QR.');
    }
    return PassengerQrWindow(nextGenerationAt: deadline, qr: qr);
  }

  Future<void> hide(int userId) async {
    try {
      await _pending[userId];
      final prefs = await SharedPreferences.getInstance();
      final current = _read(prefs, userId);
      if (current.nextGenerationAt.isAfter(now)) {
        await prefs.setString(
          _key(userId),
          jsonEncode({'next': current.nextGenerationAt.millisecondsSinceEpoch}),
        );
      }
    } catch (_) {
      /* La pantalla se oculta aunque falle el almacenamiento. */
    }
  }
}
