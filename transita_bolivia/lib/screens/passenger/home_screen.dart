import '../../models/money.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/firebase_service.dart';
import '../../config.dart';
import '../../models/transaction.dart';
import '../../models/financial_chat.dart';
import '../../models/user.dart';
import '../../services/financial_chat_service.dart';
import '../../services/app_preferences.dart';
import '../chat/financial_chat_screen.dart';
import 'pay_trip_screen.dart';
import 'history_screen.dart';
import '../soporte/support_screen.dart';
import 'profile_screen.dart';
import 'receipt_screen.dart';
import '../../widgets/passenger_navigation_bar.dart';
import '../../widgets/passenger_wallet_card.dart';
import '../../widgets/discover_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.firebaseService,
    this.financialChatService,
    this.preferences,
  });

  final FirebaseService? firebaseService;
  final FinancialChatService? financialChatService;
  final AppPreferences? preferences;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};
  final ApiService _apiService = ApiService();
  int? _recentUserId;
  Stream<List<Transaction>>? _recentTrips;
  bool? _balanceHidden;
  final Map<bool, String> _chatDrafts = {};

  AppPreferences get _preferences =>
      widget.preferences ?? AppPreferences.instance;

  FirebaseService get _firebase =>
      widget.firebaseService ?? FirebaseService.instance;

  @override
  void initState() {
    super.initState();
    _loadBalanceVisibility();
  }

  Future<void> _loadBalanceVisibility() async {
    await _preferences.load();
    if (mounted) setState(() => _balanceHidden = _preferences.balanceHidden);
  }

  Future<void> _toggleBalanceVisibility() async {
    final hidden = !(_balanceHidden ?? true);
    setState(() => _balanceHidden = hidden);
    try {
      await _preferences.setBalanceHidden(hidden);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El cambio se aplicó, pero no se pudo guardar para la próxima vez.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_recentUserId != user.id) {
      _recentUserId = user.id;
      _loadRecentTrips(user.id);
    }

    return Scaffold(
      // Cada sección con Scaffold ajusta su propio contenido al teclado.
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _currentIndex,
        children:
            <Widget>[
              _buildHomeTab(user),
              if (_visitedTabs.contains(1))
                const PayTripScreen()
              else
                const SizedBox.shrink(),
              if (_visitedTabs.contains(2))
                PayTripScreen(nfc: true, onPayWithQr: () => _selectTab(1))
              else
                const SizedBox.shrink(),
              if (_visitedTabs.contains(3))
                PassengerProfileScreen(
                  user: user,
                  onLogout: () => _confirmLogout(context, authService),
                )
              else
                const SizedBox.shrink(),
            ].indexed.map((tab) {
              return MediaQuery.removeViewInsets(
                context: context,
                removeBottom: tab.$1 != _currentIndex,
                child: tab.$2,
              );
            }).toList(),
      ),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : PassengerNavigationBar(
              currentIndex: _currentIndex,
              onSelected: _selectTab,
            ),
    );
  }

  void _loadRecentTrips(int userId) {
    _recentTrips = AppConfig.useFirebase
        ? _firebase.transactionHistoryStream(userId)
        : Stream.fromFuture(_apiService.getTransactionHistory(userId));
  }

  void _selectTab(int index) {
    final authService = context.read<AuthService>();
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
      if (index == 0 && !AppConfig.useFirebase) {
        final user = authService.currentUser;
        if (user != null) _loadRecentTrips(user.id);
      }
    });
    if (index == 0) {
      authService.refreshUser();
    }
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          firebaseService: _firebase,
          balanceHidden: _balanceHidden ?? true,
        ),
      ),
    );
    if (!mounted) return;
    final user = context.read<AuthService>().currentUser;
    if (user != null && !AppConfig.useFirebase) {
      setState(() => _loadRecentTrips(user.id));
    }
  }

  void _openRechargeChat(User user, {bool forAnotherPerson = false}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FinancialChatScreen(
          owner: ChatIdentity(
            canal: 'pasajero',
            id: user.id,
            nombre: '${user.nombre} ${user.apellido}',
          ),
          service: widget.financialChatService,
          rechargeForAnother: forAnotherPerson,
          initialDraft:
              _chatDrafts[forAnotherPerson] ??
              (forAnotherPerson
                  ? 'Quiero recargar puntos a otra persona.\nID del beneficiario: \nMonto en Bs: \nReferencia de pago: '
                  : ''),
          onDraftChanged: (value) => _chatDrafts[forAnotherPerson] = value,
        ),
      ),
    );
  }

  void _openSupport(User user) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SupportScreen(
          canal: 'pasajero',
          id: user.id,
          nombre: '${user.nombre} ${user.apellido}',
          firebaseService: _firebase,
        ),
      ),
    );
  }

  Widget _buildHomeTab(User user) {
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
                  Expanded(
                    child: Text(
                      'Hola, ${user.nombre} ${user.tipoDisplay}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Contactar al call center',
                    icon: const Icon(Icons.support_agent, color: Colors.white),
                    onPressed: () => _openSupport(user),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PassengerWalletCard(
                points: user.puntos,
                balanceHidden: _balanceHidden ?? true,
                onToggleVisibility: _balanceHidden == null
                    ? null
                    : _toggleBalanceVisibility,
                onHistory: _openHistory,
              ),
              const SizedBox(height: 20),
              DiscoverSection(
                onRecharge: () => _openRechargeChat(user),
                onRechargeAnother: () =>
                    _openRechargeChat(user, forAnotherPerson: true),
              ),
              const SizedBox(height: 24),
              const Text(
                'Últimos viajes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<Transaction>>(
                stream: _recentTrips,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Text(
                      'No pudimos cargar tus viajes. Inténtalo de nuevo más tarde.',
                    );
                  }

                  final transactions = snapshot.data ?? [];
                  final recentTrips = transactions
                      .where((t) => t.tipo == 'cobro_viaje')
                      .take(5)
                      .toList();

                  if (recentTrips.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No hay viajes recientes',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: recentTrips.map((trip) {
                      return Container(
                        key: ValueKey('recent-trip-${trip.id}'),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
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
                        child: InkWell(
                          onTap: () => openTransactionReceipt(context, trip),
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.directions_bus,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${trip.fecha.day}/${trip.fecha.month}/${trip.fecha.year}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      trip.metodoPagoDisplay,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '-${Money.format(trip.puntos)} pts',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AuthService authService,
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
