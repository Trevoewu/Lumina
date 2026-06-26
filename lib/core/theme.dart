import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// 全局应用主题
class AppTheme {
  /// 我们仅使用深色主题 (Spotify 风格)
  static ThemeData darkTheme({
    Color accentColor = AppColors.primary,
    String? fontFamily = AppTextStyles.fontFamily,
  }) {
    final colorScheme = AppColors.darkColorScheme.copyWith(
      primary: accentColor,
      secondary: accentColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTextStyles.darkTextTheme.apply(fontFamily: fontFamily),
      fontFamily: fontFamily,

      // 自定义 AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading1.copyWith(fontFamily: fontFamily),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // 自定义 BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // 自定义卡片
      cardTheme: CardThemeData(
        color: AppColors.surface,
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
