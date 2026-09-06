import 'package:flutter/material.dart';

/// Paleta de marca Livora, tomada del logo oficial.
class LivoraColors {
  LivoraColors._();

  static const deep = Color(0xFF003B2B);
  static const forest = Color(0xFF006852);
  static const green = Color(0xFF00A878);
  static const mint = Color(0xFF00E5A3);
  static const cyan = Color(0xFF00B4D8);
  static const blue = Color(0xFF0077B6);
  static const ink = Color(0xFF44515A);
  static const slate = Color(0xFF44515A);
  static const paper = Color(0xFFF4FAF7);
  static const amber = Color(0xFFF59E0B);
  static const coral = Color(0xFFEF4444);
  static const gold = Color(0xFFEAB308);
  static const border = Color(0xFFE2E8F0);

  static const brandGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [forest, green, cyan, blue],
  );
}

extension ColorValuesCompat on Color {
  Color withValues({double? alpha, double? red, double? green, double? blue}) {
    if (alpha != null) {
      return withOpacity(alpha.clamp(0.0, 1.0));
    }
    return this;
  }
}

/// Decoración estándar para campos de texto de la app.
InputDecoration livoraInput(
  String label, {
  String? hint,
  IconData? icon,
  Widget? suffix,
  String? helper,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 3,
    prefixIcon: icon != null ? Icon(icon) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    border: border(LivoraColors.deep.withValues(alpha: 0.15)),
    enabledBorder: border(LivoraColors.deep.withValues(alpha: 0.15)),
    focusedBorder: border(LivoraColors.forest, 1.6),
  );
}

class LivoraTheme {
  LivoraTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: LivoraColors.forest,
    ).copyWith(
      primary: LivoraColors.forest,
      secondary: LivoraColors.blue,
      tertiary: LivoraColors.mint,
      surface: Colors.white,
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: LivoraColors.paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: LivoraColors.paper,
        foregroundColor: LivoraColors.deep,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: LivoraColors.deep,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: LivoraColors.deep.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LivoraColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LivoraColors.forest,
          side: const BorderSide(color: LivoraColors.forest),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LivoraColors.blue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: LivoraColors.forest,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: LivoraColors.mint.withValues(alpha: 0.28),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? LivoraColors.deep
                : LivoraColors.ink,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? LivoraColors.deep
                : LivoraColors.ink,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LivoraColors.deep,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
