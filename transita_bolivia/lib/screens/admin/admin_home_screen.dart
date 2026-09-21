import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../services/admin_auth_service.dart';

/// Panel admin con los registros (usuarios, conductores y transacciones)
/// actualizándose en tiempo real mientras ocurren.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Future<void> _logout() async {
    final auth = Provider.of<AdminAuthService>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminAuthService>(context).currentAdmin;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel Admin'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Usuarios'),
              Tab(icon: Icon(Icons.directions_car), text: 'Conductores'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Transacciones'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLiveList(
              stream: FirebaseService.instance.adminUsuariosStream(),
              emptyIcon: Icons.people_outline,
              emptyText: 'No hay usuarios',
              builder: (m) => _buildUsuarioCard(m),
            ),
            _buildLiveList(
              stream: FirebaseService.instance.adminConductoresStream(),
              emptyIcon: Icons.directions_car_outlined,
              emptyText: 'No hay conductores',
              builder: (m) => _buildConductorCard(m),
            ),
            _buildLiveList(
              stream: FirebaseService.instance.adminTransaccionesStream(),
              emptyIcon: Icons.receipt_long,
              emptyText: 'No hay transacciones',
              builder: (m) => _buildTransaccionCard(m),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Sesión activa: ${admin?.nombre ?? 'Administrador'} '
              '(${admin?.id ?? '-'})',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveList({
    required Stream<List<Map<String, dynamic>>> stream,
    required String emptyText,
    required IconData emptyIcon,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    return Container(
      color: AppColors.background,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(emptyIcon, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    emptyText,
                    style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => builder(items[index]),
          );
        },
      ),
    );
  }

  Widget _wrapCard(Map<String, dynamic> m, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildUsuarioCard(Map<String, dynamic> m) {
    return _wrapCard(
      m,
      Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primarySurface,
            child: Icon(Icons.person, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m['nombre'] ?? ''} ${m['apellido'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'CI: ${m['ci'] ?? ''} · ${m['tipo'] ?? ''} · PIN: ${m['pin'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${m['puntos'] ?? 0} pts',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${m['rol'] ?? ''}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConductorCard(Map<String, dynamic> m) {
    return _wrapCard(
      m,
      Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primarySurface,
            child: Icon(Icons.directions_car, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m['nombre'] ?? ''} ${m['apellido'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'CI: ${m['ci'] ?? ''} · Licencia: ${m['licencia'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            'PIN: ${m['pin'] ?? ''}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransaccionCard(Map<String, dynamic> m) {
    final esRecarga = m['tipo'] == 'recarga';
    return _wrapCard(
      m,
      Row(
        children: [
          CircleAvatar(
            backgroundColor: esRecarga
                ? AppColors.success.withValues(alpha: 0.15)
                : Colors.orange.withValues(alpha: 0.15),
            child: Icon(
              esRecarga ? Icons.add : Icons.remove,
              color: esRecarga ? AppColors.success : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esRecarga ? 'Recarga' : 'Viaje',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_fmtFecha(m['fecha'])} · Usuario #${m['id_usuario'] ?? '-'} '
                  '· Conductor #${m['id_conductor'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${esRecarga ? '+' : '-'}${m['puntos'] ?? 0} pts',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: esRecarga ? AppColors.success : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtFecha(dynamic fecha) {
    if (fecha is Timestamp) {
      final d = fecha.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}