import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StudentCardScreen extends StatelessWidget {
  const StudentCardScreen({super.key});
  static const assetPath = 'assets/images/student_card_updated.png';
  static const aspectRatio = 1578 / 996;
  static const imageLabel = 'Carnet estudiantil de muestra con datos ficticios';

  static void openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const StudentCardFullscreenScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi carnet')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Tu carnet, a mano',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Si el conductor te solicita el carnet, podrás mostrarlo digitalmente desde esta sección cuando esté emitido y validado.',
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.info_outline_rounded, size: 18),
                label: Text('Muestra · Datos ficticios'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('student-card-image'),
                onTap: () => openFullscreen(context),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    semanticLabel: imageLabel,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('student-card-fullscreen-button'),
              onPressed: () => openFullscreen(context),
              icon: const Icon(Icons.fullscreen_rounded),
              label: const Text('Pantalla completa'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Abre el carnet en horizontal. Puedes ampliar la imagen con dos dedos y volver con el botón de cerrar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sobre esta imagen',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'La imagen proporcionada es un ejemplo y no acredita tu identidad, vigencia ni una tarifa preferencial. Su fecha y número pertenecen a la muestra.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Antes de mostrar tu carnet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Comprueba que el nombre, la fotografía y los datos sean tuyos.\n\n• Revisa la vigencia y mantén la imagen legible.\n\n• Presenta el documento cuando el conductor lo solicite; no compartas tu PIN ni códigos de acceso.',
            ),
          ],
        ),
      ),
    ),
  );
}

class StudentCardFullscreenScreen extends StatefulWidget {
  const StudentCardFullscreenScreen({super.key});
  @override
  State<StudentCardFullscreenScreen> createState() =>
      _StudentCardFullscreenScreenState();
}

class _StudentCardFullscreenScreenState
    extends State<StudentCardFullscreenScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_enterFullscreen());
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) {
      await _restoreDisplay();
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) {
      await _restoreDisplay();
    }
  }

  Future<void> _restoreDisplay() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([]);
  }

  @override
  void dispose() {
    unawaited(_restoreDisplay());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('student-card-fullscreen'),
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, size) => RotatedBox(
            quarterTurns: size.maxWidth >= size.maxHeight ? 0 : 1,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: SizedBox.expand(
                child: Image.asset(
                  StudentCardScreen.assetPath,
                  fit: BoxFit.contain,
                  semanticLabel: StudentCardScreen.imageLabel,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: IconButton.filled(
              key: const ValueKey('student-card-fullscreen-close'),
              tooltip: 'Salir de pantalla completa',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      ],
    ),
  );
}
