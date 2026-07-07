import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/app_design_tokens.dart';
import 'package:lumina/core/theme.dart';

void main() {
  test('component themes and custom widgets share semantic tokens', () {
    final theme = AppTheme.darkTheme(readingFontFamily: 'Georgia');
    final tokens = theme.extension<AppDesignTokens>()!;
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    final inputBorder =
        theme.inputDecorationTheme.border! as OutlineInputBorder;

    expect(theme.textTheme.bodyLarge?.fontFamily, isNot('Georgia'));
    expect(theme.textTheme.bodyLarge?.fontFamily, isNot('Inter'));
    expect(tokens.readingFontFamily, 'Georgia');
    expect(tokens.pageGutter, 24);
    expect(tokens.pageInsetFor(360), 16);
    expect(tokens.pageInsetFor(390), 24);
    expect(cardShape.borderRadius, BorderRadius.circular(tokens.radiusMedium));
    expect(
      inputBorder.borderRadius,
      BorderRadius.circular(tokens.radiusMedium),
    );
    expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
  });
}
