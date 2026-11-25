import 'package:flutter/material.dart';

import '../../models/user.dart';
import 'profile_options_screen.dart';
import 'profile_photo_screen.dart';
import '../../widgets/profile_photo_avatar.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Cambiar foto de perfil',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => open(ProfilePhotoScreen(userId: user.id)),
                        child: ProfilePhotoAvatar(userId: user.id),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user.nombre} ${user.apellido}'.trim(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.tipoDisplay,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ProfileGroup(
                title: 'Tu cuenta',
                children: [
                  _ProfileOption(
                    title: 'Mis datos',
                    icon: Icons.person_outline_rounded,
                    onTap: () => open(PersonalDataScreen(user: user)),
                  ),
                  _ProfileOption(
                    title: 'Foto de perfil',
                    icon: Icons.add_a_photo_outlined,
                    onTap: () => open(ProfilePhotoScreen(userId: user.id)),
                  ),
                  _ProfileOption(
                    title: 'Puntos de atención',
                    icon: Icons.support_agent_rounded,
                    onTap: () =>
                        open(AttentionPointsScreen(onSupport: onSupport)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfileGroup(
                title: 'Pagos y acceso',
                children: [
                  _ProfileOption(
                    title: 'Establecer montos límites',
                    icon: Icons.tune_rounded,
                    onTap: () => open(PaymentLimitScreen(userId: user.id)),
                  ),
                  _ProfileOption(
                    title: 'Cambiar mi clave',
                    icon: Icons.lock_reset_rounded,
                    onTap: () => open(ChangeAccessScreen(onSupport: onSupport)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfileGroup(
                title: 'Acerca de Mi Pasaje',
                children: [
                  _ProfileOption(
                    title: 'Versión de la app',
                    icon: Icons.info_outline_rounded,
                    onTap: () => open(const AppVersionScreen()),
                  ),
                  _ProfileOption(
                    title: 'Términos y condiciones',
                    icon: Icons.description_outlined,
                    onTap: () => open(const LegalInformationScreen()),
                  ),
                  _ProfileOption(
                    title: 'Política de privacidad',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () =>
                        open(const LegalInformationScreen(privacy: true)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const ValueKey('profile-logout'),
                onPressed: onLogout,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  foregroundColor: scheme.error,
                  backgroundColor: scheme.surface,
                  side: BorderSide(color: scheme.error),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, indent: 72, endIndent: 16),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: scheme.primaryContainer,
        child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
        size: 22,
      ),
      onTap: onTap,
    );
  }
}
