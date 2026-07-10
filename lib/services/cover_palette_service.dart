import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/app_colors.dart';

/// Extracts a representative cover color and turns it into a restrained,
/// high-contrast mini-player surface.
class CoverPaletteService {
  CoverPaletteService._();

  static final Map<String, Future<Color?>> _cache = {};

  static Future<Color?> seedForPath(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) return null;
      final cacheKey =
          '$path:${stat.modified.microsecondsSinceEpoch}:${stat.size}';
      return _cache.putIfAbsent(cacheKey, () async {
        try {
          return Color(await Isolate.run(() => _extractSeed(path)));
        } catch (_) {
          return null;
        }
      });
    } catch (_) {
      return null;
    }
  }

  /// Normalizes arbitrary artwork colors so white controls remain readable.
  static Color darkSurfaceForSeed(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    final normalized = hsl
        .withSaturation(hsl.saturation.clamp(0.32, 0.68))
        .withLightness(hsl.lightness.clamp(0.18, 0.28))
        .toColor();

    var surface = Color.lerp(normalized, Colors.black, 0.10)!;
    while (_contrastRatio(surface, Colors.white) < 4.5) {
      surface = Color.lerp(surface, Colors.black, 0.08)!;
    }
    return surface;
  }

  /// A stronger cover tint for the top of detail and player pages.
  static Color pageTopForSeed(Color seed, Brightness brightness) {
    final hsl = HSLColor.fromColor(seed);
    final isDark = brightness == Brightness.dark;
    return hsl
        .withSaturation(hsl.saturation.clamp(0.30, 0.68))
        .withLightness(
          isDark
              ? hsl.lightness.clamp(0.26, 0.36)
              : hsl.lightness.clamp(0.72, 0.84),
        )
        .toColor();
  }

  /// A subtle card tint for repeated book rows. This keeps the list scannable
  /// while letting local book cards inherit an ambient cover color.
  static Color cardSurfaceForSeed(Color seed, Brightness brightness) {
    final hsl = HSLColor.fromColor(seed);
    final isDark = brightness == Brightness.dark;
    return hsl
        .withSaturation(hsl.saturation.clamp(0.20, 0.46))
        .withLightness(
          isDark
              ? hsl.lightness.clamp(0.13, 0.18)
              : hsl.lightness.clamp(0.90, 0.96),
        )
        .toColor();
  }

  /// A near-black version that keeps the artwork hue for immersive screens.
  static Color darkPageBottomForSeed(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.24, 0.54))
        .withLightness(hsl.lightness.clamp(0.07, 0.11))
        .toColor();
  }

  /// Shared cover-aware background for inline and full-screen lyrics.
  static LinearGradient lyricsBackgroundGradientForSeed(Color? seed) {
    final top = seed == null
        ? AppColors.lyricsBackground
        : pageTopForSeed(seed, Brightness.dark);
    final bottom = seed == null
        ? AppColors.lyricsBackground
        : darkPageBottomForSeed(seed);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    );
  }

  static double contrastRatio(Color a, Color b) {
    return _contrastRatio(a, b);
  }

  /// Foreground for cover-derived immersive surfaces. Cover colors never
  /// replace the app primary; they only determine ambient surfaces and their
  /// readable text/icon color.
  static Color foregroundFor(Color background) {
    final whiteContrast = _contrastRatio(background, Colors.white);
    final blackContrast = _contrastRatio(background, Colors.black);
    return whiteContrast >= blackContrast ? Colors.white : Colors.black;
  }

  static double _contrastRatio(Color a, Color b) {
    final lighter = math.max(a.computeLuminance(), b.computeLuminance());
    final darker = math.min(a.computeLuminance(), b.computeLuminance());
    return (lighter + 0.05) / (darker + 0.05);
  }

  static int _extractSeed(String path) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) throw const FormatException('Invalid cover image');
    final sample = img.copyResize(
      decoded,
      width: 48,
      height: 48,
      interpolation: img.Interpolation.average,
    );

    final bins = <int, _ColorBin>{};
    for (final pixel in sample) {
      if (pixel.a < 128) continue;
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      (bins[key] ??= _ColorBin()).add(r, g, b);
    }
    if (bins.isEmpty) return Colors.black.toARGB32();

    _ColorBin? best;
    var bestScore = -1.0;
    for (final bin in bins.values) {
      final color = bin.color;
      final hsl = HSLColor.fromColor(color);
      final luminance = color.computeLuminance();
      if (luminance < 0.02 || luminance > 0.90) continue;

      // Population keeps the result representative. Saturation and a middle
      // tone preference stop black/white borders from overwhelming artwork.
      final tone = 1 - ((hsl.lightness - 0.46).abs() / 0.54).clamp(0.0, 1.0);
      final score =
          math.pow(bin.count, 0.72).toDouble() *
          (0.35 + hsl.saturation * 0.65) *
          (0.55 + tone * 0.45);
      if (score > bestScore) {
        best = bin;
        bestScore = score;
      }
    }

    best ??= bins.values.reduce((a, b) => a.count >= b.count ? a : b);
    return best.color.toARGB32();
  }
}

class _ColorBin {
  int count = 0;
  int red = 0;
  int green = 0;
  int blue = 0;

  void add(int r, int g, int b) {
    count++;
    red += r;
    green += g;
    blue += b;
  }

  Color get color =>
      Color.fromARGB(255, red ~/ count, green ~/ count, blue ~/ count);
}
