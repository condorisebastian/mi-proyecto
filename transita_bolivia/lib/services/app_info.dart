import 'package:flutter/services.dart';

/// Consulta la versión instalada sin solicitar permisos del dispositivo.
class AppInfo {
  static const channel = MethodChannel('com.transita.bolivia/app_info');

  static Future<Map<String, dynamic>?> version() =>
      channel.invokeMapMethod<String, dynamic>('appVersion');
}
