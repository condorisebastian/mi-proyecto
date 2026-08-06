import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/conductor.dart';

class AuthService extends ChangeNotifier {
  final String baseUrl = 'http://192.168.100.7:3000/api';
  Conductor? _currentConductor;
  bool _isLoading = false;

  Conductor? get currentConductor => _currentConductor;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentConductor != null;

  Future<bool> login(String licencia, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login-conductor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'licencia': licencia,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentConductor = Conductor.fromJson(data['conductor']);
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

  void logout() {
    _currentConductor = null;
    notifyListeners();
  }
}
