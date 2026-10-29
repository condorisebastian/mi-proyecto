import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/money.dart';
import '../soporte/support_screen.dart';

class NfcCardScreen extends StatelessWidget {
  const NfcCardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi tarjeta NFC')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.contactless, size: 48),
                      const SizedBox(height: 24),
                      const Text(
                        'TRANSITA BOLIVIA',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Tarjeta de transporte con saldo recargable'),
                      const SizedBox(height: 24),
                      Text(
                        'Saldo de tu cuenta: Bs ${Money.format(user?.puntos ?? 0)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Recarga tu saldo desde el chat. El conductor introduce el importe en su terminal y tú acercas tu tarjeta. '
                'El cobro aprobado se descuenta de ese mismo saldo.',
              ),
              const SizedBox(height: 16),
              const Text(
                'La emisión y vinculación de la tarjeta física debe realizarla el operador. '
                'Esta pantalla no acredita que ya tengas una tarjeta emitida.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: user == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SupportScreen(
                            canal: 'pasajero',
                            id: user.id,
                            nombre: '${user.nombre} ${user.apellido}',
                          ),
                        ),
                      ),
                icon: const Icon(Icons.support_agent),
                label: const Text('SOLICITAR TARJETA / REPORTAR PÉRDIDA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
