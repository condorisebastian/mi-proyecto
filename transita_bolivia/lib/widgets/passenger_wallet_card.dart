import 'package:flutter/material.dart';

import '../models/money.dart';
import 'amount_speaker_button.dart';

class PassengerWalletCard extends StatelessWidget {
  const PassengerWalletCard({
    super.key,
    required this.points,
    required this.balanceHidden,
    required this.onToggleVisibility,
    required this.onHistory,
  });

  final num points;
  final bool balanceHidden;
  final VoidCallback? onToggleVisibility;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tu billetera',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.stars_rounded, size: 36, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: balanceHidden
                      ? Semantics(
                          label: 'Saldo oculto',
                          child: const ExcludeSemantics(
                            child: Text(
                              '••••',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          Money.format(points),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                ),
                IconButton(
                  key: const ValueKey('wallet-visibility'),
                  tooltip: balanceHidden ? 'Mostrar saldo' : 'Ocultar saldo',
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    balanceHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!balanceHidden) ...[
              Text(
                'puntos · Bs ${Money.format(points)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              AmountSpeakerButton(amount: points, label: 'Saldo disponible'),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onHistory,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Ver movimientos'),
            ),
          ],
        ),
      ),
    );
  }
}
