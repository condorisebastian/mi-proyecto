class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.103.177/transporte_api',
  );

  static const Duration timeout = Duration(seconds: 20);

  /// Modo híbrido: si es `true`, los servicios usan Firebase
  /// (Auth + Firestore) en lugar del backend PHP. Por defecto `false`
  /// para no romper el flujo actual; se activa con
  /// `--dart-define=USE_FIREBASE=true`.
  static const bool useFirebase = bool.fromEnvironment(
    'USE_FIREBASE',
    defaultValue: false,
  );
}
