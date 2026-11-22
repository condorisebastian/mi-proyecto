import 'package:flutter/material.dart';
import '../models/money.dart';
import '../theme.dart';
import '../services/app_preferences.dart';
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
  static const leadingWidth = 48.0;

  Widget _row(Widget leading, Widget content, {Widget? trailing}) => Row(
    children: [
      SizedBox(
        width: leadingWidth,
        child: Center(child: leading),
      ),
      const SizedBox(width: 12),
      Expanded(child: content),
      ?trailing,
    ],
  );

  Widget _action({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Key? iconKey,
  }) => TextButton(
    key: key,
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(48),
      alignment: Alignment.centerLeft,
    ),
    child: _row(Icon(icon, key: iconKey, size: 24), Text(label)),
  );

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final secondaryText = highContrast ? Colors.white : Colors.white70;
    final visibilityLabel = balanceHidden ? 'Mostrar saldo' : 'Ocultar saldo';
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
              _row(
                Icon(
                  Icons.account_balance_wallet_outlined,
                  key: const ValueKey('wallet-title-icon'),
                  color: secondaryText,
                ),
                const Text(
                  'Tu billetera',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _row(
                Image.asset(
                  'assets/images/icono_saldo.png',
                  key: const ValueKey('wallet-points-icon'),
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                  semanticLabel: 'Puntos de tu billetera',
                ),
                balanceHidden
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
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                trailing: IconButton(
                  key: const ValueKey('wallet-visibility'),
                  tooltip: visibilityLabel,
                  onPressed: onToggleVisibility,
                  color: Colors.white,
                  icon: Icon(
                    balanceHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    key: const ValueKey('wallet-eye-icon'),
                  ),
                ),
              ),
              if (!balanceHidden) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: leadingWidth + 12),
                  child: Text(
                    'puntos · Bs ${Money.format(points)}',
                    style: TextStyle(color: secondaryText),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _action(
                icon: Icons.receipt_long_outlined,
                iconKey: const ValueKey('wallet-history-icon'),
                label: 'Ver movimientos',
                onPressed: onHistory,
              ),
              if (!balanceHidden)
                ListenableBuilder(
                  listenable: AppPreferences.instance,
                  builder: (context, _) => AppPreferences.instance.readAmounts
                      ? _row(
                          AmountSpeakerButton(
                            amount: points,
                            label: 'Saldo disponible',
                            color: Colors.white,
                          ),
                          const Text(
                            'Escuchar saldo',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
