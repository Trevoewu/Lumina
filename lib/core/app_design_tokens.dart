import 'package:flutter/material.dart';

/// Semantic layout and typography-adjacent values shared by every surface.
///
/// Component themes and custom widgets must both read from this extension so
/// the design system has a single source of truth.
@immutable
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceXxl;
  final double pageGutter;
  final double compactPageGutter;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusPill;
  final double minimumTouchTarget;
  final double controlHeight;
  final double toolbarHeight;
  final double dividerThickness;
  final String? readingFontFamily;
  final List<String>? readingFontFamilyFallback;

  const AppDesignTokens({
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 12,
    this.spaceLg = 16,
    this.spaceXl = 24,
    this.spaceXxl = 32,
    this.pageGutter = 16,
    this.compactPageGutter = 16,
    this.radiusSmall = 8,
    this.radiusMedium = 12,
    this.radiusLarge = 16,
    this.radiusPill = 999,
    this.minimumTouchTarget = 44,
    this.controlHeight = 52,
    this.toolbarHeight = 56,
    this.dividerThickness = 1.0,
    this.readingFontFamily,
    this.readingFontFamilyFallback,
  });

  double pageInsetFor(double width) =>
      width <= 360 ? compactPageGutter : pageGutter;

  @override
  AppDesignTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? pageGutter,
    double? compactPageGutter,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? radiusPill,
    double? minimumTouchTarget,
    double? controlHeight,
    double? toolbarHeight,
    double? dividerThickness,
    String? readingFontFamily,
    List<String>? readingFontFamilyFallback,
    bool clearReadingFontFamily = false,
  }) {
    return AppDesignTokens(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      pageGutter: pageGutter ?? this.pageGutter,
      compactPageGutter: compactPageGutter ?? this.compactPageGutter,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusPill: radiusPill ?? this.radiusPill,
      minimumTouchTarget: minimumTouchTarget ?? this.minimumTouchTarget,
      controlHeight: controlHeight ?? this.controlHeight,
      toolbarHeight: toolbarHeight ?? this.toolbarHeight,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      readingFontFamily: clearReadingFontFamily
          ? null
          : readingFontFamily ?? this.readingFontFamily,
      readingFontFamilyFallback: clearReadingFontFamily
          ? null
          : readingFontFamilyFallback ?? this.readingFontFamilyFallback,
    );
  }

  @override
  AppDesignTokens lerp(
    covariant ThemeExtension<AppDesignTokens>? other,
    double t,
  ) {
    if (other is! AppDesignTokens) return this;
    return AppDesignTokens(
      spaceXs: _lerp(spaceXs, other.spaceXs, t),
      spaceSm: _lerp(spaceSm, other.spaceSm, t),
      spaceMd: _lerp(spaceMd, other.spaceMd, t),
      spaceLg: _lerp(spaceLg, other.spaceLg, t),
      spaceXl: _lerp(spaceXl, other.spaceXl, t),
      spaceXxl: _lerp(spaceXxl, other.spaceXxl, t),
      pageGutter: _lerp(pageGutter, other.pageGutter, t),
      compactPageGutter: _lerp(compactPageGutter, other.compactPageGutter, t),
      radiusSmall: _lerp(radiusSmall, other.radiusSmall, t),
      radiusMedium: _lerp(radiusMedium, other.radiusMedium, t),
      radiusLarge: _lerp(radiusLarge, other.radiusLarge, t),
      radiusPill: _lerp(radiusPill, other.radiusPill, t),
      minimumTouchTarget: _lerp(
        minimumTouchTarget,
        other.minimumTouchTarget,
        t,
      ),
      controlHeight: _lerp(controlHeight, other.controlHeight, t),
      toolbarHeight: _lerp(toolbarHeight, other.toolbarHeight, t),
      dividerThickness: _lerp(dividerThickness, other.dividerThickness, t),
      readingFontFamily: t < 0.5 ? readingFontFamily : other.readingFontFamily,
      readingFontFamilyFallback: t < 0.5
          ? readingFontFamilyFallback
          : other.readingFontFamilyFallback,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

extension AppDesignContext on BuildContext {
  AppDesignTokens get appDesign =>
      Theme.of(this).extension<AppDesignTokens>() ?? const AppDesignTokens();
}
