import 'package:flutter/material.dart';
import '../../theme.dart';
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
    appBar: AppBar(
      title: const Text('Pagar'),
      actions: [
        if (widget.onSupport != null)
          IconButton(
            tooltip: 'Ayuda con el pago',
            onPressed: widget.onSupport,
            icon: const Icon(Icons.support_agent_rounded),
          ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                children: [
                  Expanded(
                    child: _method('Con QR', Icons.qr_code_scanner, false),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _method(
                      'Tarjeta NFC',
                      Icons.contactless_outlined,
                      true,
                    ),
                  ),
                ],
              ),
            ),
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
            ? AppColors.primaryDark
            : Theme.of(context).colorScheme.surface,
        foregroundColor: _card == card
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        side: BorderSide(
          color: _card == card
              ? AppColors.primaryDark
              : Theme.of(context).colorScheme.outlineVariant,
          width: _card == card ? 2 : 1,
        ),
        minimumSize: const Size(0, 56),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      ),
    ),
  );
}
