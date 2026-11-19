import 'package:flutter/material.dart';

class StudentCardScreen extends StatelessWidget {
  const StudentCardScreen({super.key});
  static const assetPath = 'assets/images/carnetstudiantefrontal.png';

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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Carnet de muestra')),
                      body: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1.586,
                            child: Image.asset(
                              assetPath,
                              fit: BoxFit.contain,
                              semanticLabel:
                                  'Carnet estudiantil de muestra con datos ficticios',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: AspectRatio(
                  aspectRatio: 1.586,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    semanticLabel:
                        'Carnet estudiantil de muestra con datos ficticios',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca la imagen para ampliarla.',
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
