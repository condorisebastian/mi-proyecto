class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1/transporte_api',
  );

  static const Duration timeout = Duration(seconds: 20);
}
