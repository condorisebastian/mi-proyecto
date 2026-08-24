class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.103.177/transporte_api',
  );

  static const Duration timeout = Duration(seconds: 20);
}
