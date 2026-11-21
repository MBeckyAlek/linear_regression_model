// Light and dark colours from the Electra design.

import 'package:flutter/material.dart';

const _yellow = Color(0xFFFFC629);
const _navy = Color(0xFF0B1530);

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.header,
    required this.divider,
    required this.card,
    required this.cardBorder,
    required this.inputFill,
    required this.inputBorder,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.price,
    required this.buttonBorder,
    required this.segmentFill,
    required this.errorFill,
    required this.errorBorder,
    required this.errorText,
    required this.logoFill,
  });

  final Color background, header, divider, card, cardBorder, inputFill, inputBorder, text, muted;
  final Color accent, onAccent, price, buttonBorder, segmentFill;
  final Color errorFill, errorBorder, errorText, logoFill;

  static const dark = AppColors(
    background: Color(0xFF000000),
    header: Color(0xFF000000),
    divider: Color(0xFF1C2A4A),
    card: Color(0xFF0A1735),
    cardBorder: Color(0xFF1E2F57),
    inputFill: Color(0xFF12224A),
    inputBorder: Color(0xFF2A3D6B),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFFA9B5CF),
    accent: _yellow,
    onAccent: _navy,
    price: _yellow,
    buttonBorder: Colors.transparent,
    segmentFill: Color(0xFF07112A),
    errorFill: Color(0xFF2B1216),
    errorBorder: Color(0xFFF28B7D),
    errorText: Color(0xFFF4A397),
    logoFill: Color(0xFF12224A),
  );

  static const light = AppColors(
    background: Color(0xFFF3F5FA),
    header: Color(0xFFFFFFFF),
    divider: Color(0xFFE1E5EF),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE1E5EF),
    inputFill: Color(0xFFF3F5FA),
    inputBorder: Color(0xFFCDD3E3),
    text: _navy,
    muted: Color(0xFF5B6681),
    accent: _yellow,
    onAccent: _navy,
    price: _navy,
    buttonBorder: _navy,
    segmentFill: Color(0xFFE6EAF3),
    errorFill: Color(0xFFFDECEC),
    errorBorder: Color(0xFFB3261E),
    errorText: Color(0xFFA31B14),
    logoFill: _navy,
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _yellow,
      brightness: brightness,
      primary: _yellow,
      onPrimary: _navy,
      surface: c.card,
      onSurface: c.text,
      error: c.errorBorder,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.text,
      selectionColor: _yellow.withValues(alpha: 0.4),
      selectionHandleColor: _yellow,
    ),
    dividerColor: c.divider,
    extensions: [c],
  );
}
