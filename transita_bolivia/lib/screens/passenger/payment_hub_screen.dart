import 'package:flutter/material.dart';
import 'pay_trip_screen.dart';

class PaymentHubScreen extends StatefulWidget {
  const PaymentHubScreen({super.key, this.onSupport, this.openCard = false});
  final VoidCallback? onSupport;
  final bool openCard;
  @override
  State<PaymentHubScreen> createState() => PaymentHubScreenState();
}

class PaymentHubScreenState extends State<PaymentHubScreen> {
  late bool _card = widget.openCard;
  void selectCard() => setState(() => _card = true);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagar')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Expanded(child: _method('Con QR', Icons.qr_code_scanner, false)),
              const SizedBox(width: 12),
              Expanded(
                child: _method('Con tarjeta', Icons.contactless_outlined, true),
              ),
            ],
          ),
        ),
        Expanded(
          child: PayTripScreen(
            key: ValueKey(_card),
            nfc: _card,
            embedded: true,
            onPayWithQr: () => setState(() => _card = false),
            onSupport: widget.onSupport,
          ),
        ),
      ],
    ),
  );

  Widget _method(String label, IconData icon, bool card) => Semantics(
    selected: _card == card,
    child: OutlinedButton.icon(
      key: ValueKey(card ? 'pay-method-card' : 'pay-method-qr'),
      onPressed: () => setState(() => _card = card),
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        backgroundColor: _card == card
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      ),
    ),
  );
}
