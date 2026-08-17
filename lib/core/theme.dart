import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_design_tokens.dart';
import 'app_text_styles.dart';

/// 全局应用主题
class AppTheme {
  static ThemeData darkTheme({
    Color accentColor = AppColors.defaultAccent,
    String? readingFontFamily,
    List<String>? readingFontFamilyFallback,
  }) => _buildTheme(
    AppColors.darkColorScheme,
    accentColor: accentColor,
    readingFontFamily: readingFontFamily,
    readingFontFamilyFallback: readingFontFamilyFallback,
  );

  static ThemeData lightTheme({
    Color accentColor = AppColors.defaultAccent,
    String? readingFontFamily,
    List<String>? readingFontFamilyFallback,
  }) => _buildTheme(
    AppColors.lightColorScheme,
    accentColor: accentColor,
    readingFontFamily: readingFontFamily,
    readingFontFamilyFallback: readingFontFamilyFallback,
  );

  static ThemeData _buildTheme(
    ColorScheme baseScheme, {
    required Color accentColor,
    required String? readingFontFamily,
    required List<String>? readingFontFamilyFallback,
  }) {
    final tokens = AppDesignTokens(
      readingFontFamily: readingFontFamily,
      readingFontFamilyFallback: readingFontFamilyFallback,
    );
    final accentContainer = Color.alphaBlend(
      accentColor.withValues(alpha: 0.16),
      baseScheme.surface,
    );
    final colorScheme = baseScheme.copyWith(
      primary: accentColor,
      secondary: accentColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      primaryContainer: accentContainer,
      onPrimaryContainer: baseScheme.onSurface,
      primaryFixed: accentColor,
      primaryFixedDim: accentColor,
      onPrimaryFixed: Colors.black,
      onPrimaryFixedVariant: Colors.black,
      secondaryContainer: accentContainer,
      onSecondaryContainer: baseScheme.onSurface,
      secondaryFixed: accentColor,
      secondaryFixedDim: accentColor,
      onSecondaryFixed: Colors.black,
      onSecondaryFixedVariant: Colors.black,
      inversePrimary: accentColor,
      surfaceTint: accentColor,
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
      textTheme: AppTextStyles.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      extensions: [tokens],

      // 自定义 AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      // Compact tab bar content; NavigationBar still keeps the system bottom
      // safe area outside this height so the home indicator is never covered.
      navigationBarTheme: NavigationBarThemeData(
        height: 46,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? accentColor
                : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return AppTextStyles.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            height: 1,
            color: states.contains(WidgetState.selected)
                ? accentColor
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // 自定义卡片
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spaceLg,
          vertical: tokens.spaceMd,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: AppTextStyles.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: AppTextStyles.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size.square(tokens.minimumTouchTarget),
          iconSize: 24,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        modalBackgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusLarge),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: accentColor.withValues(alpha: 0.16),
        disabledColor: colorScheme.surfaceContainer.withValues(alpha: 0.48),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
        ),
        labelStyle: AppTextStyles.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        secondaryLabelStyle: AppTextStyles.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm),
      ),

      // 自定义按钮
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceXl,
            vertical: tokens.spaceMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
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
