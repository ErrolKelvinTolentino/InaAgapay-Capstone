import 'app_colors.dart';
import 'package:flutter/material.dart';


class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'DM Sans',
    scaffoldBackgroundColor: AppColors.bgPrimary,
    colorScheme: ColorScheme.light(
      primary: AppColors.brandPrimary,
      onPrimary: AppColors.textOnColor,
      secondary: AppColors.brandAccent,
      onSecondary: AppColors.textOnColor,
      background: AppColors.bgPrimary,
      onBackground: AppColors.textPrimary,
      surface: AppColors.bgSecondary,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.textOnColor,
    ),
  );


  // 🌙 DARK THEME
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'DM Sans',
    scaffoldBackgroundColor: AppColors.darkBgPrimary,


    colorScheme: ColorScheme.dark(
      primary: AppColors.darkBrandPrimary,
      onPrimary: AppColors.textOnColor,
      secondary: AppColors.darkBrandAccent,
      onSecondary: AppColors.textOnColor,
      background: AppColors.darkBgPrimary,
      onBackground: AppColors.darkTextPrimary,
      surface: AppColors.darkBgSecondary,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.error,
      onError: AppColors.textOnColor,
    ),


    textTheme: TextTheme(
      bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
      bodySmall: TextStyle(color: AppColors.darkTextSecondary),
      titleLarge: TextStyle(
        color: AppColors.darkTextPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),


    dividerColor: AppColors.darkBorderPrimary,


    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBgPrimary,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
    ),
  );
}



