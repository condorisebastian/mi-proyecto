import 'package:flutter/material.dart';

import '../models/money.dart';
import '../models/user.dart';
import '../theme.dart';

/// Acceso al escáner; el importe definitivo se confirma después de leer el QR.
class PassengerQrPanel extends StatelessWidget {
  const PassengerQrPanel({
    super.key,
    required this.user,
    required this.onScan,
    this.isProcessing = false,
  });

  final User? user;
  final VoidCallback onScan;
  final bool isProcessing;

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
          'Escanea el QR del conductor',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Revisa el importe y confirma tu pasaje desde aquí.',
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
                      Icons.qr_code_scanner_rounded,
                      size: 66,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              ElevatedButton.icon(
                key: const ValueKey('scan-driver-qr'),
                onPressed: isProcessing ? null : onScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  elevation: 0,
                ),
                icon: isProcessing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(
                  isProcessing ? 'Procesando pago…' : 'Escanear QR',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'La cámara se abre al tocar el botón.',
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
                '¿Viajan en grupo? Pide al conductor un QR con el total de '
                'los pasajes. Verás el monto antes de pagar.',
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
