import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class AppTheme {
  static const fontFamily = 'IBMPlexSansArabic';

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.blue600,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.blue600,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDCEBFF),
      onPrimaryContainer: AppColors.navy900,
      secondary: AppColors.sky500,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD9F4FE),
      onSecondaryContainer: AppColors.navy900,
      tertiary: AppColors.cyan400,
      surface: Colors.white,
      onSurface: const Color(0xFF0B1435),
      onSurfaceVariant: const Color(0xFF5A6587),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF7F9FE),
      surfaceContainer: const Color(0xFFEFF3FB),
      surfaceContainerHigh: const Color(0xFFE7EDF8),
      surfaceContainerHighest: const Color(0xFFDFE6F4),
      outline: const Color(0xFFC5CEE3),
      outlineVariant: const Color(0xFFE3E8F3),
      error: AppColors.danger,
    ),
    scaffold: AppColors.surfaceLight,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.blue600,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.cyan400,
      onPrimary: AppColors.navy950,
      primaryContainer: AppColors.navy800,
      onPrimaryContainer: AppColors.cyan200,
      secondary: AppColors.sky500,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF0E2D70),
      onSecondaryContainer: AppColors.cyan200,
      tertiary: AppColors.cyan200,
      surface: AppColors.cardDark,
      onSurface: const Color(0xFFE8EEFF),
      onSurfaceVariant: const Color(0xFFA2AED3),
      surfaceContainerLowest: AppColors.surfaceDark,
      surfaceContainerLow: const Color(0xFF081438),
      surfaceContainer: const Color(0xFF0E1F52),
      surfaceContainerHigh: const Color(0xFF13275F),
      surfaceContainerHighest: const Color(0xFF1A306D),
      outline: const Color(0xFF2B3F7A),
      outlineVariant: const Color(0xFF1A2B5E),
      error: const Color(0xFFFF6B6F),
    ),
    scaffold: AppColors.surfaceDark,
  );

  static ThemeData _build(ColorScheme scheme, {required Color scaffold}) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.standard,
    );
    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      extensions: [
        StatusColors(
          success: AppColors.success,
          warning: AppColors.warning,
          danger: scheme.error,
          info: isDark ? AppColors.cyan400 : AppColors.blue600,
          neutral: scheme.onSurfaceVariant,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainer : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(scheme.outline),
        enabledBorder: border(scheme.outlineVariant),
        focusedBorder: border(scheme.primary, 1.6),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.6),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: rounded,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelLarge,
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? (isDark ? AppColors.cyan200 : AppColors.blue700)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.navy800 : AppColors.navy900,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: rounded,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
