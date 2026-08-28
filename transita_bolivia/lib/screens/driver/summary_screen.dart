import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_api_service.dart';

class DriverSummaryScreen extends StatefulWidget {
  const DriverSummaryScreen({super.key});

  @override
  State<DriverSummaryScreen> createState() => DriverSummaryScreenState();
}

class DriverSummaryScreenState extends State<DriverSummaryScreen> {
  final DriverApiService _apiService = DriverApiService();
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> reload() => _loadSummary();

  Future<void> _loadSummary() async {
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (authService.currentConductor != null) {
      final summary = await _apiService.getDailySummary(
        authService.currentConductor!.id,
      );
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
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE53935),
              Color(0xFFF5F5F5),
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFFE53935),
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
                                Color(0xFFE53935),
                                Color(0xFFC62828),
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
                                '${_summary['total_puntos'] ?? 0} PUNTOS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '= Bs ${_summary['total_puntos'] ?? 0}.00',
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
                              foregroundColor: const Color(0xFFE53935),
                              side: const BorderSide(
                                color: Color(0xFFE53935),
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
          Icon(icon, color: const Color(0xFFE53935), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }

  void _shareSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de compartir en desarrollo'),
        backgroundColor: Color(0xFFE53935),
      ),
    );
  }
}
