import 'package:flutter/material.dart';

import '../screens/city_selection_screen.dart';
import '../services/app_preferences.dart';

class CitySelectorButton extends StatelessWidget {
  const CitySelectorButton({super.key, this.preferences, this.color});
  final AppPreferences? preferences;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final settings = preferences ?? AppPreferences.instance;
    final foreground = color ?? Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => TextButton.icon(
        key: const ValueKey('change-city'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => CitySelectionScreen(
              preferences: settings,
              onSelected: (_) => Navigator.pop(context),
            ),
          ),
        ),
        icon: const Icon(Icons.location_on_outlined, size: 17),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                settings.city ?? 'Elige tu ciudad',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: foreground.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
