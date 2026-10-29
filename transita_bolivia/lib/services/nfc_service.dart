import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lee una prueba criptográfica de tarjeta. El servidor autoriza el descuento.
class NfcService {
  static const _channel = MethodChannel('com.transita.bolivia/nfc');
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<String> status() async {
    if (!_supported) return 'unavailable';
    try {
      return await _channel.invokeMethod<String>('status') ?? 'unavailable';
    } on MissingPluginException {
      return 'unavailable';
    }
  }

  Future<String> readCard() async =>
      await _channel.invokeMethod<String>('read') ?? '';

  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      /* Plataforma sin lector. */
    }
  }
}
