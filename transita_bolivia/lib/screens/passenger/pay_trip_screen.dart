import '../../models/money.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/trip_qr.dart';

class PayTripScreen extends StatefulWidget {
  const PayTripScreen({super.key});

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
      appBar: AppBar(
        title: const Text('Pagar Viaje'),
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
          child: SingleChildScrollView(
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
                      Icon(
                        user?.tipo == 'estudiante'
                            ? Icons.school
                            : user?.tipo == 'civil'
                            ? Icons.person
                            : user?.tipo == 'adulto_mayor'
                            ? Icons.elderly
                            : Icons.accessible,
                        size: 60,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pagar Viaje',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Costo: ${Money.format(user?.costoViaje ?? 1)} punto(s)',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            const Text(
                              'Tu saldo:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              '${Money.format(user?.puntos ?? 0)} puntos',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Escanea el QR que muestra el conductor',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _showQRScanner,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 24),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'ESCANEAR QR DEL CONDUCTOR',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
    if (tipo != user.tipo || puntos != user.costoViaje * parsed.cantidad) {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conductor N° $conductorId'),
            const SizedBox(height: 8),
            Text('Tipo de pasajero: ${_tipoLabel(tipo)}'),
            const SizedBox(height: 8),
            Text('Cantidad: ${parsed.cantidad} pasaje(s)'),
            Text(
              'Tarifa por persona: ${Money.format(user.costoViaje)} punto(s)',
            ),
            const SizedBox(height: 8),
            Text(
              '¿Confirmas el pago de ${Money.format(puntos)} punto(s)?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo disponible: ${Money.format(user.puntos)} puntos',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
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
                      ],
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
