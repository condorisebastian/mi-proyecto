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
  static const Color navy = Color(0xFF0D2C46);
  static const Color teal = Color(0xFF15BCC0);
  static const Color borderLight = Color(0xFFE3EAF1);
}

/// Tema central: componentes con estilo único (botones, inputs, appbar, cards).
ThemeData buildAppTheme({bool highContrast = false}) {
  final primary = highContrast ? AppColors.primaryDark : AppColors.primary;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: primary,
    secondary: AppColors.teal,
    surface: Colors.white,
    contrastLevel: highContrast ? 1 : 0,
    onSurface: highContrast ? Colors.black : null,
    outline: highContrast ? Colors.black : null,
    outlineVariant: highContrast ? Colors.black : null,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
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
      titleTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: highContrast ? Colors.black : AppColors.primaryBorder,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: highContrast ? Colors.black : AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.navy.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: highContrast
            ? const BorderSide(color: Colors.black, width: 1.5)
            : const BorderSide(color: AppColors.borderLight),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: AppColors.primary.withValues(alpha: 0.15),
    ),
  );
}
