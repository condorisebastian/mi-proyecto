import 'package:flutter/material.dart';
import '../services/app_preferences.dart';
import '../services/amount_speech.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key, this.preferences});
  final AppPreferences? preferences;
  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  late final _preferences = widget.preferences ?? AppPreferences.instance;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _preferences.load();
  }

  @override
  void dispose() {
    AmountSpeech.instance.stop();
    super.dispose();
  }

  Future<void> _save(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el ajuste. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accesibilidad')),
    body: ListenableBuilder(
      listenable: _preferences,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ajusta Transita a tu forma de usar el teléfono. Las preferencias se guardan en este dispositivo.',
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Texto grande'),
            subtitle: const Text(
              'Amplía las letras y respeta un tamaño mayor configurado en el teléfono.',
            ),
            value: _preferences.largeText,
            onChanged: _saving
                ? null
                : (v) => _save(() => _preferences.setLargeText(v)),
          ),
          SwitchListTile(
            title: const Text('Alto contraste'),
            subtitle: const Text(
              'Refuerza el contraste de los controles, textos y bordes del tema.',
            ),
            value: _preferences.highContrast,
            onChanged: _saving
                ? null
                : (v) => _save(() => _preferences.setHighContrast(v)),
          ),
          SwitchListTile(
            title: const Text('Escuchar importes'),
            subtitle: const Text(
              'Muestra un botón de voz junto a los importes. Solo lee cuando lo pulsas.',
            ),
            value: _preferences.readAmounts,
            onChanged: _saving
                ? null
                : (v) => _save(() => _preferences.setReadAmounts(v)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('Probar lectura: Bs 3.50'),
            onPressed: () async {
              final ok = await AmountSpeech.instance.speak(
                3.50,
                label: 'Importe de ejemplo',
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Activa o instala una voz en español en los ajustes de texto a voz del teléfono.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

class AccessibilityButton extends StatelessWidget {
  const AccessibilityButton({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Accesibilidad',
    icon: Icon(Icons.accessibility_new, color: color),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AccessibilityScreen()),
    ),
  );
}
