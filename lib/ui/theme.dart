import 'package:flutter/material.dart';

/// Colors of the concept (`spec/partizan-ui-concept.png`): red ground, black and charcoal.
abstract final class PartizanColors {
  static const red = Color(0xFFE3120B);
  static const black = Color(0xFF0B0B0B);
  static const card = Color(0xFF1C1C1C);
  static const muted = Color(0xFF9A9A9A);
}

ThemeData partizanTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PartizanColors.red,
    brightness: Brightness.dark,
    primary: PartizanColors.red,
    surface: PartizanColors.black,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: PartizanColors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: PartizanColors.black,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: PartizanColors.card,
      margin: EdgeInsets.zero,
    ),
    listTileTheme: const ListTileThemeData(tileColor: PartizanColors.card),
  );
}
