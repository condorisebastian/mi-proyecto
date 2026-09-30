import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/firebase_service.dart';
import '../../config.dart';

const Map<String, String> _tiposInc = {
  'saldo': 'Saldo incorrecto',
  'cobro': 'Cobro no aplicado/duplicado',
  'pin': 'Cambiar u olvidé mi PIN',
  'dispositivo': 'Dispositivo nuevo',
  'otro': 'Otro problema',
};

const Map<String, Color> _estadoColor = {
  'nueva': AppColors.primary,
  'en_curso': Colors.orange,
  'resuelta': AppColors.success,
  'cerrada': Colors.grey,
};

String _estadoLabel(String e) => switch (e) {
      'nueva' => 'Nueva',
      'en_curso' => 'En curso',
      'resuelta' => 'Resuelta',
      'cerrada' => 'Cerrada',
      _ => e,
    };

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.canal,
    required this.id,
    required this.nombre,
  });

  /// 'pasajero' | 'conductor'
  final String canal;
  final int id;
  final String nombre;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _descController = TextEditingController();
  String _tipo = 'saldo';
  bool _enviando = false;

  String get _clave => widget.canal == 'conductor'
      ? 'c-${widget.id}'
      : 'p-${widget.id}';

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_descController.text.trim().length < 10) {
      _mostrarSnack('Describe el problema (mínimo 10 caracteres)');
      return;
    }
    setState(() => _enviando = true);
    final result = AppConfig.useFirebase
        ? await FirebaseService.instance.reportarIncidencia(
            canal: widget.canal,
            reportanteClave: _clave,
            nombre: widget.nombre,
            tipo: _tipo,
            descripcion: _descController.text.trim(),
          )
        : const (ok: true, message: 'Requiere modo Firebase');
    setState(() => _enviando = false);
    _mostrarSnack(result.message);
    if (result.ok) {
      _descController.clear();
      setState(() => _tipo = 'saldo');
    }
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ayuda y soporte'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reportar'),
              Tab(text: 'Mis incidencias'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReportTab(),
            _buildMisIncidencias(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Qué problema tienes?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tiposInc.entries.map((entry) {
              final selected = _tipo == entry.key;
              return ChoiceChip(
                label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _tipo = entry.key),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Descripción',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Cuéntanos qué pasó para poder ayudarte...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_enviando ? 'ENVIANDO...' : 'ENVIAR INCIDENCIA'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Un operador del centro de atención revisará tu caso y te responderá aquí.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMisIncidencias() {
    if (!AppConfig.useFirebase) {
      return const Center(
        child: Text('Requiere modo Firebase', style: TextStyle(color: Colors.grey)),
      );
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.instance.incidenciasDeUsuarioStream(_clave),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final incidencias = snapshot.data ?? [];
        if (incidencias.isEmpty) {
          return const Center(
            child: Text('Aún no has reportado incidencias',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: incidencias.length,
          itemBuilder: (context, index) {
            final inc = incidencias[index];
            final estado = inc['estado'] as String? ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _tiposInc[inc['tipo']] ?? 'Incidencia',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_estadoColor[estado] ?? Colors.grey)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _estadoLabel(estado),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _estadoColor[estado] ?? Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      inc['descripcion'] as String? ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatFechaInc(inc['fecha_creacion']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if ((inc['respuesta'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Respuesta del operador',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(inc['respuesta'] as String? ?? ''),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatFechaInc(dynamic f) {
    final d = f is Timestamp
        ? f.toDate()
        : f is DateTime
            ? f
            : null;
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}