import 'package:flutter/material.dart';

/// Paleta única de la app. Todas las pantallas deben usar estos colores;
/// nunca hardcodear hex literales.
class AppColors {
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color success = Color(0xFF4CAF50);
  static const Color background = Color(0xFFF5F7FA);
  static const Color primarySurface = Color(0xFFE3F2FD);
  static const Color primaryBorder = Color(0xFF90CAF9);
  static const Color textPrimary = Color(0xFF263238);
  static const Color textMuted = Color(0xFF78909C);
}

/// Tema central: componentes con estilo único (botones, inputs, appbar, cards).
ThemeData buildAppTheme({bool highContrast = false}) {
  final primary = highContrast ? AppColors.primaryDark : AppColors.primary;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: primary,
    secondary: AppColors.primaryDark,
    surface: Colors.white,
    contrastLevel: highContrast ? 1 : 0,
    onSurface: highContrast ? Colors.black : null,
    outline: highContrast ? Colors.black : null,
    outlineVariant: highContrast ? Colors.black : null,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: highContrast ? Colors.white : AppColors.background,
    textTheme: highContrast
        ? ThemeData.light().textTheme.apply(
            bodyColor: Colors.black,
            displayColor: Colors.black,
          )
        : null,
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: highContrast ? Colors.black : const Color(0xFFE0E0E0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: highContrast
            ? const BorderSide(color: Colors.black, width: 1.5)
            : BorderSide.none,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: AppColors.primary.withValues(alpha: 0.15),
    ),
  );
}
