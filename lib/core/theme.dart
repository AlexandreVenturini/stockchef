import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF3C86B7);
  static const background = Color(0xFFE5F2FB);
  static const surface = Color(0xFFFFFFFF);
  static const iconBackground = Color(0xFFE4F2FB);
  static const title = Color(0xFF1D3A56);
  static const text = Color(0xFF0F1B2A);
  static const textSecondary = Color(0xFF5B6670);
  static const quantity = Color(0xFF367EB9);
  static const chip = Color(0xFFC4DEF5);
  static const border = Color(0xFFD3E2EF);
  static const alert = Color(0xFFBB2527);
  static const alertBackground = Color(0xFFF5E0DF);
  static const navigationBar = Color(0xFFF1F6FC);
  static const navigationSelected = Color(0xFF326384);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
}

abstract final class AppRadius {
  static const md = 12.0;
  static const lg = 16.0;
}

abstract final class AppSizes {
  static const buttonHeight = 52.0;
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondaryContainer: AppColors.chip,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    error: AppColors.alert,
    errorContainer: AppColors.alertBackground,
    onErrorContainer: AppColors.alert,
  );
  const pill = StadiumBorder();
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.title,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.title,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, AppSizes.buttonHeight),
        shape: pill,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, AppSizes.buttonHeight),
        shape: pill,
        side: const BorderSide(color: AppColors.border),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.chip,
      selectedColor: AppColors.primary,
      side: BorderSide.none,
      shape: pill,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.navigationBar,
      indicatorColor: AppColors.chip,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.navigationSelected
              : AppColors.title,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.navigationSelected
              : AppColors.title,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
  );
}
