import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/app_colors.dart';
import 'package:lumina/core/app_design_tokens.dart';
import 'package:lumina/core/appearance.dart';
import 'package:lumina/core/theme.dart';

void main() {
  test('button text follows the accent it sits on', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final accent in const [
      AppColors.defaultAccent,
      Color(0xFF1B3A6B),
      Color(0xFFF2C14E),
      Color(0xFF7A1F3D),
    ]) {
      for (final theme in [
        AppTheme.lightTheme(accentColor: accent),
        AppTheme.darkTheme(accentColor: accent),
      ]) {
        final onAccent = theme.colorScheme.onPrimary;
        expect(contrast(onAccent, accent), greaterThanOrEqualTo(4.5));
        expect(
          theme.filledButtonTheme.style?.foregroundColor?.resolve({}),
          onAccent,
        );
      }
    }
  });

  test('secondary text stays readable on the page background', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
      final scheme = theme.colorScheme;
      expect(
        contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('100% text size uses the previous 85% visual baseline', () {
    expect(const AppearanceSettings().fontScale, 1.0);
    expect(appTextScaleBaseline, 0.85);
  });

  test('component themes and custom widgets share semantic tokens', () {
    final theme = AppTheme.darkTheme(
      readingFontFamily: 'Georgia',
      readingFontFamilyFallback: const ['Literata'],
    );
    final tokens = theme.extension<AppDesignTokens>()!;
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    final inputBorder =
        theme.inputDecorationTheme.border! as OutlineInputBorder;
    final chipShape = theme.chipTheme.shape! as RoundedRectangleBorder;
    final buttonPadding = theme.filledButtonTheme.style!.padding!.resolve({});

    expect(theme.textTheme.bodyLarge?.fontFamily, isNot('Literata'));
    expect(theme.textTheme.bodyLarge?.fontFamily, isNot('Inter'));
    expect(tokens.readingFontFamily, 'Georgia');
    expect(tokens.readingFontFamilyFallback, ['Literata']);
    expect(tokens.pageGutter, 16);
    expect(tokens.pageInsetFor(360), 16);
    expect(tokens.pageInsetFor(390), 16);
    expect(tokens.toolbarHeight, 56);
    expect(cardShape.borderRadius, BorderRadius.circular(tokens.radiusMedium));
    expect(
      inputBorder.borderRadius,
      BorderRadius.circular(tokens.radiusMedium),
    );
    expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    expect(theme.textTheme.headlineSmall?.fontSize, 18);
    expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w600);
    expect(chipShape.borderRadius, BorderRadius.circular(tokens.radiusSmall));
    expect(
      buttonPadding,
      EdgeInsets.symmetric(
        horizontal: tokens.spaceXl,
        vertical: tokens.spaceMd,
      ),
    );
    expect(tokens.dividerThickness, 1.0);
    expect(theme.dividerTheme.color, AppColors.darkDivider);
    expect(theme.dividerTheme.color, AppColors.darkDivider);
    expect(AppTheme.lightTheme().dividerTheme.color, AppColors.divider);
    expect(theme.dividerTheme.thickness, 1.0);
  });

  test('reading font options use bundled font families', () {
    expect(appearanceFontOptions.map((option) => option.fontFamily), [
      null,
      'Literata',
      'Athelas',
      'Menlo',
    ]);
    expect(appearanceFontOptions.map((option) => option.fontFamilyFallback), [
      null,
      ['Georgia'],
      ['Georgia', 'Literata'],
      ['JetBrainsMono'],
    ]);
  });

  testWidgets('bundled reading fonts are available as Flutter assets', (
    tester,
  ) async {
    final literata = await rootBundle.load(
      'assets/fonts/literata/Literata-Variable.ttf',
    );
    final jetBrainsMono = await rootBundle.load(
      'assets/fonts/jetbrains_mono/JetBrainsMono-Variable.ttf',
    );

    expect(literata.lengthInBytes, greaterThan(900000));
    expect(jetBrainsMono.lengthInBytes, greaterThan(180000));
  });
}
