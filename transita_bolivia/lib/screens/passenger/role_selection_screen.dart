import 'package:flutter/material.dart';

import '../../theme.dart';
import 'welcome_information_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
  static const backgroundAsset = 'assets/images/fondo.png';

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.navy),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: highContrast
                    ? [Colors.black.withValues(alpha: .8), Colors.black]
                    : [
                        AppColors.navy.withValues(alpha: .15),
                        AppColors.navy.withValues(alpha: .45),
                        AppColors.navy.withValues(alpha: .97),
                      ],
                stops: highContrast ? null : const [0, .4, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Mi Pasaje',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _WelcomeAction(
                              icon: Icons.help_outline_rounded,
                              label: 'Ayuda',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const WelcomeInformationScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _WelcomeAction(
                              icon: Icons.location_on_outlined,
                              label: 'Ubicación y cobertura',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const WelcomeInformationScreen(
                                        location: true,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: (constraints.maxHeight * .16).clamp(64, 150),
                        ),
                        const Text(
                          '¿Cómo usarás Mi Pasaje?',
                          style: TextStyle(
                            fontSize: 32,
                            height: 1.15,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Elige tu perfil para continuar.',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 28),
                        _WelcomeRole(
                          icon: Icons.person_outline_rounded,
                          title: 'Viajero / Pasajero',
                          subtitle: 'Tu billetera y tus viajes',
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/passenger/type',
                            arguments: {'role': 'passenger'},
                          ),
                        ),
                        const SizedBox(height: 14),
                        _WelcomeRole(
                          icon: Icons.directions_bus_rounded,
                          title: 'Conductor',
                          subtitle: 'Administra tus cobros del día',
                          onTap: () =>
                              Navigator.pushNamed(context, '/driver/login'),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/passenger/requirements',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            side: const BorderSide(color: Colors.white70),
                          ),
                          icon: const Icon(Icons.assignment_outlined),
                          label: const Text(
                            'Requisitos para el registro',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeAction extends StatelessWidget {
  const _WelcomeAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: .16),
      minimumSize: const Size(48, 48),
    ),
  );
}

class _WelcomeRole extends StatelessWidget {
  const _WelcomeRole({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, color: scheme.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
