import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config.dart';
import '../../models/money.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_api_service.dart';
import '../../services/firebase_service.dart';
import '../../theme.dart';

class DriverSummaryScreen extends StatefulWidget {
  const DriverSummaryScreen({super.key, this.firebaseService});
  final FirebaseService? firebaseService;
  @override
  State<DriverSummaryScreen> createState() => DriverSummaryScreenState();
}

class DriverSummaryScreenState extends State<DriverSummaryScreen> {
  final DriverApiService _apiService = DriverApiService();
  FirebaseService get _firebase =>
      widget.firebaseService ?? FirebaseService.instance;
  Map<String, dynamic> _summary = {};
  StreamSubscription<Map<String, dynamic>>? _liveSub;
  bool _loading = true, _failed = false;

  @override
  void initState() {
    super.initState();
    final conductor = context.read<DriverAuthService>().currentConductor;
    if (AppConfig.useFirebase && conductor != null) {
      _liveSub = _firebase
          .dailySummaryStream(conductor.id)
          .listen(
            (summary) {
              if (mounted) {
                setState(() {
                  _summary = summary;
                  _loading = false;
                  _failed = false;
                });
              }
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _failed = true;
                });
              }
            },
          );
    } else {
      _loadSummary();
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> reload() => _loadSummary();

  Future<void> _loadSummary() async {
    final conductor = context.read<DriverAuthService>().currentConductor;
    if (conductor == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final summary = AppConfig.useFirebase
          ? await _firebase.dailySummaryStream(conductor.id).first
          : await _apiService.getDailySummary(conductor.id);
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conductor = context.watch<DriverAuthService>().currentConductor;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = !_loading && !_failed;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen del día')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSummary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${now.day}/${now.month}/${now.year}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${conductor?.nombre ?? ''} ${conductor?.apellido ?? ''}'
                          .trim(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: MediaQuery.highContrastOf(context)
                            ? Colors.black
                            : AppColors.navy,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recaudación confirmada',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ready
                                ? 'Bs ${Money.format(_summary['total_puntos'] ?? 0)}'
                                : '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _loading
                                ? 'Consultando los cobros…'
                                : _failed
                                ? 'No pudimos actualizar el resumen.'
                                : 'Cobros exitosos de hoy',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      child: Column(
                        children: [
                          for (final item in const [
                            (
                              'Total de pasajeros',
                              'total_pasajeros',
                              Icons.groups_outlined,
                            ),
                            (
                              'Estudiantes',
                              'estudiantes',
                              Icons.school_outlined,
                            ),
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
                                ready ? '${_summary[item.$2] ?? 0}' : '—',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: ready ? _shareSummary : null,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Compartir resumen'),
                    ),
                    if (_failed) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadSummary,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareSummary() async {
    final conductor = context.read<DriverAuthService>().currentConductor;
    final now = DateTime.now();
    try {
      await Share.share(
        'Mi Pasaje — Resumen del ${now.day}/${now.month}/${now.year}\n'
        'Conductor: ${conductor?.nombre ?? ''} ${conductor?.apellido ?? ''}\n'
        'Viajes: ${_summary['total_pasajeros'] ?? 0}\n'
        'Recaudación: ${Money.format(_summary['total_puntos'] ?? 0)} puntos\n'
        'Estudiantes: ${_summary['estudiantes'] ?? 0}\n'
        'Civiles: ${_summary['civiles'] ?? 0}\n'
        'Adultos mayores: ${_summary['mayores'] ?? 0}\n'
        'Personas con discapacidad: ${_summary['discapacitados'] ?? 0}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el resumen.')),
      );
    }
  }
}
