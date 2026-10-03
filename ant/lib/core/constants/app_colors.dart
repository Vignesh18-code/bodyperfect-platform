import 'package:flutter/material.dart';

class AppColors {
  // Patient experience: shared blue / indigo palette.
  static const brandBlue = Color(0xFF4361EE);
  static const brandIndigo = Color(0xFF3A0CA3);
  static const surface = Color(0xFFF5F6FA);
  static const border = Color(0xFFE4E7F0);
  static const muted = Color(0xFF646C80);
  static const tint = Color(0xFFEEF0FF);
  static const success = Color(0xFF087F68);
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBlue, brandIndigo],
  );

  // Sky Blue Gradient (auth screens)
  static const skyBlueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF89CFF0),
      Color(0xFF6BB6D6),
      Color(0xFF4A9FD8),
      Color(0xFF5FB3E6),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const primary = Color(0xFF4A9FD8);
  static const textDark = Color(0xFF1A1A1A);
  static const textLight = Colors.white;

  // Brand Colors — Body Perfect Clinic
  static const navy = Color(0xFF1A1A2E);
  static const navyLight = Color(0xFF16213E);
  static const gold = Color(0xFFF5A623);
  static const rose = Color(0xFFE94560);

  // Home screen gradient
  static const navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
  );
}
