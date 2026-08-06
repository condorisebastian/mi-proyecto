import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config.dart';
import '../models/conductor.dart';

class AuthService extends ChangeNotifier {
  static const _kSessionKey = 'session';

  final String baseUrl = AppConfig.apiUrl;
  Conductor? _currentConductor;
  bool _isLoading = false;
  String? _token;

  Conductor? get currentConductor => _currentConductor;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentConductor != null;
  String? get token => _token;

  Future<bool> login(String licencia, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login-conductor'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'licencia': licencia,
              'password': password,
            }),
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentConductor = Conductor.fromJson(data['conductor']);
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
      _currentConductor = Conductor.fromJson(data['conductor']);
      _token = data['token'] as String?;
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
          'conductor': _currentConductor!.toJson(),
          'token': _token,
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
    _currentConductor = null;
    _token = null;
    await _clearSession();
    notifyListeners();
  }
}
