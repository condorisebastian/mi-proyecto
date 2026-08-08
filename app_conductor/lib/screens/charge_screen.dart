import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ndef/ndef.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class ChargeScreen extends StatefulWidget {
  const ChargeScreen({super.key});

  @override
  State<ChargeScreen> createState() => _ChargeScreenState();
}

class _ChargeScreenState extends State<ChargeScreen> {
  final ApiService _apiService = ApiService();
  String _lastPayment = '';
  bool _isProcessing = false;

  final List<({String id, String nombre, int puntos})> _tipos = [
    (id: 'estudiante', nombre: 'Estudiante', puntos: 1),
    (id: 'civil', nombre: 'Civil', puntos: 3),
    (id: 'adulto_mayor', nombre: 'Adulto Mayor', puntos: 1),
  ];
  ({String id, String nombre, int puntos}) _tipo =
      (id: 'estudiante', nombre: 'Estudiante', puntos: 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobrar'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIPO DE PASAJERO',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _tipos.map((tipo) {
                          final isSelected = tipo.id == _tipo.id;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _tipo = tipo;
                                });
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE53935)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFE53935)
                                        : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      tipo.nombre,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${tipo.puntos} pt',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white70
                                            : const Color(0xFFE53935),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Monto a cobrar: ${_tipo.puntos} punto(s) = Bs ${_tipo.puntos}.00',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                        'OPCIONES DE PAGO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildPaymentOption(
                        context,
                        icon: Icons.nfc,
                        title: 'Tarjeta NFC',
                        subtitle: 'Acerca la tarjeta al celular',
                        onTap: _readNFC,
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentOption(
                        context,
                        icon: Icons.qr_code_scanner,
                        title: 'QR del Celular',
                        subtitle: 'Escanea el QR del pasajero',
                        onTap: _showQRScanner,
                      ),
                      const SizedBox(height: 24),
                      if (_lastPayment.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _lastPayment,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mantén el celular cerca del pasajero',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFE53935),
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _readNFC() async {
    if (_isProcessing) return;

    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este celular no soporta lectura NFC'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isProcessing = true;
      });

      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
      );
      final text = await _readNdefText();
      await FlutterNfcKit.finish();

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      _onScanned('NFC', text ?? tag.id);
    } catch (e) {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al leer tarjeta NFC'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _readNdefText() async {
    final records = await FlutterNfcKit.readNDEFRecords();
    for (final record in records) {
      final text = record is TextRecord ? record.text : null;
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Future<void> _showQRScanner() async {
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
                  'Escanea el QR del pasajero',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MobileScanner(
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final raw = barcode.rawValue;
                          if (raw != null && raw.isNotEmpty) {
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
      _onScanned('QR', scanned);
    }
  }

  void _onScanned(String method, String rawData) {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final userId = _parseUserId(rawData);
    String passengerLabel = 'Pasajero';
    if (userId != null) {
      passengerLabel = 'Pasajero vinculado (ID $userId)';
    } else if (rawData.isNotEmpty) {
      passengerLabel = 'Pasajero (identificador: $rawData)';
    }

    _showPaymentDialog(method, userId, passengerLabel);
  }

  int? _parseUserId(String raw) {
    if (raw.startsWith('PASAJERO:')) {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        return int.tryParse(parts[1]);
      }
    }
    return null;
  }

  void _showPaymentDialog(String method, int? userId, String passengerLabel) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final conductor = authService.currentConductor;
    final puntos = _tipo.puntos;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pago por $method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Cobrar viaje?'),
            const SizedBox(height: 8),
            Text(passengerLabel,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            Text(
              'Monto: $puntos punto(s) = Bs $puntos.00',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
              }
            },
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final result = await _apiService.registerTrip(
                conductorId: conductor!.id,
                tipoUsuario: _tipo.id,
                puntos: puntos,
                metodoPago: method == 'NFC' ? 'tarjeta_nfc' : 'qr',
                userId: userId,
              );

              if (!mounted) return;
              setState(() {
                _isProcessing = false;
              });

              if (result.ok) {
                setState(() {
                  _lastPayment = 'Pago exitoso: -$puntos punto(s) ($method)';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pago registrado exitosamente'),
                    backgroundColor: Colors.green,
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
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('COBRAR'),
          ),
        ],
      ),
    );
  }
}
