import '../../models/money.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/trip_qr.dart';
import '../../widgets/amount_speaker_button.dart';
import 'history_screen.dart';
import 'passenger_qr_screen.dart';
import '../../widgets/passenger_nfc_panel.dart';
import '../../widgets/passenger_qr_panel.dart';
import '../soporte/support_screen.dart';
import '../../services/payment_preferences.dart';

class PayTripScreen extends StatefulWidget {
  const PayTripScreen({
    super.key,
    this.nfc = false,
    this.onPayWithQr,
    this.onSupport,
    this.embedded = false,
  });

  final bool nfc;
  final VoidCallback? onPayWithQr;
  final VoidCallback? onSupport;
  final bool embedded;

  @override
  State<PayTripScreen> createState() => _PayTripScreenState();
}

class _PayTripScreenState extends State<PayTripScreen> {
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(widget.nfc ? 'Tarjeta NFC' : 'Pagar con QR'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: widget.nfc
                  ? _buildNfcInfo()
                  : PassengerQrPanel(
                      user: user,
                      isProcessing: _isProcessing,
                      onScan: _showQRScanner,
                      onShowQr: user == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PassengerQrScreen(userId: user.id),
                              ),
                            ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNfcInfo() {
    final user = context.read<AuthService>().currentUser;
    return PassengerNfcPanel(
      onPayWithQr:
          widget.onPayWithQr ??
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PayTripScreen()),
          ),
      onSupport:
          widget.onSupport ??
          (user == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SupportScreen(
                      canal: 'pasajero',
                      id: user.id,
                      nombre: '${user.nombre} ${user.apellido}',
                    ),
                  ),
                )),
    );
  }

  Future<void> _showQRScanner() async {
    bool scannedOnce = false;
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                  'Escanea el QR del conductor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MobileScanner(
                      onDetect: (capture) {
                        if (scannedOnce) return;
                        for (final barcode in capture.barcodes) {
                          final raw = barcode.rawValue;
                          if (raw != null && raw.isNotEmpty) {
                            scannedOnce = true;
                            Navigator.pop(context, raw);
                            return;
                          }
                        }
                      },
                      errorBuilder: (context, error) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 60,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No se pudo abrir la cámara: $error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCELAR'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (scanned != null && scanned.isNotEmpty) {
      _handleScannedCode(scanned);
    }
  }

  void _handleScannedCode(String raw) {
    final parsed = TripQr.tryParse(raw);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR inválido: no corresponde a un conductor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    final conductorId = parsed.conductorId;
    final puntos = parsed.puntos;
    final tipo = parsed.tipo;
    if (!parsed.isCustom &&
        !parsed.isProvince &&
        (tipo != user.tipo ||
            puntos != Money.multiply(user.costoViaje, parsed.cantidad))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pide al conductor un QR para tu tipo de pasajero.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pagar viaje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conductor N° $conductorId'),
              const SizedBox(height: 8),
              Text(
                parsed.isProvince
                    ? 'Destino: ${parsed.provinceRoute!.destination}'
                    : parsed.isCustom
                    ? 'Monto personalizado por el conductor'
                    : 'Tipo de pasajero: ${_tipoLabel(tipo)}',
              ),
              const SizedBox(height: 8),
              Text('Cantidad: ${parsed.cantidad} pasaje(s)'),
              if (!parsed.isCustom && !parsed.isProvince)
                Text(
                  'Tarifa por persona: ${Money.format(user.costoViaje)} punto(s)',
                ),
              const SizedBox(height: 8),
              Text(
                '¿Confirmas el pago de ${Money.format(puntos)} punto(s)?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              AmountSpeakerButton(amount: puntos, label: 'Total a pagar'),
              const SizedBox(height: 8),
              Text(
                'Saldo disponible: ${Money.format(user.puntos)} puntos',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_isProcessing) return;
              Navigator.pop(dialogContext);
              setState(() {
                _isProcessing = true;
              });

              final permission = await PaymentAuthorization(
                PaymentPreferences(user.id),
              ).authorize(puntos);
              if (!mounted) return;
              if (!permission.ok || authService.currentUser?.id != user.id) {
                setState(() => _isProcessing = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      permission.ok
                          ? 'La sesión cambió. Vuelve a iniciar el pago.'
                          : permission.message,
                    ),
                  ),
                );
                return;
              }

              final result = await _apiService.payTrip(
                user.id,
                conductorId,
                puntos,
                'qr',
                tipoUsuario: tipo.isNotEmpty ? tipo : user.tipo,
                paymentReference: parsed.reference,
                cantidadPasajeros: parsed.cantidad,
              );

              if (!mounted) return;
              setState(() {
                _isProcessing = false;
              });

              if (result.ok) {
                await authService.refreshUser();
                if (!mounted) return;
                final u = authService.currentUser;
                final now = DateTime.now();
                final fecha =
                    '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
                    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 46,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  '¡Pago exitoso!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Comprobante de pago',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                            child: Column(
                              children: [
                                _receiptRow(
                                  'Pasajero',
                                  '${u?.nombre ?? ''} ${u?.apellido ?? ''}'
                                      .trim(),
                                ),
                                _receiptRow('Tipo', _tipoLabel(tipo)),
                                _receiptRow('Pasajes', '${parsed.cantidad}'),
                                _receiptRow('Conductor', '#$conductorId'),
                                const Divider(height: 24),
                                _receiptRow(
                                  'Monto',
                                  '-${Money.format(puntos)} punto(s)',
                                  valueColor: Colors.redAccent,
                                  bold: true,
                                ),
                                _receiptRow(
                                  'Nuevo saldo',
                                  '${Money.format(u?.puntos ?? 0)} puntos',
                                  valueColor: AppColors.primary,
                                  bold: true,
                                ),
                                _receiptRow('Fecha', fecha),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'LISTO',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('VER COMPROBANTES'),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                this.context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const HistoryScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('PAGAR'),
          ),
        ],
      ),
    );
  }

  String _tipoLabel(String tipo) {
    switch (tipo) {
      case 'estudiante':
        return 'Estudiante';
      case 'civil':
        return 'Civil';
      case 'adulto_mayor':
        return 'Adulto Mayor';
      case 'discapacitado':
        return 'Discapacitado';
      case TripQr.customType:
        return 'Monto personalizado';
      default:
        return tipo;
    }
  }

  Widget _receiptRow(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? Colors.grey[850],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
