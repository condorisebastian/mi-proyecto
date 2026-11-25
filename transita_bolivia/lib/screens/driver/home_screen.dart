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
import '../../models/conductor.dart';
import '../../widgets/driver_dashboard.dart';
import '../../config.dart';
import 'charge_screen.dart';
import 'summary_screen.dart';
import '../soporte/support_screen.dart';
import '../../models/financial_chat.dart';
import '../chat/financial_chat_screen.dart';
import '../accessibility_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key, this.firebaseService});
  final FirebaseService? firebaseService;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};
  bool _summaryLoading = true;
  bool _summaryFailed = false;
  FirebaseService get _firebase =>
      widget.firebaseService ?? FirebaseService.instance;
  final DriverApiService _apiService = DriverApiService();
  Map<String, dynamic> _dailySummary = {};
  StreamSubscription<Map<String, dynamic>>? _summarySub;
  StreamSubscription<({List<DriverPayment> payments, bool fromCache})>?
  _paymentsSub;
  final _paymentTracker = DriverPaymentTracker();
  OverlayEntry? _paymentNotice;
  Timer? _noticeTimer;

  final GlobalKey<DriverSummaryScreenState> _summaryKey =
      GlobalKey<DriverSummaryScreenState>();

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<DriverAuthService>(context, listen: false);
    if (AppConfig.useFirebase && authService.currentConductor != null) {
      _summarySub = _firebase
          .dailySummaryStream(authService.currentConductor!.id)
          .listen(
            (summary) {
              if (!mounted) return;
              setState(() {
                _dailySummary = summary;
                _summaryLoading = false;
                _summaryFailed = false;
              });
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  _summaryLoading = false;
                  _summaryFailed = true;
                });
              }
            },
          );
      _paymentsSub = _firebase
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
              debugPrint('No se pudo escuchar la confirmación de pagos.');
            },
          );
    } else {
      _loadDailySummary();
    }
  }

  @override
  void dispose() {
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
    final conductor = context.read<DriverAuthService>().currentConductor;
    if (conductor == null) return;
    setState(() {
      _summaryLoading = true;
      _summaryFailed = false;
    });
    try {
      final summary = AppConfig.useFirebase
          ? await _firebase.dailySummaryStream(conductor.id).first
          : await _apiService.getDailySummary(conductor.id);
      if (mounted) {
        setState(() {
          _dailySummary = summary;
          _summaryLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _summaryLoading = false;
          _summaryFailed = true;
        });
      }
    }
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
    if (!AppConfig.useFirebase) {
      if (index == 0) _loadDailySummary();
      if (index == 2) _summaryKey.currentState?.reload();
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
        children:
            [
                  _buildHomeTab(conductor, authService),
                  _visitedTabs.contains(1)
                      ? const DriverChargeScreen()
                      : const SizedBox.shrink(),
                  _visitedTabs.contains(2)
                      ? DriverSummaryScreen(
                          key: _summaryKey,
                          firebaseService: _firebase,
                        )
                      : const SizedBox.shrink(),
                  if (_visitedTabs.contains(3))
                    FinancialChatScreen(
                      owner: ChatIdentity(
                        canal: 'conductor',
                        id: conductor.id,
                        nombre: '${conductor.nombre} ${conductor.apellido}',
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ].indexed
                .map(
                  (entry) => MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: entry.$1 != _currentIndex,
                    child: TickerMode(
                      enabled: entry.$1 == _currentIndex,
                      child: entry.$2,
                    ),
                  ),
                )
                .toList(),
      ),
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.qr_code_2_rounded),
                  label: 'Cobrar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: 'Resumen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.forum_outlined),
                  label: 'Chat',
                ),
              ],
            ),
    );
  }

  Widget _buildHomeTab(Conductor conductor, DriverAuthService authService) {
    return DriverDashboard(
      conductor: conductor,
      summary: _dailySummary,
      loading: _summaryLoading,
      failed: _summaryFailed,
      onCharge: () => _selectTab(1),
      onSummary: () => _selectTab(2),
      onChat: () => _selectTab(3),
      onRefresh: () => _loadDailySummary(),
      onLogout: () => _confirmLogout(context, authService),
      onAccessibility: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const AccessibilityScreen()),
      ),
      onSupport: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SupportScreen(
            canal: 'conductor',
            id: conductor.id,
            nombre: '${conductor.nombre} ${conductor.apellido}',
            firebaseService: _firebase,
          ),
        ),
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
