import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/firebase_service.dart';

const Map<String, String> _tiposInc = {
  'saldo': 'Saldo incorrecto',
  'cobro': 'Cobro no aplicado/duplicado',
  'pin': 'Cambiar u olvidé mi PIN',
  'dispositivo': 'Dispositivo nuevo',
  'otro': 'Otro problema',
};

const Map<String, String> _estados = {
  'nueva': 'Nueva',
  'en_curso': 'En curso',
  'resuelta': 'Resuelta',
  'cerrada': 'Cerrada',
};

const Map<String, Color> _estadoColor = {
  'nueva': AppColors.primary,
  'en_curso': Colors.orange,
  'resuelta': AppColors.success,
  'cerrada': Colors.grey,
};

class IncidenciaPanelScreen extends StatefulWidget {
  const IncidenciaPanelScreen({
    super.key,
    this.incidencia,
    this.cliente,
  });

  /// Ticket de la cola (mapa con `docId`).
  final Map<String, dynamic>? incidencia;

  /// Cliente ya conocido (resultado de búsqueda o lista).
  final Map<String, dynamic>? cliente;

  @override
  State<IncidenciaPanelScreen> createState() => _IncidenciaPanelScreenState();
}

class _IncidenciaPanelScreenState extends State<IncidenciaPanelScreen> {
  Map<String, dynamic>? _cliente;
  bool _esUsuario = true;
  String _estadoTicket = 'nueva';
  final _respuestaController = TextEditingController();
  final _notaController = TextEditingController();

  bool get _esConductor => !_esUsuario;

  @override
  void initState() {
    super.initState();
    if (widget.incidencia != null) {
      _estadoTicket = (widget.incidencia!['estado'] as String?) ?? 'nueva';
      _respuestaController.text =
          (widget.incidencia!['respuesta'] as String?) ?? '';
    }
    _cargarCliente();
  }

  @override
  void dispose() {
    _respuestaController.dispose();
    _notaController.dispose();
    super.dispose();
  }

  Future<void> _cargarCliente() async {
    Map<String, dynamic>? cliente;
    bool esUsuario = true;
    final inc = widget.incidencia;

    if (widget.cliente != null) {
      cliente = widget.cliente!;
      esUsuario = (cliente['canal'] as String? ?? 'pasajero') != 'conductor';
    } else if (inc != null) {
      esUsuario = (inc['canal'] as String? ?? 'pasajero') != 'conductor';
      final clave = inc['reportante_clave'] as String? ?? '';
      final id = int.tryParse(clave.replaceAll(RegExp(r'[^0-9]'), ''));
      if (id != null) {
        cliente = await FirebaseService.instance.fetchClienteDoc(esUsuario, id);
      }
    }
    if (!mounted) return;
    setState(() {
      _cliente = cliente;
      _esUsuario = esUsuario;
    });
  }

  Future<void> _guardarTicket() async {
    final inc = widget.incidencia;
    if (inc == null) return;
    final accion = 'Operador ${_estados[_estadoTicket] ?? _estadoTicket}';
    await _aplicarAccionTicket(accion);
    await FirebaseService.instance.actualizarIncidencia(inc['docId'] as String, {
      'estado': _estadoTicket,
      'respuesta': _respuestaController.text.trim(),
      if (_estadoTicket == 'resuelta' || _estadoTicket == 'cerrada')
        'fecha_resolucion': DateTime.now().toUtc(),
    });
    _mostrarSnack('Ticket actualizado');
  }

  Future<void> _agregarNota() async {
    final inc = widget.incidencia;
    final texto = _notaController.text.trim();
    if (inc == null || texto.isEmpty) return;
    final notas =
        List<Map<String, dynamic>>.from(inc['notas'] as List? ?? []);
    notas.add({
      'autor': 'Operador',
      'texto': texto,
      'fecha': DateTime.now().toUtc().toIso8601String(),
    });
    await FirebaseService.instance.actualizarIncidencia(inc['docId'] as String, {
      'notas': notas,
    });
    if (!mounted) return;
    _mostrarSnack('Nota guardada');
    Navigator.pop(context);
  }

  Future<void> _aplicarAccionTicket(String accion) async {
    final inc = widget.incidencia;
    if (inc == null) return;
    final acciones =
        List<Map<String, dynamic>>.from(inc['acciones'] as List? ?? []);
    acciones.add({
      'accion': accion,
      'fecha': DateTime.now().toUtc().toIso8601String(),
    });
    await FirebaseService.instance
        .actualizarIncidencia(inc['docId'] as String, {'acciones': acciones});
  }

  Future<void> _toggleBloqueo() async {
    final nuevo = (_cliente?['estado'] as String? ?? 'activo') == 'activo'
        ? 'inactivo'
        : 'activo';
    final result = _esConductor
        ? await FirebaseService.instance
            .setConductorEstado(_idCliente(), nuevo)
        : await FirebaseService.instance.setUsuarioEstado(_idCliente(), nuevo);
    if (result.ok) {
      await _aplicarAccionTicket(nuevo == 'activo'
          ? 'Cliente desbloqueado'
          : 'Cliente bloqueado');
      await _reloadCliente();
    }
    _mostrarSnack(result.message);
  }

  Future<void> _regenerarPin() async {
    final pin = _esConductor
        ? await FirebaseService.instance.regenerarPinConductor(_idCliente())
        : await FirebaseService.instance.regenerarPinUsuario(_idCliente());
    if (pin == null) {
      _mostrarSnack('No se pudo regenerar el PIN');
      return;
    }
    await _aplicarAccionTicket('PIN regenerado: $pin');
    _mostrarDialog('PIN regenerado', 'El nuevo PIN del cliente es: $pin');
  }

  Future<void> _recargaManual() async {
    if (_esConductor) return;
    final controller = TextEditingController();
    final monto = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recarga manual'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad de puntos (Bs)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0),
            child: const Text('RECARGAR'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (monto == null || monto <= 0) return;
    await FirebaseService.instance.recargar(
      userId: _idCliente(),
      puntos: monto,
      metodoPago: 'manual_admin',
    );
    await _aplicarAccionTicket('Recarga manual de $monto pts');
    await _reloadCliente();
    _mostrarSnack('Recarga de $monto pts aplicada');
  }

  Future<void> _cambiarTipo() async {
    if (_esConductor) return;
    final tipos = {
      'estudiante': 'Estudiante',
      'civil': 'Civil',
      'adulto_mayor': 'Adulto mayor',
      'discapacitado': 'Discapacitado',
    };
    final actual = (_cliente?['tipo'] as String?) ?? 'civil';
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Cambiar tipo de pasajero'),
        children: tipos.entries
            .map(
              (e) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, e.key),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: e.key == actual
                          ? const Icon(Icons.check_circle,
                              color: AppColors.primary, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(e.value),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (nuevo == null || nuevo == actual) return;
    final ok = await FirebaseService.instance.cambiarTipoUsuario(_idCliente(), nuevo);
    if (ok.ok) {
      await _aplicarAccionTicket('Tipo cambiado a $nuevo');
      await _reloadCliente();
      _mostrarSnack('Tipo actualizado a ${tipos[nuevo]}');
    } else {
      _mostrarSnack(ok.message);
    }
  }

  int _idCliente() {
    final id = (_cliente?['id'] as num?)?.toInt();
    return id ?? int.tryParse(((_cliente?['docId'] as String?) ?? '')
            .replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
  }

  Future<void> _reloadCliente() async {
    final c = await FirebaseService.instance
        .fetchClienteDoc(_esUsuario, _idCliente());
    if (c != null && mounted) {
      setState(() => _cliente = c);
    }
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _mostrarDialog(String titulo, String cuerpo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(cuerpo),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atención al cliente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.incidencia != null)
            _buildTicketCard(widget.incidencia!),
          if (_cliente != null) _buildClienteCard(),
          _buildAcciones(),
          if (widget.incidencia != null) _buildBitacora(widget.incidencia!),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> inc) {
    final estado = (inc['estado'] as String?) ?? 'nueva';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_estadoColor[estado] ?? Colors.grey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _estados[estado] ?? estado,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _estadoColor[estado] ?? Colors.grey,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatFechaInc(inc['fecha_creacion']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _tiposInc[inc['tipo']] ?? 'Incidencia',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(inc['descripcion'] as String? ?? ''),
            const SizedBox(height: 14),
            const Text('Estado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _estadoTicket,
              items: _estados.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _estadoTicket = v);
              },
            ),
            const SizedBox(height: 14),
            const Text('Respuesta al cliente',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _respuestaController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Escribe la respuesta que verá el cliente...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardarTicket,
                child: const Text('GUARDAR TICKET'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteCard() {
    final c = _cliente!;
    final estado = (c['estado'] as String?) ?? 'activo';
    final activo = estado == 'activo';
    final idCliente = (c['id'] as num?)?.toInt() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (activo ? AppColors.success : Colors.red)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    activo ? 'ACTIVO' : 'BLOQUEADO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: activo ? AppColors.success : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _fila('ID', idCliente > 0 ? '#$idCliente' : '—'),
            _fila('Canal', _esConductor ? 'Conductor' : 'Pasajero'),
            _fila('CI', (c['ci'] as String? ?? '').isEmpty ? '—' : c['ci']),
            if (!_esConductor) ...[
              _fila('Tipo', _tipoLabel(c['tipo'] as String? ?? 'civil')),
              _fila('Puntos', '${c['puntos'] ?? 0}'),
            ] else
              _fila('Licencia', c['licencia'] ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(etiqueta,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text('$valor',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildAcciones() {
    final c = _cliente;
    if (c == null) return const SizedBox.shrink();
    final activo = (c['estado'] as String?) == 'activo';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Acciones del operador',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _botonAccion(
              icon: activo ? Icons.block : Icons.lock_open,
              color: activo ? Colors.red : AppColors.success,
              label: activo ? 'Bloquear cuenta' : 'Desbloquear cuenta',
              onTap: _toggleBloqueo,
            ),
            _botonAccion(
              icon: Icons.refresh,
              color: AppColors.primary,
              label: 'Regenerar PIN',
              onTap: _regenerarPin,
            ),
            if (!_esConductor) ...[
              _botonAccion(
                icon: Icons.add_card,
                color: AppColors.success,
                label: 'Recarga manual',
                onTap: _recargaManual,
              ),
              _botonAccion(
                icon: Icons.swap_horiz,
                color: Colors.orange,
                label: 'Cambiar tipo',
                onTap: _cambiarTipo,
              ),
            ],
            if (widget.incidencia != null) ...[
              const SizedBox(height: 8),
              const Text('Nota de seguimiento',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _notaController,
                decoration: const InputDecoration(
                  hintText: 'Nota interna para el ticket...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _agregarNota,
                  icon: const Icon(Icons.note_add),
                  label: const Text('AGREGAR NOTA'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _botonAccion({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        dense: true,
        leading: Icon(icon, color: color),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildBitacora(Map<String, dynamic> inc) {
    final notas = List<Map<String, dynamic>>.from(inc['notas'] as List? ?? []);
    final acciones =
        List<Map<String, dynamic>>.from(inc['acciones'] as List? ?? []);
    if (notas.isEmpty && acciones.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Sin actividad aún.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    final items = <Widget>[];
    for (final a in acciones) {
      items.add(ListTile(
        dense: true,
        leading: const Icon(Icons.history, color: AppColors.primary, size: 20),
        title: Text(a['accion'] as String? ?? ''),
        subtitle: Text(_formatIso(a['fecha']),
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ));
    }
    for (final n in notas) {
      items.add(ListTile(
        dense: true,
        leading: const Icon(Icons.sticky_note_2, color: Colors.orange, size: 20),
        title: Text('${n['autor'] ?? ''}: ${n['texto'] ?? ''}'),
        subtitle: Text(_formatIso(n['fecha']),
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Bitácora',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            ...items,
          ],
        ),
      ),
    );
  }

  String _formatFechaInc(dynamic f) {
    final d = f is Timestamp
        ? f.toDate()
        : f is DateTime
            ? f
            : null;
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatIso(dynamic v) {
    final d = DateTime.tryParse(v ?? '');
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _tipoLabel(String t) => switch (t) {
        'estudiante' => 'Estudiante',
        'civil' => 'Civil',
        'adulto_mayor' => 'Adulto mayor',
        'discapacitado' => 'Discapacitado',
        _ => t,
      };
}