import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl = 'http://192.168.100.7:3000/api';

  Future<bool> registerTrip(int conductorId, String tipoUsuario, int puntos) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transactions/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'conductor_id': conductorId,
          'tipo_usuario': tipoUsuario,
          'puntos': puntos,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getDailySummary(int conductorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transactions/summary/$conductorId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {};
      }
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getDailyHistory(int conductorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transactions/history/$conductorId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
