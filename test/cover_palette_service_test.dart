import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/core/app_colors.dart';
import 'package:lumina/services/cover_palette_service.dart';

void main() {
  test('normalizes vivid cover colors into readable dark surfaces', () {
    for (final seed in <Color>[
      Colors.yellow,
      Colors.cyanAccent,
      Colors.pinkAccent,
      Colors.white,
      const Color(0xFF777777),
    ]) {
      final surface = CoverPaletteService.darkSurfaceForSeed(seed);
      expect(surface.computeLuminance(), lessThan(0.18));
      expect(
        CoverPaletteService.contrastRatio(surface, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('creates one shared lyrics background from the cover seed', () {
    const seed = Color(0xFF19BEE8);
    final top = CoverPaletteService.pageTopForSeed(seed, Brightness.dark);
    final bottom = CoverPaletteService.darkPageBottomForSeed(seed);
    final lyricsBackground =
        CoverPaletteService.lyricsBackgroundGradientForSeed(seed);
    final defaultLyricsBackground =
        CoverPaletteService.lyricsBackgroundGradientForSeed(null);
    final card = CoverPaletteService.cardSurfaceForSeed(seed, Brightness.dark);

    expect(lyricsBackground.begin, Alignment.topCenter);
    expect(lyricsBackground.end, Alignment.bottomCenter);
    expect(lyricsBackground.colors, [top, bottom]);
    expect(defaultLyricsBackground.colors, [
      AppColors.lyricsBackground,
      AppColors.lyricsBackground,
    ]);
    expect(top.computeLuminance(), greaterThan(bottom.computeLuminance()));
    expect(card.computeLuminance(), greaterThan(bottom.computeLuminance()));
    expect(
      HSLColor.fromColor(top).hue,
      closeTo(HSLColor.fromColor(seed).hue, 1),
    );
    expect(
      HSLColor.fromColor(bottom).hue,
      closeTo(HSLColor.fromColor(seed).hue, 1),
    );
  });

  test('book card surface keeps cover tint subtle across themes', () {
    const seed = Color(0xFFE85C2A);

    final darkCard = CoverPaletteService.cardSurfaceForSeed(
      seed,
      Brightness.dark,
    );
    final lightCard = CoverPaletteService.cardSurfaceForSeed(
      seed,
      Brightness.light,
    );

    expect(darkCard.computeLuminance(), lessThan(0.08));
    expect(lightCard.computeLuminance(), greaterThan(0.72));
  });

  test('missing covers have no extracted seed', () async {
    expect(await CoverPaletteService.seedForPath(null), isNull);
    expect(
      await CoverPaletteService.seedForPath('/path/that/does/not/exist.jpg'),
      isNull,
    );
  });

  test('extracts a representative color from a real cover image', () async {
    final directory = await Directory.systemTemp.createTemp('cover-palette-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cover.png');
    final image = img.Image(width: 48, height: 48);
    img.fill(image, color: img.ColorRgb8(20, 150, 180));
    await file.writeAsBytes(img.encodePng(image));

    final seed = await CoverPaletteService.seedForPath(file.path);

    expect(seed, isNotNull);
    expect(seed!.b, greaterThan(seed.r));
    expect(seed.g, greaterThan(seed.r));
  });
}
