import 'package:flutter/material.dart';

/// 应用程序全局颜色定义 (Spotify Style)
class AppColors {
  /// 主色调 - 绿色
  static const Color primary = Color(0xFF1DB954);

  /// 深色背景 - 纯黑/深灰
  static const Color background = Color(0xFF121212);

  /// 表面颜色 - 卡片、底部导航栏等
  static const Color surface = Color(0xFF282828);
  static const Color surfaceHighlight = Color(0xFF333333);

  /// 文字颜色
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);

  /// 错误提示
  static const Color error = Color(0xFFE22134);

  /// Lyrics use an immersive dark palette in every app theme.
  static const Color lyricsBackground = Color(0xFF0D1511);
  static const Color lyricsTextPrimary = Colors.white;
  static const Color lyricsTextSecondary = Color(0xFF8A948F);

  /// 根据这些颜色生成 ColorScheme
  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: primary,
    onPrimary: Colors.black,
    secondary: primary,
    onSecondary: Colors.black,
    surface: background, // Scaffold background
    surfaceContainer: surface, // Cards, bottom sheets
    surfaceContainerHighest: surfaceHighlight, // Hover states, elevated cards
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    error: error,
    onError: Colors.white,
  );

  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: primary,
    onPrimary: Colors.black,
    secondary: primary,
    onSecondary: Colors.black,
    surface: Color(0xFFF7F7F7),
    surfaceContainer: Colors.white,
    surfaceContainerHighest: Color(0xFFE8E8E8),
    onSurface: Color(0xFF151515),
    onSurfaceVariant: Color(0xFF666666),
    error: error,
    onError: Colors.white,
  );
}

extension AppColorContext on BuildContext {
  Color get appBackground => Theme.of(this).colorScheme.surface;
  Color get appSurface => Theme.of(this).colorScheme.surfaceContainer;
  Color get appSurfaceHighlight =>
      Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get appTextPrimary => Theme.of(this).colorScheme.onSurface;
  Color get appTextSecondary => Theme.of(this).colorScheme.onSurfaceVariant;
}
