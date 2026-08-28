import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_api_service.dart';
import 'charge_screen.dart';
import 'history_screen.dart';
import 'summary_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  bool _isCharging = false;
  final DriverApiService _apiService = DriverApiService();
  Map<String, dynamic> _dailySummary = {};

  final GlobalKey<DriverHistoryScreenState> _historyKey =
      GlobalKey<DriverHistoryScreenState>();
  final GlobalKey<DriverSummaryScreenState> _summaryKey =
      GlobalKey<DriverSummaryScreenState>();

  @override
  void initState() {
    super.initState();
    _loadDailySummary();
  }

  Future<void> _loadDailySummary() async {
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (authService.currentConductor != null) {
      final summary = await _apiService.getDailySummary(
        authService.currentConductor!.id,
      );
      setState(() {
        _dailySummary = summary;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<DriverAuthService>(context);
    final conductor = authService.currentConductor;

    if (conductor == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(conductor, authService),
          const DriverChargeScreen(),
          DriverHistoryScreen(key: _historyKey),
          DriverSummaryScreen(key: _summaryKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            _loadDailySummary();
          } else if (index == 2) {
            _historyKey.currentState?.reload();
          } else if (index == 3) {
            _summaryKey.currentState?.reload();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE53935),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Cobrar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Resumen',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(dynamic conductor, DriverAuthService authService) {
    return Container(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${conductor.nombre}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Licencia: ${conductor.licencia}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () {
                      _confirmLogout(context, authService);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isCharging
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _isCharging ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCharging ? 'COBRANDO ✅' : 'DETENIDO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isCharging ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'COBROS HOY',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_dailySummary['total_puntos'] ?? 0} PUNTOS',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE53935),
                      ),
                    ),
                    Text(
                      '= Bs ${_dailySummary['total_puntos'] ?? 0}.00',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          '${_dailySummary['total_pasajeros'] ?? 0}',
                          'Pasajeros',
                          Icons.people,
                        ),
                        _buildStatItem(
                          '${_dailySummary['estudiantes'] ?? 0}',
                          'Estudiantes',
                          Icons.school,
                        ),
                        _buildStatItem(
                          '${_dailySummary['civiles'] ?? 0}',
                          'Civiles',
                          Icons.person,
                        ),
                        _buildStatItem(
                          '${_dailySummary['mayores'] ?? 0}',
                          'Mayores',
                          Icons.elderly,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    _showQRCode(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'MOSTRAR QR PARA COBRAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isCharging = !_isCharging;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isCharging ? Colors.red : Colors.green,
                    side: BorderSide(
                      color: _isCharging ? Colors.red : Colors.green,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isCharging ? 'DETENER COBRO' : 'INICIAR COBRO',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFE53935), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(
      BuildContext context, DriverAuthService authService) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('SALIR'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await authService.logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  void _showQRCode(BuildContext context) {
    final conductor =
        Provider.of<DriverAuthService>(context, listen: false).currentConductor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Código QR para cobro',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: QrImageView(
                    data: 'CONDUCTOR:${conductor?.id}:${conductor?.licencia}',
                    version: QrVersions.auto,
                    size: 250,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Escanea este código para pagar',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Conductor: ${conductor?.nombre} ${conductor?.apellido}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CERRAR'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
