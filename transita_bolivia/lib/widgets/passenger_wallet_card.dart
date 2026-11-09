import 'package:flutter/material.dart';

import '../models/money.dart';
import '../theme.dart';
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
    final highContrast = MediaQuery.highContrastOf(context);
    final secondaryText = highContrast ? Colors.white : Colors.white70;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: highContrast
                ? [Colors.black, Colors.black]
                : [AppColors.navy, AppColors.primaryDark],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: secondaryText,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tu billetera',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      size: 28,
                      color: highContrast ? Colors.white : AppColors.teal,
                    ),
                  ),
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
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            Money.format(points),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  IconButton(
                    key: const ValueKey('wallet-visibility'),
                    tooltip: balanceHidden ? 'Mostrar saldo' : 'Ocultar saldo',
                    onPressed: onToggleVisibility,
                    color: Colors.white,
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
                  style: TextStyle(color: secondaryText),
                ),
                AmountSpeakerButton(
                  amount: points,
                  label: 'Saldo disponible',
                  color: Colors.white,
                ),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver movimientos'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
