import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // GLOWLOAD Color Tokens
  static const Color background = Color(0xFF000000); // pure black body
  static const Color surface = Color(0xFF131313); // dark surface
  static const Color surfaceContainer = Color(0xFF201F1F); // container card surface
  static const Color surfaceLowest = Color(0xFF0E0E0E); // input field background
  
  static const Color primary = Color(0xFFFFB3B6); // light rose pink
  static const Color primaryContainer = Color(0xFFFF5168); // vibrant hot pink/red
  static const Color secondary = Color(0xFFE3B5FF); // light purple
  static const Color secondaryContainer = Color(0xFF6A1C9B); // deep purple
  static const Color tertiary = Color(0xFFBAC3FF); // light blue-purple
  static const Color tertiaryContainer = Color(0xFF7087FF); // electric blue-purple

  static const Color textPrimary = Color(0xFFE5E2E1); // on-background
  static const Color textSecondary = Color(0xFFE6BCBD); // on-surface-variant
  static const Color textMuted = Color(0xFF5D5D5B); // muted labels/borders
  
  static const Color border = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color outline = Color(0xFFAD8889);
  static const Color outlineVariant = Color(0xFF5D3F40);

  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFFB4AB);

  // GLOWLOAD gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      primaryContainer,
      secondaryContainer,
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient atmosphericPrimary = LinearGradient(
    colors: [
      Color(0x1AFFB3B6), // primary/10
      Color(0x00FFB3B6),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient atmosphericSecondary = LinearGradient(
    colors: [
      Color(0x0DE3B5FF), // secondary/5
      Color(0x00E3B5FF),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
