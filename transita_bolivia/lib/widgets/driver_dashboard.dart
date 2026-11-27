import 'package:flutter/material.dart';
import '../models/conductor.dart';
import '../models/money.dart';
import '../theme.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({
    super.key,
    required this.conductor,
    required this.summary,
    required this.loading,
    required this.failed,
    required this.onCharge,
    required this.onSummary,
    required this.onChat,
    required this.onSupport,
    required this.onLogout,
    required this.onAccessibility,
    required this.onRefresh,
  });
  final Conductor conductor;
  final Map<String, dynamic> summary;
  final bool loading, failed;
  final VoidCallback onCharge,
      onSummary,
      onChat,
      onSupport,
      onLogout,
      onAccessibility,
      onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = !loading && !failed;
    final total = ready ? Money.format(summary['total_puntos'] ?? 0) : '—';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.directions_bus_rounded,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, ${conductor.nombre}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Panel del conductor',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ayuda del conductor',
                      onPressed: onSupport,
                      icon: const Icon(Icons.support_agent_rounded),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Opciones del conductor',
                      onSelected: (value) =>
                          value == 'logout' ? onLogout() : onAccessibility(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'accessibility',
                          child: Text('Accesibilidad'),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: MediaQuery.highContrastOf(context)
                          ? [Colors.black, Colors.black]
                          : [AppColors.navy, AppColors.primaryDark],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white70,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Recaudación de hoy',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        ready ? 'Bs $total' : total,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loading
                            ? 'Consultando los cobros…'
                            : failed
                            ? 'No se pudo actualizar la recaudación.'
                            : '${summary['total_pasajeros'] ?? 0} pasajes confirmados',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('driver-primary-charge'),
                  onPressed: onCharge,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    minimumSize: const Size(0, 60),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text(
                    'Cobrar pasajes',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Prepara la categoría, la cantidad de pasajes o un monto acordado.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                const SizedBox(height: 24),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.insights_rounded,
                          color: scheme.primary,
                        ),
                        title: const Text('Resumen del día'),
                        subtitle: const Text(
                          'Revisa y comparte tus resultados',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: onSummary,
                      ),
                      const Divider(height: 1, indent: 64, endIndent: 16),
                      ListTile(
                        leading: Icon(
                          Icons.forum_outlined,
                          color: scheme.primary,
                        ),
                        title: const Text('Chat de retiros'),
                        subtitle: const Text('Coordina con el operador'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: onChat,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pasajes por categoría',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  child: Column(
                    children: [
                      for (final item in const [
                        ('Estudiantes', 'estudiantes', Icons.school_outlined),
                        ('Civiles', 'civiles', Icons.person_outline),
                        ('Adultos mayores', 'mayores', Icons.elderly),
                        (
                          'Personas con discapacidad',
                          'discapacitados',
                          Icons.accessible,
                        ),
                      ])
                        ListTile(
                          leading: Icon(item.$3, color: scheme.primary),
                          title: Text(item.$1),
                          trailing: Text(
                            ready ? '${summary[item.$2] ?? 0}' : '—',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  child: ExpansionTile(
                    title: const Text('Datos del conductor'),
                    leading: const Icon(Icons.badge_outlined),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('ID: #${conductor.id}'),
                      const SizedBox(height: 8),
                      Text('Licencia: ${conductor.licencia}'),
                      const SizedBox(height: 8),
                      Text('CI: ${conductor.ci.isEmpty ? '—' : conductor.ci}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
