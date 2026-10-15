import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/trip_qr.dart';
import '../../services/driver_auth_service.dart';

class DriverChargeScreen extends StatefulWidget {
  const DriverChargeScreen({super.key});
  @override
  State<DriverChargeScreen> createState() => _DriverChargeScreenState();
}

class _DriverChargeScreenState extends State<DriverChargeScreen> {
  static const _labels = {
    'estudiante': 'Estudiante',
    'civil': 'Civil',
    'adulto_mayor': 'Adulto mayor',
    'discapacitado': 'Persona con discapacidad',
  };
  String _tipo = 'estudiante';
  int _cantidad = 1;
  static const _icons = {
    'estudiante': Icons.school_outlined,
    'civil': Icons.person_outline,
    'adulto_mayor': Icons.elderly,
    'discapacitado': Icons.accessible,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cobrar con QR')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tipo de pasajero',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final labelStyle = Theme.of(context).textTheme.bodyMedium!
                    .copyWith(fontWeight: FontWeight.bold, fontSize: 14);
                final fareStyle = Theme.of(
                  context,
                ).textTheme.bodySmall!.copyWith(fontSize: 11);
                final width = (constraints.maxWidth - 12) / 2 - 24;
                double textHeight(String text, TextStyle style) {
                  final painter = TextPainter(
                    text: TextSpan(text: text, style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: width);
                  final height = painter.height;
                  painter.dispose();
                  return height;
                }

                final labelHeight = _labels.values
                    .map((text) => textHeight(text, labelStyle))
                    .reduce(math.max);
                final tileHeight = math.max(
                  132.0,
                  labelHeight + textHeight('3 punto / persona', fareStyle) + 70,
                );
                return GridView(
                  key: const Key('passenger-type-grid'),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: tileHeight,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _labels.entries.map((entry) {
                    final selected = _tipo == entry.key;
                    final color = Theme.of(context).colorScheme.primary;
                    return Semantics(
                      selected: selected,
                      button: true,
                      child: Material(
                        color: selected
                            ? color.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => setState(() => _tipo = entry.key),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected ? color : Colors.grey.shade300,
                                width: selected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_icons[entry.key], size: 30, color: color),
                                const SizedBox(height: 8),
                                Text(
                                  entry.value,
                                  textAlign: TextAlign.center,
                                  style: labelStyle,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${TripQr.fares[entry.key]} punto / persona',
                                  textAlign: TextAlign.center,
                                  style: fareStyle,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payments_outlined),
                        SizedBox(width: 8),
                        Text(
                          'Pago',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Una persona puede pagar los pasajes de su grupo.',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Quitar un pasaje',
                          onPressed: _cantidad > 1
                              ? () => setState(() => _cantidad--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Flexible(
                          child: Text(
                            '$_cantidad pasaje(s)',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Agregar un pasaje',
                          onPressed: _cantidad < TripQr.maxPassengers
                              ? () => setState(() => _cantidad++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Total: ${TripQr.fares[_tipo]! * _cantidad} punto(s) = Bs ${TripQr.fares[_tipo]! * _cantidad}.00',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showChargeQr,
              icon: const Icon(Icons.qr_code_2),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('MOSTRAR QR'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'El pasajero escanea este QR y confirma el pago en su teléfono. '
              'Recibirás un aviso y un sonido cuando el pago sea confirmado.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showChargeQr() {
    final conductor = context.read<DriverAuthService>().currentConductor;
    if (conductor == null) return;
    final qr = TripQr(
      conductorId: conductor.id,
      tipo: _tipo,
      puntos: TripQr.fares[_tipo]! * _cantidad,
      reference: TripQr.newReference(),
      cantidad: _cantidad,
    );
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Escanea para pagar',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('${conductor.nombre} ${conductor.apellido}'),
              const SizedBox(height: 16),
              Semantics(
                label: 'QR de cobro: ${qr.encode()}',
                child: Container(
                  color: Colors.white,
                  child: QrImageView(
                    data: qr.encode(),
                    size: 250,
                    gapless: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_labels[_tipo]} · ${qr.cantidad} pasaje(s)\nTotal: ${qr.puntos} punto(s)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Espera el aviso de pago exitoso antes de dar por cobrado el viaje.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CERRAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
