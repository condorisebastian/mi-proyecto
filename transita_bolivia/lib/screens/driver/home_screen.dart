import '../../models/money.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme.dart';
import 'package:provider/provider.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_api_service.dart';
import '../../services/firebase_service.dart';
import '../../services/payment_alert_service.dart';
import '../../models/driver_payment.dart';
import '../../config.dart';
import 'charge_screen.dart';
import 'summary_screen.dart';
import '../soporte/support_screen.dart';
import '../../models/financial_chat.dart';
import '../chat/financial_chat_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final bool _isCharging = true;
  final DriverApiService _apiService = DriverApiService();
  Map<String, dynamic> _dailySummary = {};
  StreamSubscription<Map<String, dynamic>>? _summarySub;
  StreamSubscription<({List<DriverPayment> payments, bool fromCache})>?
  _paymentsSub;
  final _paymentTracker = DriverPaymentTracker();
  OverlayEntry? _paymentNotice;
  Timer? _noticeTimer;

  late final AnimationController _chargePulse;

  final GlobalKey<DriverSummaryScreenState> _summaryKey =
      GlobalKey<DriverSummaryScreenState>();

  @override
  void initState() {
    super.initState();
    _chargePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _chargePulse.repeat(reverse: true);
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (AppConfig.useFirebase && authService.currentConductor != null) {
      _summarySub = FirebaseService.instance
          .dailySummaryStream(authService.currentConductor!.id)
          .listen((summary) {
            if (!mounted) return;
            setState(() {
              _dailySummary = summary;
            });
          }, onError: (_) {});
      _paymentsSub = FirebaseService.instance
          .confirmedDriverPaymentsStream(authService.currentConductor!.id)
          .listen(
            (batch) {
              if (!mounted) return;
              for (final payment in _paymentTracker.receive(
                batch.payments,
                fromCache: batch.fromCache,
              )) {
                _onPaymentReceived(payment);
              }
            },
            onError: (Object error) {
              debugPrint('No se pudo escuchar los pagos: $error');
            },
          );
    } else {
      _loadDailySummary();
    }
  }

  @override
  void dispose() {
    _chargePulse.dispose();
    _summarySub?.cancel();
    _paymentsSub?.cancel();
    _clearPaymentNotice();
    super.dispose();
  }

  void _clearPaymentNotice() {
    _noticeTimer?.cancel();
    _paymentNotice?.remove();
    _paymentNotice = null;
  }

  void _onPaymentReceived(DriverPayment payment) {
    unawaited(PaymentAlertService.play());
    debugPrint('Pago confirmado: ${payment.documentId}');
    _clearPaymentNotice();
    _paymentNotice = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 12,
        right: 12,
        child: SafeArea(
          child: Material(
            elevation: 12,
            color: Colors.green.shade800,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _clearPaymentNotice,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'PAGO EXITOSO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '+${Money.format(payment.puntos)} punto(s) · ${payment.cantidad} pasaje(s)\n${payment.pasajero.isEmpty ? 'Pasajero' : payment.pasajero}',
                            style: const TextStyle(color: Colors.white),
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
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_paymentNotice!);
    _noticeTimer = Timer(const Duration(seconds: 6), _clearPaymentNotice);
  }

  Future<void> _loadDailySummary() async {
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (authService.currentConductor != null) {
      final summary = await _apiService.getDailySummary(
        authService.currentConductor!.id,
      );
      if (!mounted) return;
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(conductor, authService),
          const DriverChargeScreen(),
          DriverSummaryScreen(key: _summaryKey),
          FinancialChatScreen(
            owner: ChatIdentity(
              canal: 'conductor',
              id: conductor.id,
              nombre: '${conductor.nombre} ${conductor.apellido}',
            ),
          ),
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
            _summaryKey.currentState?.reload();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Cobrar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Resumen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
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
          colors: [AppColors.primary, AppColors.background],
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
                        'ID: #${conductor.id}  ·  Licencia: ${conductor.licencia}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        'CI: ${conductor.ci.isEmpty ? '—' : conductor.ci}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
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
                          AnimatedBuilder(
                            animation: _chargePulse,
                            builder: (context, child) {
                              final t = Curves.easeInOut.transform(
                                _chargePulse.value,
                              );
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_isCharging)
                                    Opacity(
                                      opacity: 0.4 * (1 - t),
                                      child: Transform.scale(
                                        scale: 1 + t,
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _isCharging
                                          ? Colors.green
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCharging ? 'COBRANDO' : 'DETENIDO',
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
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${Money.format(_dailySummary['total_puntos'] ?? 0)} PUNTOS',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '= Bs ${Money.format(_dailySummary['total_puntos'] ?? 0)}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.2,
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
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
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
                        'COBRAR PASAJES',
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
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SupportScreen(
                          canal: 'conductor',
                          id: conductor.id,
                          nombre: '${conductor.nombre} ${conductor.apellido}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.support_agent),
                  label: const Text(
                    'AYUDA / SOPORTE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: BorderSide(
                      color: AppColors.primaryDark.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    DriverAuthService authService,
  ) async {
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
              backgroundColor: AppColors.primary,
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
}
