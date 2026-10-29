import 'package:flutter/material.dart';

/// Colors of the concept (`spec/partizan-ui-concept.png`): red ground, black, dark grey.
abstract final class PartizanColors {
  static const red = Color(0xFFE3120B);
  static const black = Color(0xFF0B0B0B);

  /// Background of the dark screens: plain, no texture.
  static const ground = Color(0xFF1A1A1A);
  static const card = Color(0xFF262626);
  static const muted = Color(0xFF9A9A9A);
  static const white = Color(0xFFF2F2F2);
}

/// Oswald, the condensed display face: titles, the state headline. Variable font, so the
/// weight is set on its axis as well.
TextStyle oswald(
  double size, {
  int weight = 600,
  Color? color,
  double spacing = 1.5,
}) => TextStyle(
  fontFamily: 'Oswald',
  fontSize: size,
  fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  letterSpacing: spacing,
  height: 1.05,
  color: color,
);

/// Inter, the text face.
TextStyle inter(double size, {int weight = 400, Color? color}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  color: color,
);

ThemeData partizanTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PartizanColors.red,
    brightness: Brightness.dark,
    primary: PartizanColors.red,
    onPrimary: PartizanColors.white,
    surface: PartizanColors.ground,
    onSurface: PartizanColors.white,
    error: const Color(0xFFFF6B5E),
  );
  final body = TextTheme(
    displayLarge: oswald(56, weight: 700),
    displayMedium: oswald(44, weight: 700),
    displaySmall: oswald(34, weight: 700),
    headlineMedium: oswald(26),
    headlineSmall: oswald(22),
    titleLarge: oswald(20, weight: 500),
    titleMedium: inter(16, weight: 500),
    titleSmall: inter(14, weight: 500),
    bodyLarge: inter(16),
    bodyMedium: inter(14),
    bodySmall: inter(12),
    labelLarge: inter(14, weight: 600),
    labelMedium: inter(12, weight: 500),
    labelSmall: inter(11, weight: 500),
  ).apply(bodyColor: PartizanColors.white, displayColor: PartizanColors.white);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Inter',
    textTheme: body,
    scaffoldBackgroundColor: PartizanColors.ground,
    appBarTheme: AppBarTheme(
      backgroundColor: PartizanColors.ground,
      foregroundColor: PartizanColors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: oswald(22, weight: 500, color: PartizanColors.white),
    ),
    cardTheme: CardThemeData(
      color: PartizanColors.card,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: PartizanColors.card,
      shape: shape,
      iconColor: PartizanColors.white,
      titleTextStyle: inter(15, weight: 500, color: PartizanColors.white),
      subtitleTextStyle: inter(12, color: PartizanColors.muted),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(PartizanColors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? PartizanColors.red
            : const Color(0xFF555555),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? PartizanColors.red
              : PartizanColors.card,
        ),
        foregroundColor: WidgetStateProperty.all(PartizanColors.white),
        side: WidgetStateProperty.all(BorderSide.none),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PartizanColors.red,
      foregroundColor: PartizanColors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PartizanColors.red,
        foregroundColor: PartizanColors.white,
        shape: shape,
        textStyle: oswald(17, weight: 500),
        minimumSize: const Size.fromHeight(52),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PartizanColors.white,
        side: const BorderSide(color: Color(0xFF444444)),
        shape: shape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PartizanColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      hintStyle: inter(14, color: PartizanColors.muted),
      labelStyle: inter(14, color: PartizanColors.muted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PartizanColors.card,
      shape: shape,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: PartizanColors.card,
      shape: shape,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PartizanColors.card,
      contentTextStyle: inter(14, color: PartizanColors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
