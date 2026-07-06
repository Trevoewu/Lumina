import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// 全局应用主题
class AppTheme {
  static ThemeData darkTheme({
    Color accentColor = AppColors.primary,
    String? fontFamily = AppTextStyles.fontFamily,
  }) => _buildTheme(
    AppColors.darkColorScheme,
    accentColor: accentColor,
    fontFamily: fontFamily,
  );

  static ThemeData lightTheme({
    Color accentColor = AppColors.primary,
    String? fontFamily = AppTextStyles.fontFamily,
  }) => _buildTheme(
    AppColors.lightColorScheme,
    accentColor: accentColor,
    fontFamily: fontFamily,
  );

  static ThemeData _buildTheme(
    ColorScheme baseScheme, {
    required Color accentColor,
    required String? fontFamily,
  }) {
    final colorScheme = baseScheme.copyWith(
      primary: accentColor,
      secondary: accentColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      // Keep page navigation touch-native on phones. MaterialPageRoute only
      // installs an edge-swipe detector when it uses Cupertino transitions;
      // Android's default transition therefore cannot be dragged back.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: AppTextStyles.darkTextTheme.apply(
        fontFamily: fontFamily,
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      fontFamily: fontFamily,

      // 自定义 AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading1.copyWith(
          color: colorScheme.onSurface,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      // 自定义 BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.onSurface,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // 自定义卡片
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),

      // 自定义按钮
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        thumbColor: accentColor,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accentColor),
    );
  }
}
