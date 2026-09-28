import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../services/admin_auth_service.dart';
import 'incidencia_panel_screen.dart';

/// Panel admin: centro de atención (call center) + registros en vivo.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      length: 4,
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.support_agent), text: 'Atención'),
              Tab(icon: Icon(Icons.people), text: 'Usuarios'),
              Tab(icon: Icon(Icons.directions_car), text: 'Conductores'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Transacciones'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAtencionTab(),
            _buildLiveList(
              stream: FirebaseService.instance.adminUsuariosStream(),
              emptyIcon: Icons.people_outline,
              emptyText: 'No hay usuarios',
              builder: (m) => _buildClienteCard(m, esUsuario: true),
            ),
            _buildLiveList(
              stream: FirebaseService.instance.adminConductoresStream(),
              emptyIcon: Icons.directions_car_outlined,
              emptyText: 'No hay conductores',
              builder: (m) => _buildClienteCard(m, esUsuario: false),
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

  // ===================================================================
  // PESTAÑA ATENCIÓN (call center)
  // ===================================================================

  Widget _buildAtencionTab() {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _buildBuscador(),
          Expanded(child: _buildColaIncidencias()),
        ],
      ),
    );
  }

  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        onSubmitted: _buscar,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar cliente por CI, PIN o nombre...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => _buscar(_searchController.text),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _buscar(String q) async {
    if (q.trim().isEmpty) return;
    final resultados = await FirebaseService.instance.buscarClientes(q);
    if (!mounted) return;
    if (resultados.isEmpty) {
      _mostrarSnack('No se encontró ningún cliente con "$q"');
      return;
    }
    if (resultados.length == 1) {
      await _abrirPanel(cliente: resultados.first);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: resultados
            .map((r) => ListTile(
                  leading: Icon(
                    r['canal'] == 'conductor'
                        ? Icons.directions_car
                        : Icons.person,
                    color: AppColors.primary,
                  ),
                  title: Text('${r['nombre'] ?? ''} ${r['apellido'] ?? ''}'),
                  subtitle: Text(
                    '${r['canal'] == 'conductor' ? 'Conductor' : 'Pasajero'} · '
                    'CI: ${r['ci'] ?? ''} · PIN: ${r['pin'] ?? ''}',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _abrirPanel(cliente: r);
                  },
                ))
            .toList(),
      ),
    );
  }

  Widget _buildColaIncidencias() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.instance.incidenciasStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final incidencias = snapshot.data ?? [];
        if (incidencias.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mark_chat_unread,
                    size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Sin incidencias en cola',
                  style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                ),
                Text(
                  'Los reportes de pasajeros y conductores\naparecerán aquí en vivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: incidencias.length,
          itemBuilder: (context, index) =>
              _buildTicketCard(incidencias[index]),
        );
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> m) {
    const estadoColor = {
      'nueva': AppColors.primary,
      'en_curso': Colors.orange,
      'resuelta': AppColors.success,
      'cerrada': Colors.grey,
    };
    const estadoLabel = {
      'nueva': 'Nueva',
      'en_curso': 'En curso',
      'resuelta': 'Resuelta',
      'cerrada': 'Cerrada',
    };
    final estado = (m['estado'] as String?) ?? 'nueva';
    final color = estadoColor[estado] ?? Colors.grey;
    final esConductor = (m['canal'] as String?) == 'conductor';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _abrirPanel(incidencia: m),
      child: Container(
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
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  (estadoColor[estado] ?? Colors.grey).withValues(alpha: 0.15),
              child: Icon(
                esConductor ? Icons.directions_car : Icons.person_pin_circle,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['nombre'] ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_tipoLabel(m['tipo'] as String? ?? 'otro')} · '
                    '${esConductor ? 'Conductor' : 'Pasajero'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    m['descripcion'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estadoLabel[estado] ?? estado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmtFecha(m['fecha_creacion']),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirPanel({
    Map<String, dynamic>? incidencia,
    Map<String, dynamic>? cliente,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IncidenciaPanelScreen(
          incidencia: incidencia,
          cliente: cliente,
        ),
      ),
    );
  }

  String _tipoLabel(String t) => switch (t) {
        'saldo' => 'Saldo incorrecto',
        'cobro' => 'Cobro no aplicado/duplicado',
        'pin' => 'Cambiar u olvidé mi PIN',
        'dispositivo' => 'Dispositivo nuevo',
        'otro' => 'Otro problema',
        _ => t,
      };

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================================================================
  // LISTAS EN VIVO
  // ===================================================================

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

  Widget _buildClienteCard(Map<String, dynamic> m, {required bool esUsuario}) {
    final activo = (m['estado'] as String?) == 'activo';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _abrirPanel(
        cliente: {...m, 'canal': esUsuario ? 'pasajero' : 'conductor'},
      ),
      child: _wrapCard(
        m,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(
                    esUsuario ? Icons.person : Icons.directions_car,
                    color: AppColors.primaryDark,
                  ),
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
                        esUsuario
                            ? 'CI: ${m['ci'] ?? ''} · ${m['tipo'] ?? ''} · PIN: ${m['pin'] ?? ''}'
                            : 'CI: ${m['ci'] ?? ''} · Licencia: ${m['licencia'] ?? ''}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (esUsuario)
                      Text(
                        '${m['puntos'] ?? 0} pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (activo ? AppColors.success : Colors.red)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        activo ? 'ACTIVO' : 'BLOQUEADO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: activo ? AppColors.success : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
                  '· Conductor #${m['id_conductor'] ?? '-'}'
                  '${(m['nombre_pasajero'] as String? ?? '').isEmpty ? '' : ' · ${m['nombre_pasajero']}'}',
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