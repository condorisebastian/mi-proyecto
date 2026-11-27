import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PaymentAlertService {
  static const _channel = MethodChannel('com.transita.bolivia/payment_alert');

  /// SystemSoundType.alert no reproduce sonido en Android. El canal nativo
  /// emite dos tonos cortos con el volumen multimedia del dispositivo.
  static Future<void> play() async {
    await HapticFeedback.heavyImpact();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('paymentReceived');
    } on PlatformException catch (error) {
      debugPrint('No se pudo reproducir el aviso: ${error.code}');
    } on MissingPluginException {
      // Permite usar la misma interfaz en pruebas y otras plataformas.
    }
  }
}
