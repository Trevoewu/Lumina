import 'package:flutter/material.dart';

/// 应用程序全局文字样式定义
class AppTextStyles {
  /// UI typography intentionally uses the platform system font. Reading
  /// typography is applied only by content widgets through AppDesignTokens.
  static const TextTheme textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.normal,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      height: 1.2,
      fontWeight: FontWeight.normal,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.normal,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.normal,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.normal,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w400,
    ),
  );
}
