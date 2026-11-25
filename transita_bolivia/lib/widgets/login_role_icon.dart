import 'package:flutter/material.dart';

class LoginRoleIcon extends StatelessWidget {
  const LoginRoleIcon({super.key, required this.role});
  final String role;

  static IconData iconFor(String role) => switch (role) {
    'estudiante' => Icons.school_rounded,
    'civil' => Icons.person_rounded,
    'adulto_mayor' => Icons.elderly_rounded,
    'discapacitado' => Icons.accessible_rounded,
    'conductor' => Icons.directions_bus_rounded,
    _ => Icons.person_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = switch (role) {
      'estudiante' => 'Estudiante',
      'civil' => 'Civil',
      'adulto_mayor' => 'Adulto mayor',
      'discapacitado' => 'Persona con discapacidad',
      'conductor' => 'Conductor',
      _ => 'Usuario',
    };
    return Semantics(
      label: 'Acceso: $label',
      image: true,
      child: CircleAvatar(
        radius: 42,
        backgroundColor: scheme.primaryContainer,
        child: Icon(
          iconFor(role),
          key: ValueKey('login-role-$role'),
          size: 44,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
