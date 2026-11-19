import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/money.dart';

/// Controles adicionales de este dispositivo y cuenta, no límites del servidor.
class PaymentPreferences {
  PaymentPreferences(this.userId);
  final int userId;
  int? limitCents;
  bool biometricEnabled = false;
  String get _prefix =>
      'payments.${AppConfig.useFirebase ? 'firebase' : 'api'}.$userId';

  Future<void> load() async {
    final storage = await SharedPreferences.getInstance();
    limitCents = storage.getInt('$_prefix.limit_cents');
    if (limitCents != null && limitCents! <= 0) {
      throw StateError('Límite inválido');
    }
    biometricEnabled = storage.getBool('$_prefix.biometric') ?? false;
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

  Future<void> setBiometric(bool value) async {
    final storage = await SharedPreferences.getInstance();
    if (!await storage.setBool('$_prefix.biometric', value)) {
      throw StateError('No se pudo guardar la preferencia.');
    }
    biometricEnabled = value;
  }
}

class PaymentBiometrics {
  static const channel = MethodChannel('com.transita.bolivia/device_security');

  Future<bool> available() async {
    try {
      return await channel.invokeMethod<bool>('biometricAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirm() async {
    try {
      return await channel.invokeMethod<bool>('authenticate') ?? false;
    } catch (_) {
      return false;
    }
  }
}

class PaymentAuthorization {
  PaymentAuthorization(this.preferences, {PaymentBiometrics? biometrics})
    : biometrics = biometrics ?? PaymentBiometrics();
  final PaymentPreferences preferences;
  final PaymentBiometrics biometrics;

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
      if (preferences.biometricEnabled && !await biometrics.confirm()) {
        return (
          ok: false,
          message: 'No se confirmó tu identidad. No se realizó el pago.',
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
