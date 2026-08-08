import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../models/transaction.dart';

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

  Future<List<Transaction>> getTransactionHistory(int userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/transactions/user/$userId'),
            headers: _headers,
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((json) => Transaction.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<({bool ok, String message})> rechargePoints(
      int userId, int points, String metodoPago) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/transactions/recharge'),
            headers: _headers,
            body: jsonEncode({
              'user_id': userId,
              'puntos': points,
              'metodo_pago': metodoPago,
            }),
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        return (ok: true, message: 'Recarga exitosa');
      }
      return _errorMessage(response);
    } catch (e) {
      return (ok: false, message: 'Error de conexión con el servidor');
    }
  }

  Future<({bool ok, String message})> payTrip(
      int userId, int conductorId, int puntos, String metodoPago) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/transactions/pay'),
            headers: _headers,
            body: jsonEncode({
              'user_id': userId,
              'conductor_id': conductorId,
              'puntos': puntos,
              'metodo_pago': metodoPago,
            }),
          )
          .timeout(AppConfig.timeout);

      if (response.statusCode == 200) {
        return (ok: true, message: 'Viaje pagado');
      }
      return _errorMessage(response);
    } catch (e) {
      return (ok: false, message: 'Error de conexión con el servidor');
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
