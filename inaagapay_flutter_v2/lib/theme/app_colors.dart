// lib/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // ===== CONTEXT-AWARE HELPERS =====
  // Use these in widgets where BuildContext is available.
  static Color bgPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBgPrimary : bgPrimary;

  static Color bgSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBgSecondary : bgSecondary;

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color brandPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBrandPrimary : brandPrimary;

  static Color cardColorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBgSecondary : Colors.white;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorderPrimary : borderPrimary;

  // ===== LIGHT =====
  static const bgPrimary = Color(0xFFFAFAFA);
  static const bgSecondary = Color(0xFFFFF5F8);

  static const textPrimary = Color(0xFF2D2D2D);
  static const inputText = Color(0xFF5A5A5A);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textOnColor = Color(0xFFFFFFFF);
  static const faintWhite = Color(0xFFFFF9FC);

  static const brandPrimary = Color(0xFFFF68A5);
  static const brandSecondary = Color(0xFFFFF8FB);
  static const brandAccent = Color(0xFFE6398D);
  static const brandText = Color(0xFFC73578);

  static const borderPrimary = Color(0xFFF0F0F0);

  static const success = Color(0xFF68CBB8);
  static const warning = Color(0xFFFFB562);
  static const error = Color(0xFFE57373);
  static const info = Color(0xFF3B82F6);

  // ===== DARK =====
  static const darkBgPrimary = Color(0xFF121212);
  static const darkBgSecondary = Color(0xFF1C1C1E);

  static const darkTextPrimary = Color(0xFFEDEDED);
  static const darkTextSecondary = Color(0xFFB3B3B3);

  static const darkBorderPrimary = Color(0xFF2C2C2E);

  static const darkBrandPrimary = Color(0xFFFF7EB6);
  static const darkBrandAccent = Color(0xFFFF5FA2);
}
