import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config.dart';
import '../models/user.dart';
import 'firebase_service.dart';

class AuthService extends ChangeNotifier {
  static const _kSessionKey = 'session';
  static const _kSessionTtl = Duration(hours: 8);

  final String baseUrl = AppConfig.apiUrl;
  User? _currentUser;
  bool _isLoading = false;
  String? _token;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get token => _token;

  Future<bool> login(String pin, String tipo, {String ci = ''}) async {
    _isLoading = true;
    notifyListeners();

    if (AppConfig.useFirebase) {
      final ok = await _loginFirebase(pin, tipo, ci: ci);
      _isLoading = false;
      notifyListeners();
      return ok;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pin': pin,
              'tipo': tipo,
              'ci': ci,
            }),
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        _token = data['token'] as String?;
        await _saveSession();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _loginFirebase(String pin, String tipo, {String ci = ''}) async {
    final user = await FirebaseService.instance
        .loginPasajero(pin, tipo, ci: ci);
    if (user == null) return false;
    if (user.tipo != tipo) return false;
    _currentUser = user;
    _token = 'firebase';
    await _saveSession();
    return true;
  }

  Future<bool> register({
    required String nombre,
    required String apellido,
    required String ci,
    required String pin,
    required String tipo,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (AppConfig.useFirebase) {
      final user = await FirebaseService.instance.registerPasajero(
        nombre: nombre,
        apellido: apellido,
        ci: ci,
        pin: pin,
        tipo: tipo,
      );
      if (user != null) {
        _currentUser = user;
        _token = 'firebase';
        await _saveSession();
      }
      _isLoading = false;
      notifyListeners();
      return user != null;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nombre': nombre,
              'apellido': apellido,
              'ci': ci,
              'pin': pin,
              'tipo': tipo,
            }),
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        _token = data['token'] as String?;
        await _saveSession();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
      _currentUser = User.fromJson(data['user']);

      if (AppConfig.useFirebase) {
        final user = await FirebaseService.instance
            .fetchUserById(_currentUser!.id);
        if (user != null) _currentUser = user;
        _token = 'firebase';
      } else {
        _token = data['token'] as String?;
      }
      notifyListeners();
    } catch (e) {
      await _clearSession();
    }
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kSessionKey,
        jsonEncode({
          'user': _currentUser!.toJson(),
          'token': _token,
          'expiresAt': DateTime.now()
              .add(_kSessionTtl)
              .millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      // El error de persistencia no debe impedir el login
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
    } catch (e) {
      // Ignorar
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    await _clearSession();
    if (AppConfig.useFirebase) {
      await FirebaseService.instance.logout();
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_currentUser == null) return;

    if (AppConfig.useFirebase) {
      final user = await FirebaseService.instance
          .fetchUserById(_currentUser!.id);
      if (user != null) {
        _currentUser = user;
        _token = 'firebase';
        notifyListeners();
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/${_currentUser!.id}'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      // Error handling
    }
  }
}
