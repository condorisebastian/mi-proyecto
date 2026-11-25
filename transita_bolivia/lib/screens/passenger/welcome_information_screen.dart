import 'package:flutter/material.dart';
import '../province_routes_screen.dart';

/// Información pública; el soporte personal continúa dentro de la sesión.
class WelcomeInformationScreen extends StatelessWidget {
  const WelcomeInformationScreen({super.key, this.location = false});
  final bool location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(location ? 'Ubicación y cobertura' : 'Ayuda')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      location
                          ? Icons.location_on_outlined
                          : Icons.support_agent_rounded,
                      size: 30,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  location
                      ? 'Santa Cruz de la Sierra'
                      : 'Te ayudamos a empezar',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  location
                      ? 'El catálogo de Mi Pasaje reúne rutas con salida desde esta '
                            'ciudad. Consulta los destinos y su información de referencia.'
                      : 'Elige Pasajero si usarás tu billetera, o Conductor si '
                            'administrarás los cobros de tus viajes.',
                ),
                const SizedBox(height: 20),
                Text(
                  location ? 'Información de referencia' : 'Tu acceso',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  location
                      ? 'Las tarifas provinciales siguen por verificar. Esta pantalla '
                            'no consulta el GPS ni muestra tu ubicación en tiempo real.'
                      : 'Los pasajeros eligen su categoría e ingresan con su PIN de '
                            '4 dígitos. Para recuperar el acceso, solicita apoyo al operador '
                            'que administra tu cuenta.',
                ),
                const SizedBox(height: 20),
                if (!location) ...[
                  Text(
                    'Atención personal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Después de ingresar, el icono de ayuda abre el centro '
                    'de atención con la identidad de tu cuenta.',
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => location
                      ? Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const ProvinceRoutesScreen(title: 'Rutas'),
                          ),
                        )
                      : Navigator.pushNamed(context, '/passenger/requirements'),
                  icon: Icon(
                    location
                        ? Icons.alt_route_rounded
                        : Icons.assignment_outlined,
                  ),
                  label: Text(location ? 'Consultar rutas' : 'Ver requisitos'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
