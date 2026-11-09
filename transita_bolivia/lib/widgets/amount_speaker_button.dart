import 'package:flutter/material.dart';
import '../services/amount_speech.dart';
import '../services/app_preferences.dart';

class AmountSpeakerButton extends StatelessWidget {
  const AmountSpeakerButton({
    super.key,
    required this.amount,
    this.label = 'Importe',
    this.color,
  });
  final num amount;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppPreferences.instance,
    builder: (context, _) => AppPreferences.instance.readAmounts
        ? IconButton(
            color: color,
            tooltip: 'Escuchar ${label.toLowerCase()}',
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () async {
              final ok = await AmountSpeech.instance.speak(
                amount,
                label: label,
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No hay una voz en español disponible. Revisa la salida de texto a voz del teléfono.',
                    ),
                  ),
                );
              }
            },
          )
        : const SizedBox.shrink(),
  );
}
