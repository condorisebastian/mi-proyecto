import 'package:flutter/material.dart';

import '../models/money.dart';
import '../models/user.dart';
import '../theme.dart';

/// Presentación del QR del pasajero para la prueba del lector.
class PassengerQrPanel extends StatelessWidget {
  const PassengerQrPanel({
    super.key,
    required this.user,
    this.isProcessing = false,
    this.onShowQr,
  });

  final User? user;
  final bool isProcessing;
  final VoidCallback? onShowQr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actionColor = MediaQuery.highContrastOf(context)
        ? scheme.primary
        : AppColors.primaryDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tu QR de pasajero',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Presenta tu código frente al lector ESP32-CAM.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 112,
                    height: 112,
                    margin: const EdgeInsets.only(top: 4, bottom: 20),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      size: 66,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              ElevatedButton.icon(
                key: const ValueKey('show-passenger-qr'),
                onPressed: isProcessing ? null : onShowQr,
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(0, 56),
                  elevation: 0,
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Mostrar mi QR', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 14),
              Text(
                'Cada código dura 15 segundos. Podrás generar otro al vencer.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1),
              ),
              _PaymentDetail(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Saldo disponible',
                value: user == null
                    ? 'Inicia sesión para ver tu saldo'
                    : '${Money.format(user!.puntos)} puntos',
              ),
              if (user != null) ...[
                const SizedBox(height: 18),
                _PaymentDetail(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Tarifa individual · ${user!.tipoDisplay}',
                  value: '${Money.format(user!.costoViaje)} puntos',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.groups_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Para un pago en grupo, la terminal deberá mostrar el total de '
                'los pasajes antes de confirmar el cobro.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentDetail extends StatelessWidget {
  const _PaymentDetail({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: theme.colorScheme.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
