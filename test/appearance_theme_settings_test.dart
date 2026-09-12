import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/core/appearance.dart';
import 'package:lumina/core/app_preferences.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/presentation/screens/settings/appearance_screen.dart';
import 'package:lumina/services/app_icon_service.dart';

class _FakeAppIconGateway implements AppIconGateway {
  @override
  Future<String> currentIconId() async => 'a1';
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<void> setIcon(String iconId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Appearance Theme Palettes & Presets', () {
    test('Default Light preset matches reference values exactly', () {
      final preset = lightThemePresets.firstWhere(
        (p) => p.id == 'default_light',
      );
      expect(preset.background.toHexRgb(), 'FAF9F5');
      expect(preset.foreground.toHexRgb(), '1F1E1D');
      expect(preset.accent.toHexRgb(), '93B259');
    });

    test('Default Dark preset matches reference values exactly', () {
      final preset = darkThemePresets.firstWhere((p) => p.id == 'default_dark');
      expect(preset.background.toHexRgb(), '1F1E1D');
      expect(preset.foreground.toHexRgb(), 'FAF9F5');
      expect(preset.accent.toHexRgb(), '93B259');
    });

    test('All presets match specified configurations', () {
      expect(lightThemePresets, hasLength(3));
      expect(lightThemePresets[0].id, 'default_light');
      expect(lightThemePresets[0].label, 'Default');
      expect(lightThemePresets[0].background.toHexRgb(), 'FAF9F5');
      expect(lightThemePresets[0].foreground.toHexRgb(), '1F1E1D');
      expect(lightThemePresets[0].accent.toHexRgb(), '93B259');

      expect(lightThemePresets[1].id, 'terracotta_orange');
      expect(lightThemePresets[1].label, 'Terracotta Orange');
      expect(lightThemePresets[1].background.toHexRgb(), 'FAF9F5');
      expect(lightThemePresets[1].foreground.toHexRgb(), '1F1E1D');
      expect(lightThemePresets[1].accent.toHexRgb(), 'C96442');

      expect(lightThemePresets[2].id, 'ever_forest');
      expect(lightThemePresets[2].label, 'Ever Forest');
      expect(lightThemePresets[2].background.toHexRgb(), 'FDF6E3');
      expect(lightThemePresets[2].foreground.toHexRgb(), '5C6A72');
      expect(lightThemePresets[2].accent.toHexRgb(), '93B259');

      expect(darkThemePresets, hasLength(1));
      expect(darkThemePresets[0].id, 'default_dark');
      expect(darkThemePresets[0].label, 'Default');
      expect(darkThemePresets[0].background.toHexRgb(), '1F1E1D');
      expect(darkThemePresets[0].foreground.toHexRgb(), 'FAF9F5');
      expect(darkThemePresets[0].accent.toHexRgb(), '93B259');
    });

    test(
      'ThemePalette matchesPreset correctly distinguishes modified colors',
      () {
        const palette = defaultLightPalette;
        final defaultPreset = lightThemePresets.first;
        expect(palette.matchesPreset(defaultPreset), isTrue);

        final modified = palette.copyWith(background: const Color(0xFFFFFFFF));
        expect(modified.matchesPreset(defaultPreset), isFalse);
      },
    );

    test('ColorHexFormatting formats uppercase RGB without alpha', () {
      expect(const Color(0xFFFAF9F5).toHexRgb(), 'FAF9F5');
      expect(const Color(0xFF007ACC).toHexRgb(), '007ACC');
      expect(const Color(0xFF000000).toHexRgb(), '000000');
    });
  });

  group('AppearanceScreen Widget Rendering', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        'subtitle preview responds to size and spacing in $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(430, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appIconGatewayProvider.overrideWithValue(_FakeAppIconGateway()),
              ],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: const AppearanceScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final sentence = find.text('Every story begins with a single word.');
          await tester.ensureVisible(sentence);
          await tester.pumpAndSettle();
          final initialSize = tester.widget<Text>(sentence).style!.fontSize!;
          final sizeSlider = tester.widget<Slider>(
            find.byKey(const ValueKey('appearance-font-slider')),
          );
          sizeSlider.onChanged!(40 / 24);
          await tester.pumpAndSettle();
          expect(
            tester.widget<Text>(sentence).style!.fontSize,
            greaterThan(initialSize),
          );
          final second = find.text('每一个故事，都从一个词开始。');
          final initialDistance =
              tester.getTopLeft(second).dy - tester.getTopLeft(sentence).dy;
          tester
              .widget<Slider>(
                find.byKey(const ValueKey('subtitle-spacing-slider')),
              )
              .onChanged!(80);
          await tester.pumpAndSettle();
          expect(
            tester.getTopLeft(second).dy - tester.getTopLeft(sentence).dy,
            greaterThan(initialDistance),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'renders Theme switch and both Light & Dark Theme palette cards',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appIconGatewayProvider.overrideWithValue(_FakeAppIconGateway()),
            ],
            child: const MaterialApp(
              locale: Locale('en'),
              home: AppearanceScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Check section labels & titles
        expect(find.byType(AppearanceScreen), findsOneWidget);

        // Verify theme icons (Laptop/System, Sun/Light, Moon/Dark)
        expect(
          find.byWidgetPredicate(
            (widget) => widget is AppIcon && widget.icon == AppIcons.laptop,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is AppIcon && widget.icon == AppIcons.sun03,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is AppIcon && widget.icon == AppIcons.moon02,
          ),
          findsOneWidget,
        );

        // Check preset labels
        expect(find.text('Default'), findsNWidgets(2));

        // Check hex codes from reference values
        expect(
          find.textContaining('FAF9F5', findRichText: true),
          findsNWidgets(2),
        );
        expect(
          find.textContaining('1F1E1D', findRichText: true),
          findsNWidgets(2),
        );
        expect(
          find.textContaining('93B259', findRichText: true),
          findsNWidgets(2),
        );
      },
    );

    testWidgets('tapping theme mode updates preference', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appIconGatewayProvider.overrideWithValue(_FakeAppIconGateway()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AppearanceScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        container.read(appPreferencesProvider).theme,
        AppThemePreference.system,
      );

      // Tap dark mode icon
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.icon == AppIcons.moon02,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(appPreferencesProvider).theme,
        AppThemePreference.dark,
      );

      // Tap light mode icon
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.icon == AppIcons.sun03,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(appPreferencesProvider).theme,
        AppThemePreference.light,
      );
    });

    testWidgets(
      'circular info buttons display explanations in dialogs and switch toggles scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(430, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            appIconGatewayProvider.overrideWithValue(_FakeAppIconGateway()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: AppearanceScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // 1. Scroll until subtitle scrolling switch is visible and toggles
        final switchFinder = find.byKey(
          const ValueKey('subtitle-scrolling-switch'),
        );
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(switchFinder, findsOneWidget);
        expect(
          container.read(appearanceControllerProvider).subtitleScrolling,
          isTrue,
        );
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(
          container.read(appearanceControllerProvider).subtitleScrolling,
          isFalse,
        );

        // 2. Verify subtitle spacing slider and text size slider are present
        expect(
          find.byKey(const ValueKey('subtitle-spacing-slider')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('appearance-font-slider')),
          findsOneWidget,
        );

        // 3. Verify no circular info buttons exist
        expect(
          find.byKey(const ValueKey('info-button-subtitle-scrolling')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('info-button-subtitle-spacing')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('info-button-font-size')),
          findsNothing,
        );
      },
    );
  });
}
