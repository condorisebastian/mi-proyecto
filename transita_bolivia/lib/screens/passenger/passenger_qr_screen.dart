import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config.dart';
import '../../models/passenger_qr.dart';
import '../../services/auth_service.dart';

class PassengerQrScreen extends StatefulWidget {
  const PassengerQrScreen({super.key, required this.userId});
  final int userId;
  @override
  State<PassengerQrScreen> createState() => _PassengerQrScreenState();
}

class _PassengerQrScreenState extends State<PassengerQrScreen>
    with WidgetsBindingObserver {
  PassengerQr? _qr;
  Timer? _expiry;
  Timer? _ticker;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generate();
  }

  void _generate() {
    if (context.read<AuthService>().currentUser?.id != widget.userId) return;
    _expiry?.cancel();
    _ticker?.cancel();
    final qr = PassengerQr.create(
      widget.userId,
      backend: AppConfig.useFirebase ? 'F' : 'P',
    );
    setState(() {
      _qr = qr;
      _remaining = 15;
    });
    _expiry = Timer(PassengerQr.lifetime, _invalidate);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _qr == null) return;
      final remaining =
          ((qr.expiresAt.difference(DateTime.now()).inMilliseconds + 999) ~/
                  1000)
              .clamp(0, 15);
      if (remaining == 0) {
        _invalidate();
        return;
      }
      setState(() => _remaining = remaining);
    });
  }

  void _invalidate() {
    _expiry?.cancel();
    _ticker?.cancel();
    if (mounted) {
      setState(() {
        _qr = null;
        _remaining = 0;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _invalidate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthService>().currentUser;
    final ownSession = user?.id == widget.userId;
    final qr = ownSession ? _qr : null;
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
                                  ownSession
                                      ? 'QR vencido'
                                      : 'La sesión cambió',
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
                      ? 'Genera otro cuando estés frente al lector.'
                      : 'Vence en $_remaining s',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('regenerate-passenger-qr'),
                  onPressed: ownSession ? _generate : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    qr == null ? 'Generar otro QR' : 'Generar nuevo QR',
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
                  'ESP32-CAM necesitará validación y confirmación en el servidor. '
                  'Para pagar ahora, escanea el QR del conductor.',
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
