import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract class AppColors {
  static const canvas = Color(0xFFF5F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF171A18);
  static const secondaryText = Color(0xFF7B817D);
  static const divider = Color(0xFFE5E8EB);
  // Note: We keep the variable names 'sage' and 'sageSoft' to avoid compile errors
  // in other files, but the values are changed to a premium modern coral-red.
  static const sage = Color(0xFFE54D42);
  static const sageSoft = Color(0xFFFDF0EF);
  static const marigold = Color(0xFFF1B93B);
  static const danger = Color(0xFFD65A4A);
  static const night = Color(0xFF171916);
  static const nightText = Color(0xFFD8DBD5);
}

abstract class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sage,
        secondary: AppColors.marigold,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: AppColors.text,
        onSurface: AppColors.text,
        onError: Colors.white,
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          color: AppColors.text,
          fontSize: 30,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineSmall: const TextStyle(
          color: AppColors.text,
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: const TextStyle(
          color: AppColors.text,
          fontSize: 19,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: AppColors.text,
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          color: AppColors.text,
          fontSize: 15,
          height: 1.65,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 13,
          height: 1.5,
        ),
        bodySmall: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      dividerColor: AppColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.sage,
        unselectedItemColor: AppColors.text,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: Color(0xFFA1A6A2)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.sage, width: 1.4),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
