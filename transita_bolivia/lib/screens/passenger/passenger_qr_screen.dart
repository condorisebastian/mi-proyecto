import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/passenger_qr_window_store.dart';
import '../../services/auth_service.dart';

class PassengerQrScreen extends StatefulWidget {
  const PassengerQrScreen({super.key, required this.userId, this.store});
  final int userId;
  final PassengerQrWindowStore? store;
  @override
  State<PassengerQrScreen> createState() => _PassengerQrScreenState();
}

class _PassengerQrScreenState extends State<PassengerQrScreen>
    with WidgetsBindingObserver {
  PassengerQrWindowStore get _store =>
      widget.store ?? PassengerQrWindowStore.instance;
  PassengerQrWindow? _window;
  Timer? _ticker;
  int _remaining = 0;
  bool _busy = false;
  bool _visible = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generate();
  }

  Future<void> _generate() async {
    if (_busy ||
        _remaining > 0 ||
        context.read<AuthService>().currentUser?.id != widget.userId) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final window = await _store.issue(widget.userId);
      if (!mounted) return;
      setState(() {
        _window = window;
        _remaining = window.remaining(_store.now);
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo preparar tu QR. Inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tick() {
    if (!mounted || _window == null) return;
    final remaining = _window!.remaining(_store.now);
    if (remaining == 0) _ticker?.cancel();
    setState(() => _remaining = remaining);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      setState(() => _visible = false);
      unawaited(_store.hide(widget.userId));
    } else {
      _tick();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthService>().currentUser;
    final ownSession = user?.id == widget.userId;
    final ticket = _window?.qr;
    final qr =
        ownSession &&
            _visible &&
            ticket != null &&
            ticket.expiresAt.isAfter(_store.now)
        ? ticket
        : null;
    final canGenerate = ownSession && !_busy && _remaining == 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi QR')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Preséntalo al lector',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mantén la pantalla frente a la cámara ESP32-CAM.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: qr == null
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                size: 72,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  !ownSession
                                      ? 'La sesión cambió'
                                      : _busy
                                      ? 'Preparando tu QR…'
                                      : _remaining > 0
                                      ? 'QR oculto'
                                      : 'QR vencido',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) => Center(
                            child: QrImageView(
                              key: const ValueKey('passenger-presentation-qr'),
                              data: qr.encode(),
                              size: math.min(300, constraints.maxWidth),
                              padding: const EdgeInsets.all(28),
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              semanticsLabel:
                                  'QR temporal de identificación de prueba',
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  qr == null
                      ? _remaining > 0
                            ? 'Espera $_remaining s para generar otro.'
                            : 'Genera otro cuando estés frente al lector.'
                      : 'Vence en $_remaining s',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('regenerate-passenger-qr'),
                  onPressed: canGenerate
                      ? () {
                          _visible = true;
                          _generate();
                        }
                      : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    _busy
                        ? 'Preparando QR…'
                        : _remaining > 0
                        ? 'Disponible en $_remaining s'
                        : 'Generar otro QR',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Prueba de lectura · No autoriza cobros',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este QR no contiene tu PIN, carnet ni saldo. El cobro mediante '
                  'ESP32-CAM necesitará validación y confirmación en el servidor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
