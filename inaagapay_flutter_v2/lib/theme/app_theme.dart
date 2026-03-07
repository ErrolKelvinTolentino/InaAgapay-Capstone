import 'package:flutter/material.dart';

class AppTheme {
  // ─── Core Colors ───────────────────────────────────────────────────────────
  static const Color primaryPink = Color(0xFFE91E8C);
  static const Color primaryDark = Color(0xFFC2185B);
  static const Color primaryDarker = Color(0xFF880E4F);
  static const Color primaryLight = Color(0xFFF48FB1);
  static const Color softPink = Color(0xFFFCE4EC);
  static const Color accentPink = Color(0xFFFF4081);
  static const Color white = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFFFF5F8);
  static const Color textPrimary = Color(0xFF2D1B2E);
  static const Color textSecondary = Color(0xFF72567A);
  static const Color textLight = Color(0xFFB0899D);
  static const Color borderColor = Color(0xFFFFCDD2);

  // ─── Semantic Colors ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successBg = Color(0xFFC8E6C9);
  static const Color warning = Color(0xFFE65100);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color warningBg = Color(0xFFFFCCBC);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerLight = Color(0xFFFFEBEE);
  static const Color dangerBg = Color(0xFFFFCDD2);
  static const Color info = Color(0xFF0277BD);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ─── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE91E8C), Color(0xFF880E4F)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF80AB), Color(0xFFE91E8C)],
  );

  static const LinearGradient loginBgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF0F5), Color(0xFFFFE0EF), Color(0xFFFCE4EC)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF5F8)],
  );

  // ─── Stat Card Gradients ───────────────────────────────────────────────────
  static const LinearGradient stat1 = LinearGradient(
    colors: [Color(0xFFE91E8C), Color(0xFFC2185B)],
  );
  static const LinearGradient stat2 = LinearGradient(
    colors: [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
  );
  static const LinearGradient stat3 = LinearGradient(
    colors: [Color(0xFFD81B60), Color(0xFF880E4F)],
  );
  static const LinearGradient stat4 = LinearGradient(
    colors: [Color(0xFFAD1457), Color(0xFF6A1B9A)],
  );
  static const LinearGradient stat5 = LinearGradient(
    colors: [Color(0xFF00897B), Color(0xFF00695C)],
  );

  // ─── Decorations ──────────────────────────────────────────────────────────
  static BoxDecoration cardDecoration({
    double radius = 16,
    bool showShadow = true,
    Gradient? gradient,
    Color? borderCol,
  }) {
    return BoxDecoration(
      gradient: gradient ?? cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderCol ?? borderColor.withAlpha(153),
        width: 1,
      ),
      boxShadow: showShadow
          ? [
              BoxShadow(
                color: primaryPink.withAlpha(20),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  // ─── Material Theme ───────────────────────────────────────────────────────
  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        primary: primaryPink,
        secondary: accentPink,
        surface: bg,
      ),
      scaffoldBackgroundColor: bg,
      fontFamily: 'Poppins',
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPink,
          side: const BorderSide(color: primaryPink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor.withAlpha(200)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontFamily: 'Poppins',
        ),
        hintStyle: const TextStyle(color: textLight, fontFamily: 'Poppins'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardColor: white,
      dialogTheme: const DialogThemeData(backgroundColor: white),
    );
  }
}
