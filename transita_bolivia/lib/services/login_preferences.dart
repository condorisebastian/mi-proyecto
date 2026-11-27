import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda únicamente el carnet; el PIN siempre lo introduce el usuario.
abstract final class LoginPreferences {
  static String defaultCi(String profile) => switch (profile) {
    'estudiante' => '1234567',
    'civil' => '7654321',
    'adulto_mayor' => '1122334',
    'conductor' => '9876543',
    _ => '',
  };

  static Future<String> readCi(String profile) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('last_login_ci_$profile') ??
        defaultCi(profile);
  }

  static Future<void> saveCi(String profile, String ci) async {
    if (ci.trim().isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('last_login_ci_$profile', ci.trim());
  }
}
