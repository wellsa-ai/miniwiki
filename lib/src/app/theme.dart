import 'package:flutter/material.dart';

class MiniWikiTheme {
  MiniWikiTheme._();

  static const _seedColor = Color(0xFF2E7353);

  static final light = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seedColor,
    brightness: Brightness.light,
    fontFamily: 'Pretendard',
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seedColor,
    brightness: Brightness.dark,
    fontFamily: 'Pretendard',
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),
  );
}
