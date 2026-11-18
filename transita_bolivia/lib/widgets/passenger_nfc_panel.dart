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
    final scheme = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('nfc-card-preview'),
          padding: const EdgeInsets.all(24),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.contactless_rounded,
                    size: 38,
                    color: highContrast ? Colors.white : AppColors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Icon(
                Icons.credit_card_rounded,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'Tu pasaje, más cerca',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tarjeta de transporte recargable',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'VISTA PREVIA · SIN ACTIVAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Pago con NFC',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'El pago con NFC aún no está habilitado. Por ahora, paga tu '
                  'pasaje escaneando el QR del conductor.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'La tarjeta física deberá ser emitida y vinculada a tu '
                  'cuenta por un operador.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Cómo funcionará',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('Cuando el servicio esté disponible:'),
        const SizedBox(height: 16),
        const _NfcStep(
          icon: Icons.account_balance_wallet_outlined,
          number: '1',
          title: 'Recarga tu billetera',
          description: 'Gestiona tus puntos con el operador.',
        ),
        const _NfcStep(
          icon: Icons.payments_outlined,
          number: '2',
          title: 'Revisa el importe',
          description:
              'Confirma el monto que muestre la terminal del conductor.',
        ),
        const _NfcStep(
          icon: Icons.contactless_outlined,
          number: '3',
          title: 'Acerca tu tarjeta',
          description: 'Espera la confirmación del cobro antes de retirarla.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onPayWithQr,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('PAGAR CON QR', textAlign: TextAlign.center),
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
        const SizedBox(height: 8),
        Text(
          'Consulta sobre emisión, vinculación o pérdida de tu tarjeta.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
