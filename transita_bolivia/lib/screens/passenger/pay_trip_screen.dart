import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/passenger_nfc_panel.dart';
import '../../widgets/passenger_qr_panel.dart';
import '../soporte/support_screen.dart';
import 'passenger_qr_screen.dart';

class PayTripScreen extends StatelessWidget {
  const PayTripScreen({
    super.key,
    this.nfc = false,
    this.onPayWithQr,
    this.onSupport,
    this.embedded = false,
  });
  final bool nfc;
  final VoidCallback? onPayWithQr;
  final VoidCallback? onSupport;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(title: Text(nfc ? 'Tarjeta NFC' : 'Mi QR')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: nfc
                  ? PassengerNfcPanel(
                      onPayWithQr:
                          onPayWithQr ??
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const PayTripScreen(),
                            ),
                          ),
                      onSupport:
                          onSupport ??
                          (user == null
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
                                )),
                    )
                  : PassengerQrPanel(
                      user: user,
                      onShowQr: user == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PassengerQrScreen(userId: user.id),
                              ),
                            ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
