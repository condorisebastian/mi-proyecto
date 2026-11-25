import 'package:flutter/material.dart';

import '../theme.dart';

/// Presentación de la futura tarjeta; no representa una tarjeta emitida.
class PassengerNfcPanel extends StatelessWidget {
  const PassengerNfcPanel({
    super.key,
    required this.onPayWithQr,
    this.onSupport,
  });

  final VoidCallback onPayWithQr;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pago con NFC',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'El pago con NFC aún no está habilitado. En Con QR puedes mostrar '
          'tu identificación de prueba para el lector.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          key: const ValueKey('nfc-card-preview'),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highContrast
                  ? [Colors.black, Colors.black]
                  : [AppColors.navy, AppColors.primaryDark],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'Mi Pasaje',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.contactless_rounded,
                    size: 34,
                    color: highContrast ? Colors.white : AppColors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.credit_card_rounded,
                size: 32,
                color: Colors.white,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu tarjeta de transporte',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Paga con tus recargas',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Vista previa · Sin activar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onPayWithQr,
          style: FilledButton.styleFrom(
            backgroundColor: highContrast
                ? scheme.primary
                : AppColors.primaryDark,
            minimumSize: const Size(0, 56),
          ),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Ir a QR', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 20),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                ? AnimationStyle.noAnimation
                : null,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: const Text(
              'Cómo funcionará tu tarjeta',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            children: const [
              _NfcStep(
                icon: Icons.account_balance_wallet_outlined,
                number: '1',
                title: 'Recarga tu billetera',
                description: 'Gestiona tus puntos con el operador.',
              ),
              _NfcStep(
                icon: Icons.payments_outlined,
                number: '2',
                title: 'Revisa el importe',
                description: 'Confirma el monto en la terminal del conductor.',
              ),
              _NfcStep(
                icon: Icons.contactless_outlined,
                number: '3',
                title: 'Acerca tu tarjeta',
                description: 'Espera la confirmación antes de retirarla.',
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'La tarjeta física deberá ser emitida y vinculada a tu '
                  'cuenta por un operador cuando el servicio esté disponible.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('nfc-support'),
          onPressed: onSupport,
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text(
            'Ayuda con mi tarjeta',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Consulta sobre emisión, vinculación o pérdida de tu tarjeta.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NfcStep extends StatelessWidget {
  const _NfcStep({
    required this.icon,
    required this.number,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. $title',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
