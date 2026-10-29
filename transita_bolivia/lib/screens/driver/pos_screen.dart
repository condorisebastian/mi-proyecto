import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/money.dart';
import '../../models/trip_qr.dart';
import '../../services/driver_auth_service.dart';
import '../../services/nfc_service.dart';
import '../../services/pos_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({
    super.key,
    this.routeId,
    this.amountCents,
    this.quantity = 1,
  });
  final String? routeId;
  final int? amountCents;
  final int quantity;
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  late final _amount = TextEditingController(
    text: widget.amountCents == null
        ? ''
        : Money.format(widget.amountCents! / 100),
  );
  final _nfc = NfcService();
  final _service = PosService();
  bool _busy = false;
  String _status = 'Prepara el importe y acerca la tarjeta Transita.';
  bool _approved = false;
  String? _reference;
  CardProof? _pendingCard;
  int? _pendingAmount;
  bool _uncertain = false;

  @override
  void dispose() {
    _nfc.cancel();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activar terminal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo del operador',
              ),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña de la terminal',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ACTIVAR'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      try {
        await _service.activate(email.text, password.text);
        if (mounted) setState(() => _status = 'Sesión de terminal activada.');
      } catch (_) {
        if (mounted) {
          setState(
            () => _status =
                'No se pudo activar la terminal. Verifica los datos y la conexión.',
          );
        }
      }
    }
    email.dispose();
    password.dispose();
  }

  Future<void> _charge() async {
    if (_busy) return;
    if (!PosService.enabled) {
      setState(
        () => _status =
            'Terminal pendiente de activación. El responsable debe habilitar el servicio y la tarjeta antes del primer cobro.',
      );
      return;
    }
    final parsed = Money.tryParse(_amount.text);
    if (parsed == null || parsed <= 0 || parsed > 1000) {
      setState(
        () => _status = 'Introduce un importe entre Bs 0.01 y Bs 1,000.00.',
      );
      return;
    }
    final driverId = context.read<DriverAuthService>().currentConductor?.id;
    if (driverId == null) return;
    setState(() {
      _busy = true;
      _approved = false;
      _status = _uncertain
          ? 'Consultando la misma operación…'
          : 'Acerca la tarjeta Transita al lector.';
    });
    try {
      if (!_uncertain) {
        final state = await _nfc.status();
        if (state != 'ready') {
          throw StateError(
            state == 'disabled'
                ? 'Activa NFC en este equipo.'
                : 'Este equipo necesita un lector NFC compatible. Puedes seguir cobrando con QR.',
          );
        }
        final card = CardProof.tryParse(await _nfc.readCard());
        if (card == null) {
          throw StateError(
            'Tarjeta no compatible. Solicita una tarjeta Transita activada.',
          );
        }
        _pendingCard = card;
        _pendingAmount = Money.cents(parsed);
        _reference = TripQr.newReference();
      }
      if (mounted) {
        setState(() => _status = 'Verificando saldo y autorizando el cobro…');
      }
      _uncertain = true;
      final receipt = await _service.charge(
        card: _pendingCard!,
        conductorId: driverId,
        amountCents: _pendingAmount!,
        quantity: widget.quantity,
        reference: _reference!,
        routeId: widget.routeId,
      );
      _uncertain = false;
      _pendingCard = null;
      if (mounted) {
        setState(() {
          _approved = true;
          _status =
              'PAGO APROBADO\nBs ${Money.format(_pendingAmount! / 100)}\nComprobante ${receipt.substring(0, 12)}';
        });
      }
    } on FirebaseFunctionsException catch (error) {
      if (const [
        'failed-precondition',
        'permission-denied',
        'unauthenticated',
        'invalid-argument',
      ].contains(error.code)) {
        _uncertain = false;
      }
      if (mounted) {
        setState(
          () => _status = _uncertain
              ? 'Resultado pendiente. Reintenta consultar esta operación antes de iniciar otra.'
              : error.message ?? 'Cobro rechazado.',
        );
      }
    } on FirebaseAuthException {
      _uncertain = false;
      if (mounted) {
        setState(() => _status = 'Activa la sesión de esta terminal.');
      }
    } on StateError catch (error) {
      _uncertain = false;
      if (mounted) setState(() => _status = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = _uncertain
              ? 'Resultado pendiente. Consulta esta operación antes de iniciar otra.'
              : 'No se pudo leer la tarjeta. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terminal POS')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.contactless, size: 72),
            const SizedBox(height: 20),
            const Text(
              'Tarjeta Transita',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'El pasaje se descuenta de las recargas del pasajero.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _amount,
              enabled: !_busy && !_uncertain && widget.routeId == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 36),
              decoration: const InputDecoration(
                labelText: 'Total a cobrar (Bs)',
                hintText: '8.50',
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: _approved ? Colors.green.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      color: _approved ? Colors.green.shade900 : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_busy)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _charge,
              icon: Icon(_uncertain ? Icons.refresh : Icons.nfc),
              label: Text(
                _uncertain
                    ? 'CONSULTAR OPERACIÓN PENDIENTE'
                    : 'COBRAR CON TARJETA',
              ),
            ),
            if (_busy && !_uncertain)
              TextButton(
                onPressed: _nfc.cancel,
                child: const Text('CANCELAR LECTURA'),
              ),
            if (PosService.enabled)
              TextButton(
                onPressed: _busy ? null : _activate,
                child: const Text('ACTIVAR TERMINAL'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Acerca la tarjeta una sola vez. La aprobación llega del servidor. '
              'Si se pierde la conexión, consulta la operación pendiente para evitar repetir el cobro.',
            ),
          ],
        ),
      ),
    ),
  );
}
