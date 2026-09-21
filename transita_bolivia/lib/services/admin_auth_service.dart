import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config.dart';
import '../models/user.dart';
import 'firebase_service.dart';

/// Sesión del administrador (PIN 0000) para el panel de registros en vivo.
class AdminAuthService extends ChangeNotifier {
  static const _kSessionKey = 'admin_session';
  static const _kSessionTtl = Duration(hours: 8);

  User? _current;
  bool _isLoading = false;

  User? get currentAdmin => _current;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _current != null;

  Future<bool> login(String pin) async {
    _isLoading = true;
    notifyListeners();

    if (!AppConfig.useFirebase) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final user = await FirebaseService.instance.loginAdmin(pin);
    if (user != null) {
      _current = user;
      await _saveSession();
    }
    _isLoading = false;
    notifyListeners();
    return _current != null;
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSessionKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt =
          (data['expiresAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
      if (expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        await _clearSession();
        return;
      }
      _current = User.fromJson(data['user']);
      notifyListeners();
    } catch (_) {
      await _clearSession();
    }
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kSessionKey,
        jsonEncode({
          'user': _current!.toJson(),
          'expiresAt':
              DateTime.now().add(_kSessionTtl).millisecondsSinceEpoch,
        }),
      );
    } catch (_) {
      // La persistencia no debe impedir el acceso.
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
    } catch (_) {
      // Ignorar.
    }
  }

  Future<void> logout() async {
    _current = null;
    await _clearSession();
    notifyListeners();
  }
}