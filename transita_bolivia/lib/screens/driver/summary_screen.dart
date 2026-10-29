import '../../models/money.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import '../../theme.dart';
import 'package:provider/provider.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_api_service.dart';
import '../../services/firebase_service.dart';
import '../../config.dart';

class DriverSummaryScreen extends StatefulWidget {
  const DriverSummaryScreen({super.key});

  @override
  State<DriverSummaryScreen> createState() => DriverSummaryScreenState();
}

class DriverSummaryScreenState extends State<DriverSummaryScreen> {
  final DriverApiService _apiService = DriverApiService();
  Map<String, dynamic> _summary = {};
  StreamSubscription<Map<String, dynamic>>? _liveSub;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (AppConfig.useFirebase && authService.currentConductor != null) {
      _liveSub = FirebaseService.instance
          .dailySummaryStream(authService.currentConductor!.id)
          .listen((summary) {
            if (mounted) {
              setState(() {
                _summary = summary;
              });
            }
          }, onError: (_) {});
    } else {
      _loadSummary();
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> reload() => _loadSummary();

  Future<void> _loadSummary() async {
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (authService.currentConductor != null) {
      final summary = await _apiService.getDailySummary(
        authService.currentConductor!.id,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<DriverAuthService>(context);
    final conductor = authService.currentConductor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen del Día'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.background],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadSummary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'RESUMEN DIARIO',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${conductor?.nombre ?? ''} ${conductor?.apellido ?? ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Placa: ${conductor?.licencia ?? ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'COBRADO HOY',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${Money.format(_summary['total_puntos'] ?? 0)} PUNTOS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '= Bs ${Money.format(_summary['total_puntos'] ?? 0)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildStatRow(
                          'Total pasajeros',
                          '${_summary['total_pasajeros'] ?? 0}',
                          Icons.people,
                        ),
                        const Divider(),
                        _buildStatRow(
                          'Estudiantes',
                          '${_summary['estudiantes'] ?? 0}',
                          Icons.school,
                        ),
                        const Divider(),
                        _buildStatRow(
                          'Civiles',
                          '${_summary['civiles'] ?? 0}',
                          Icons.person,
                        ),
                        const Divider(),
                        _buildStatRow(
                          'Adultos Mayores',
                          '${_summary['mayores'] ?? 0}',
                          Icons.elderly,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _shareSummary();
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('COMPARTIR RESUMEN'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSummary() async {
    final conductor = context.read<DriverAuthService>().currentConductor;
    final now = DateTime.now();
    try {
      await Share.share(
        'Transita Bolivia — Resumen del ${now.day}/${now.month}/${now.year}\n'
        'Conductor: ${conductor?.nombre ?? ''} ${conductor?.apellido ?? ''}\n'
        'Viajes: ${_summary['total_pasajeros'] ?? 0}\n'
        'Recaudación: ${Money.format(_summary['total_puntos'] ?? 0)} puntos\n'
        'Estudiantes: ${_summary['estudiantes'] ?? 0}\n'
        'Civiles: ${_summary['civiles'] ?? 0}\n'
        'Adultos mayores: ${_summary['mayores'] ?? 0}\n'
        'Personas con discapacidad: ${_summary['discapacitados'] ?? 0}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el resumen.')),
      );
    }
  }
}
