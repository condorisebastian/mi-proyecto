import 'package:flutter/material.dart';
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
            ..._labels.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(
                      '${entry.value} · ${TripQr.fares[entry.key]} punto(s)',
                    ),
                  ),
                  selected: _tipo == entry.key,
                  onSelected: (_) => setState(() => _tipo = entry.key),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Monto: ${TripQr.fares[_tipo]} punto(s) = Bs ${TripQr.fares[_tipo]}.00',
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
      puntos: TripQr.fares[_tipo]!,
      reference: TripQr.newReference(),
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
                '${_labels[_tipo]} · ${qr.puntos} punto(s)',
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
