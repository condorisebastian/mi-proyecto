import 'package:flutter/material.dart';

import '../theme.dart';

/// Dibuja el primer fotograma antes de iniciar cualquier espera de red.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    required this.initialize,
    required this.child,
    this.onReady,
  });

  final Future<void> Function() initialize;
  final Widget child;
  final VoidCallback? onReady;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready = false;
  bool _failed = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (!mounted || _working || _ready) return;
    _working = true;
    setState(() => _failed = false);
    try {
      await widget.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _working = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return MaterialApp(
      title: 'Mi Pasaje',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_bus_rounded,
                    size: 56,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Mi Pasaje',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  if (_failed) ...[
                    const Text(
                      'No pudimos preparar la app. Inténtalo otra vez.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _initialize,
                      child: const Text('Reintentar'),
                    ),
                  ] else ...[
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 16),
                    const Text('Preparando tu viaje…'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
