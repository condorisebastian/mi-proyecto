import 'package:flutter/material.dart';
import '../../models/user.dart';
import 'profile_options_screen.dart';

class PassengerProfileScreen extends StatelessWidget {
  const PassengerProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onSupport,
  });
  final User user;
  final VoidCallback onLogout;
  final ProfileSupport onSupport;

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  size: 38,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${user.nombre} ${user.apellido}'.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(user.tipoDisplay, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              _option(
                'Mis datos',
                Icons.person_outline_rounded,
                () => open(PersonalDataScreen(user: user)),
              ),
              _option(
                'Puntos de atención',
                Icons.location_on_outlined,
                () => open(AttentionPointsScreen(onSupport: onSupport)),
              ),
              const SizedBox(height: 12),
              _option(
                'Establecer montos límites',
                Icons.tune_rounded,
                () => open(PaymentLimitScreen(userId: user.id)),
              ),
              _option(
                'Biometría digital',
                Icons.fingerprint_rounded,
                () => open(BiometricSettingsScreen(userId: user.id)),
              ),
              _option(
                'Cambiar mi clave',
                Icons.lock_reset_rounded,
                () => open(ChangeAccessScreen(onSupport: onSupport)),
              ),
              const SizedBox(height: 12),
              _option(
                'Versión de la app',
                Icons.info_outline_rounded,
                () => open(const AppVersionScreen()),
              ),
              _option(
                'Términos y condiciones',
                Icons.description_outlined,
                () => open(const LegalInformationScreen()),
              ),
              _option(
                'Política de privacidad',
                Icons.privacy_tip_outlined,
                () => open(const LegalInformationScreen(privacy: true)),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  key: const ValueKey('profile-logout'),
                  leading: Icon(Icons.logout, color: scheme.error),
                  title: Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: onLogout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(String title, IconData icon, VoidCallback action) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: action,
    ),
  );
}
