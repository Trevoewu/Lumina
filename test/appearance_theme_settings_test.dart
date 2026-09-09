import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(preset.accent.toHexRgb(), 'C96442');
    });

    test('Default Dark preset matches reference values exactly', () {
      final preset = darkThemePresets.firstWhere((p) => p.id == 'default_dark');
      expect(preset.background.toHexRgb(), '101010');
      expect(preset.foreground.toHexRgb(), 'CCCCCC');
      expect(preset.accent.toHexRgb(), '007ACC');
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
        expect(find.text('Default Light'), findsOneWidget);
        expect(find.text('Default Dark'), findsOneWidget);

        // Check hex codes from reference image
        expect(
          find.textContaining('FAF9F5', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('1F1E1D', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('C96442', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('101010', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('CCCCCC', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('007ACC', findRichText: true),
          findsOneWidget,
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
  });
}
