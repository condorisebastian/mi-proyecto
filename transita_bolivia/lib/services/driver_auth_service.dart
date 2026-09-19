import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config.dart';
import '../models/conductor.dart';
import 'firebase_service.dart';

class DriverAuthService extends ChangeNotifier {
  static const _kSessionKey = 'driver_session';

  final String baseUrl = AppConfig.apiUrl;
  Conductor? _currentConductor;
  bool _isLoading = false;
  String? _token;

  Conductor? get currentConductor => _currentConductor;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentConductor != null;
  String? get token => _token;

  Future<bool> login(String pin) async {
    _isLoading = true;
    notifyListeners();

    if (AppConfig.useFirebase) {
      final conductor = await FirebaseService.instance.loginConductor(pin);
      if (conductor != null) {
        _currentConductor = conductor;
        _token = 'firebase';
        await _saveSession();
      }
      _isLoading = false;
      notifyListeners();
      return conductor != null;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login-conductor'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pin': pin,
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

  Future<bool> register({
    required String nombre,
    required String apellido,
    required String ci,
    required String pin,
    String? licencia,
    String? telefono,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (AppConfig.useFirebase) {
      final conductor = await FirebaseService.instance.registerConductor(
        nombre: nombre,
        apellido: apellido,
        ci: ci,
        pin: pin,
        licencia: licencia,
        telefono: telefono,
      );
      if (conductor != null) {
        _currentConductor = conductor;
        _token = 'firebase';
        await _saveSession();
      }
      _isLoading = false;
      notifyListeners();
      return conductor != null;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register-conductor'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nombre': nombre,
              'apellido': apellido,
              'ci': ci,
              'pin': pin,
              'licencia': licencia,
              'telefono': telefono,
            }),
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 201) {
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
      if (AppConfig.useFirebase) {
        // Firebase mantiene la sesión; cargamos desde Firestore si hay
        // sesión activa del conductor.
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_kSessionKey);
        if (raw != null) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          _currentConductor = Conductor.fromJson(data['conductor']);
          _token = 'firebase';
          notifyListeners();
        }
        return;
      }

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
    if (AppConfig.useFirebase) {
      await FirebaseService.instance.logout();
    }
    notifyListeners();
  }
}
