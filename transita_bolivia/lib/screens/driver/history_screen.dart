import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme.dart';
import 'package:provider/provider.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_api_service.dart';
import '../../services/firebase_service.dart';
import '../../config.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => DriverHistoryScreenState();
}

class DriverHistoryScreenState extends State<DriverHistoryScreen> {
  final DriverApiService _apiService = DriverApiService();
  List<Map<String, dynamic>> _history = [];
  StreamSubscription<List<Map<String, dynamic>>>? _liveSub;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (AppConfig.useFirebase && authService.currentConductor != null) {
      _liveSub = FirebaseService.instance
          .dailyHistoryStream(authService.currentConductor!.id)
          .listen((history) {
        if (mounted) {
          setState(() {
            _history = history;
          });
        }
      }, onError: (_) {});
    } else {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> reload() => _loadHistory();

  Future<void> _loadHistory() async {
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (authService.currentConductor != null) {
      final history = await _apiService.getDailyHistory(
        authService.currentConductor!.id,
      );
      setState(() {
        _history = history;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial del Día'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.background,
            ],
            stops: [0.0, 0.2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadHistory,
                  child: _history.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: constraints.maxHeight,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 80,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No hay cobros hoy',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            return _buildHistoryItem(item);
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final DateTime fecha = DateTime.parse(item['fecha']);
    final int puntos = item['puntos'];
    final String metodo = _metodoLabel(item['metodo_pago']);
    final String tipoUsuario = _tipoLabel(item['tipo_usuario']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_bus,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$metodo · $tipoUsuario',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-$puntos pts',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _metodoLabel(dynamic metodo) {
    switch (metodo) {
      case 'tarjeta_nfc':
        return 'NFC';
      case 'qr':
        return 'QR';
      default:
        return 'Efectivo';
    }
  }

  String _tipoLabel(dynamic tipo) {
    switch (tipo) {
      case 'estudiante':
        return 'Estudiante';
      case 'civil':
        return 'Civil';
      case 'adulto_mayor':
        return 'Adulto Mayor';
      case 'discapacitado':
        return 'Discapacitado';
      default:
        return 'Pasajero';
    }
  }
}
