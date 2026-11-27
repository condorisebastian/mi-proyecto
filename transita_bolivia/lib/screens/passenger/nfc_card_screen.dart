import 'package:flutter/material.dart';
import 'pay_trip_screen.dart';

class NfcCardScreen extends StatelessWidget {
  const NfcCardScreen({super.key});

  @override
  Widget build(BuildContext context) => const PayTripScreen(nfc: true);
}
