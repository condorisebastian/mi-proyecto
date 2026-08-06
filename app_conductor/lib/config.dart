class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.100.7:3000/api',
  );

  static const Duration timeout = Duration(seconds: 20);
}
