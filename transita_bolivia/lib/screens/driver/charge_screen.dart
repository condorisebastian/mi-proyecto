import '../../models/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _cantidadController = TextEditingController(text: '1');
  final _montoController = TextEditingController();
  final _cantidadKey = GlobalKey<FormFieldState<String>>();
  final _montoKey = GlobalKey<FormFieldState<String>>();
  static const _icons = {
    'estudiante': Icons.school_outlined,
    'civil': Icons.person_outline,
    'adulto_mayor': Icons.elderly,
    'discapacitado': Icons.accessible,
  };

  @override
  void dispose() {
    _cantidadController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cobrar con QR')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    TextFormField(
                      key: _cantidadKey,
                      controller: _cantidadController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad de pasajes',
                        hintText: '1',
                        errorMaxLines: 3,
                      ),
                      validator: (value) {
                        final cantidad = int.tryParse(value?.trim() ?? '');
                        if (cantidad == null ||
                            cantidad < 1 ||
                            cantidad > TripQr.maxPassengers) {
                          return 'Introduce entre 1 y ${TripQr.maxPassengers} pasajes';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: _montoKey,
                      controller: _montoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Monto total (Bs)',
                        hintText: 'Ej. 10.50',
                        helperText: 'Total a cobrar por todos los pasajes.',
                        helperMaxLines: 2,
                        errorMaxLines: 3,
                      ),
                      validator: (value) {
                        final monto = Money.tryParse(value ?? '');
                        if (monto == null ||
                            monto <= 0 ||
                            monto > TripQr.maxAmount) {
                          return 'Introduce un monto válido con hasta 2 decimales';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _showChargeQr(custom: true),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showChargeQr(custom: true),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('MOSTRAR QR'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                  labelHeight + textHeight('Bs 3.50 / persona', fareStyle) + 70,
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
                          onTap: () {
                            setState(() => _tipo = entry.key);
                            _showChargeQr();
                          },
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
                                  'Bs ${Money.format(TripQr.fares[entry.key])} / persona',
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
            const SizedBox(height: 20),
            const Text(
              'Toca un tipo de pasajero para mostrar el QR automáticamente. '
              'El pasajero lo escanea y confirma el pago. '
              'Recibirás un aviso y un sonido cuando el pago sea confirmado.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showChargeQr({bool custom = false}) {
    final validQuantity = _cantidadKey.currentState!.validate();
    final validAmount = !custom || _montoKey.currentState!.validate();
    if (!validQuantity || !validAmount) return;
    final conductor = context.read<DriverAuthService>().currentConductor;
    if (conductor == null) return;
    FocusScope.of(context).unfocus();
    final cantidad = int.parse(_cantidadController.text.trim());
    final qr = TripQr(
      conductorId: conductor.id,
      tipo: custom ? TripQr.customType : _tipo,
      puntos: custom
          ? Money.read(_montoController.text)
          : Money.multiply(TripQr.fares[_tipo]!, cantidad),
      reference: TripQr.newReference(),
      cantidad: cantidad,
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
                    size: math.min(250, MediaQuery.sizeOf(context).width - 100),
                    gapless: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${qr.isCustom ? 'Monto personalizado' : _labels[qr.tipo]} · ${qr.cantidad} pasaje(s)\nTotal: Bs ${Money.format(qr.puntos)}',
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
