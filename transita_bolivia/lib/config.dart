class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.103.177/transporte_api',
  );

  static const Duration timeout = Duration(seconds: 20);

  /// Firestore permite sincronizar los dos teléfonos en tiempo real.
  /// El backend PHP se puede seleccionar con `--dart-define=USE_FIREBASE=false`.
  static const bool useFirebase = bool.fromEnvironment(
    'USE_FIREBASE',
    defaultValue: true,
  );
}
