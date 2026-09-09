import 'package:lumina/presentation/widgets/app_back_button.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/app_preferences.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/settings_screen.dart';
import 'package:lumina/presentation/widgets/design_system/settings_components.dart';

void main() {
  final cases = <({String name, Size size, double scale, ThemeMode mode})>[
    (
      name: 'dark compact',
      size: const Size(390, 760),
      scale: 1,
      mode: ThemeMode.dark,
    ),
    (
      name: 'light compact',
      size: const Size(390, 760),
      scale: 1.3,
      mode: ThemeMode.light,
    ),
    (
      name: 'dark regular',
      size: const Size(430, 820),
      scale: 1.3,
      mode: ThemeMode.dark,
    ),
    (
      name: 'light regular',
      size: const Size(430, 820),
      scale: 1,
      mode: ThemeMode.light,
    ),
  ];

  for (final testCase in cases) {
    testWidgets('settings layout supports ${testCase.name}', (tester) async {
      tester.view.physicalSize = testCase.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: testCase.mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(testCase.scale)),
              child: child!,
            ),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Models & Services'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('asr-service-settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('llm-provider-settings')),
        findsOneWidget,
      );
      expect(find.text('Speech Recognition (ASR)'), findsOneWidget);
      expect(find.text('AI Model'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tts-service-settings')),
        findsOneWidget,
      );
      expect(find.text('Voice Synthesis (TTS)'), findsOneWidget);
      expect(find.byKey(const ValueKey('tts-provider-selector')), findsNothing);

      // Nothing the settings spec dropped should still be on the page.
      expect(find.text('Enhanced Features'), findsNothing);
      expect(find.text('Playback'), findsNothing);
      expect(find.text('Sleep timer'), findsNothing);
      expect(find.text('App Icon'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('language settings separate UI and AI response languages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: ThemeMode.dark,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    // The spec runs the row hairline the full width of the card.
    final firstGroup = find.byType(SettingsGroup).first;
    final dividerFinder = find.descendant(
      of: firstGroup,
      matching: find.byType(Divider),
    );
    final divider = tester.widget<Divider>(dividerFinder.first);
    expect(divider.thickness, 1);
    expect(divider.indent, isNull);
    expect(divider.endIndent, isNull);
    expect(divider.color?.a, closeTo(0.06, 0.01));

    final languageRow = find.byKey(const ValueKey('language-selector'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(languageRow);
    await tester.pumpAndSettle();

    expect(find.text('UI Language'), findsOneWidget);
    expect(find.text('AI Service Language'), findsOneWidget);
    final uiLanguageRow = find.byKey(const ValueKey('ui-language-selector'));
    await tester.tap(uiLanguageRow);
    await tester.pumpAndSettle();
    final languageItems = find.byType(PopupMenuItem<AppLanguage>);
    expect(languageItems, findsNWidgets(AppLanguage.values.length));
    expect(
      tester.getCenter(languageItems.first).dx,
      greaterThan(tester.getCenter(uiLanguageRow).dx),
    );
    expect(
      find.descendant(of: languageItems, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();

    expect(await database.getSetting('general_language'), 'english');
    expect(await database.getSetting('ai_service_language'), 'japanese');

    // Theme preference is configured inside AppearanceScreen
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    final appearanceRow = find.byKey(const ValueKey('appearance-settings'));
    await tester.ensureVisible(appearanceRow);
    await tester.tap(appearanceRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.nightlight_outlined));
    await tester.pumpAndSettle();
    expect(await database.getSetting('general_theme_mode'), 'dark');
  });

  testWidgets('restoring initial settings requires two confirmations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final resetRow = find.byKey(const ValueKey('reset-app-settings'));
    await tester.scrollUntilVisible(
      resetRow,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(resetRow);
    await tester.pumpAndSettle();

    expect(find.text('Restore initial settings?'), findsOneWidget);
    expect(
      find.textContaining('API keys and provider configuration'),
      findsOneWidget,
    );
    expect(
      find.textContaining('downloaded Whisper model will be kept'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('continue-reset-app-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Final confirmation'), findsOneWidget);
    expect(find.textContaining('This cannot be undone'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-reset-app-settings')),
      findsOneWidget,
    );

    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(find.text('Final confirmation'), findsNothing);
  });
}
