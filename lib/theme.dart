import 'package:flutter/material.dart';

/// Colors and text styles of the cozy sweet-shop look.
abstract final class AppColors {
  static const cream = Color(0xFFFFF4E0);
  static const creamDark = Color(0xFFF7DFB6);
  static const caramel = Color(0xFFE8A23B);
  static const caramelDark = Color(0xFFB86E14);
  static const chocolate = Color(0xFF5A3220);
  static const chocolateDark = Color(0xFF3B1F12);
  static const chocolateLight = Color(0xFF7A4A2E);
  static const gold = Color(0xFFFFCB3C);
  static const goldDark = Color(0xFFE39A0C);
  static const goldLight = Color(0xFFFFE89A);
  static const text = Color(0xFF4A2A12);
  static const pink = Color(0xFFF26FA6);
  static const mint = Color(0xFF4CC992);
  static const sky = Color(0xFF3D8FE8);
  static const red = Color(0xFFE5484D);
  static const tileLight = Color(0xFFFFF6E6);
  static const tileDark = Color(0xFFF8E6C6);
}

abstract final class AppText {
  static const heading = 'Baloo2';
  static const body = 'Nunito';

  static TextStyle title(double size, {Color color = Colors.white, List<Shadow>? shadows}) =>
      TextStyle(
        fontFamily: heading,
        fontWeight: FontWeight.w800,
        fontSize: size,
        height: 1.05,
        color: color,
        shadows: shadows ??
            const [Shadow(color: Color(0x88000000), offset: Offset(0, 2), blurRadius: 2)],
      );

  static TextStyle label(double size, {Color color = AppColors.text, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: body, fontWeight: weight, fontSize: size, color: color, height: 1.2);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.caramel,
      primary: AppColors.caramelDark,
      surface: AppColors.cream,
    ),
    scaffoldBackgroundColor: AppColors.cream,
    fontFamily: AppText.body,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: AppText.body,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.transparent, elevation: 0),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold : Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.caramelDark : AppColors.chocolateLight),
    ),
  );
}
