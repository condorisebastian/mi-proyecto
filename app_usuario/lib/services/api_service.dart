import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/transaction.dart';

class ApiService {
  final String baseUrl = 'http://192.168.100.7:3000/api';

  Future<List<Transaction>> getTransactionHistory(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transactions/user/$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Transaction.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<bool> rechargePoints(int userId, int points, String metodoPago) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transactions/recharge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'puntos': points,
          'metodo_pago': metodoPago,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> payTrip(int userId, int conductorId, int puntos) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transactions/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'conductor_id': conductorId,
          'puntos': puntos,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
