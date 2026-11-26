import 'package:flutter/material.dart';

import 'app_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build() {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.ink,
        onPrimary: AppColors.paper,
        secondary: AppColors.gold,
        onSecondary: Colors.white,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.caution,
      ),
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppText.serif,
          fontSize: 20,
          color: AppColors.ink,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inkDeep,
        contentTextStyle: TextStyle(fontSize: 16, color: AppColors.paper),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      // 派手なアニメーションは使わない
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      bodyLarge: const TextStyle(
        fontFamily: AppText.sans,
        fontSize: AppText.bodyLarge,
        height: 1.7,
        color: AppColors.ink,
      ),
      bodyMedium: const TextStyle(
        fontFamily: AppText.sans,
        fontSize: AppText.body,
        height: 1.7,
        color: AppColors.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: AppText.sans,
        fontSize: 13,
        height: 1.6,
        color: AppColors.ink.withValues(alpha: 0.6),
      ),
      titleLarge: const TextStyle(
        fontFamily: AppText.serif,
        fontSize: AppText.title,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: 1.5,
      ),
      titleMedium: const TextStyle(
        fontFamily: AppText.serif,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      labelLarge: const TextStyle(
        fontFamily: AppText.sans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }
}
