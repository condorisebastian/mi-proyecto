import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class ApiService {
  static String? Function()? tokenProvider;

  final String baseUrl = AppConfig.apiUrl;

  Map<String, String> get _headers {
    final token = tokenProvider?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<({bool ok, String message})> registerTrip({
    required int conductorId,
    required String tipoUsuario,
    required int puntos,
    required String metodoPago,
    int? userId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/transactions/pay'),
            headers: _headers,
            body: jsonEncode({
              'conductor_id': conductorId,
              if (userId != null) 'user_id': userId,
              'tipo_usuario': tipoUsuario,
              'puntos': puntos,
              'metodo_pago': metodoPago,
            }),
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        return (ok: true, message: 'Cobro registrado');
      }
      return _errorMessage(response);
    } catch (e) {
      return (ok: false, message: 'Error de conexión con el servidor');
    }
  }

  Future<Map<String, dynamic>> getDailySummary(int conductorId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/transactions/summary/$conductorId'),
            headers: _headers,
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getDailyHistory(int conductorId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/transactions/history/$conductorId'),
            headers: _headers,
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  ({bool ok, String message}) _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as String?;
      if (error != null && error.isNotEmpty) {
        return (ok: false, message: error);
      }
    } catch (e) {
      // Cuerpo no JSON, usar estado
    }
    return (ok: false, message: 'Error del servidor (${response.statusCode})');
  }
}
