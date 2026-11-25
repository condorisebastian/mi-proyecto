import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/money.dart';

/// Controles adicionales de este dispositivo y cuenta, no límites del servidor.
class PaymentPreferences {
  PaymentPreferences(this.userId);
  final int userId;
  int? limitCents;
  String get _prefix =>
      'payments.${AppConfig.useFirebase ? 'firebase' : 'api'}.$userId';

  Future<void> load() async {
    final storage = await SharedPreferences.getInstance();
    limitCents = storage.getInt('$_prefix.limit_cents');
    if (limitCents != null && limitCents! <= 0) {
      throw StateError('Límite inválido');
    }
    // Retira la preferencia obsoleta sin cambiar los límites guardados.
    if (storage.containsKey('$_prefix.biometric')) {
      await storage.remove('$_prefix.biometric');
    }
  }

  Future<void> setLimit(num? amount) async {
    if (amount != null && (!Money.valid(amount) || amount <= 0)) {
      throw ArgumentError('Introduce un monto mayor a cero con dos decimales.');
    }
    final storage = await SharedPreferences.getInstance();
    final cents = amount == null ? null : (amount * 100).round();
    final saved = cents == null
        ? await storage.remove('$_prefix.limit_cents')
        : await storage.setInt('$_prefix.limit_cents', cents);
    if (!saved) throw StateError('No se pudo guardar el límite.');
    limitCents = cents;
  }
}

class PaymentAuthorization {
  PaymentAuthorization(this.preferences);
  final PaymentPreferences preferences;

  Future<({bool ok, String message})> authorize(num amount) async {
    if (!Money.valid(amount) || amount <= 0) {
      return (ok: false, message: 'El monto de pago no es válido.');
    }
    try {
      await preferences.load();
      final limit = preferences.limitCents;
      if (limit != null && (amount * 100).round() > limit) {
        return (
          ok: false,
          message:
              'Este pago supera tu límite de Bs ${Money.format(limit / 100)}. '
              'Puedes revisarlo en Perfil → Establecer montos límites.',
        );
      }
      return (ok: true, message: 'Autorizado');
    } catch (_) {
      return (
        ok: false,
        message:
            'No se pudo comprobar tu configuración de pago. Inténtalo nuevamente.',
      );
    }
  }
}
