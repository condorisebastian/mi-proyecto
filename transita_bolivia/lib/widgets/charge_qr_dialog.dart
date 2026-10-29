import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/trip_qr.dart';
import '../models/money.dart';
import 'amount_speaker_button.dart';

Future<void> showTripQr(
  BuildContext context,
  TripQr qr,
  String label,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'QR de cobro: ${qr.encode()}',
            child: Container(
              color: Colors.white,
              child: QrImageView(
                data: qr.encode(),
                size: math.min(280, MediaQuery.sizeOf(context).width - 100),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${qr.cantidad} pasaje(s) · Bs ${Money.format(qr.puntos)}',
            textAlign: TextAlign.center,
          ),
          AmountSpeakerButton(amount: qr.puntos, label: 'Total a cobrar'),
          const SizedBox(height: 12),
          const Text(
            'Espera la confirmación de pago antes de dar por cobrado el viaje.',
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    ),
  ),
);
