import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/app_preferences.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/settings_screen.dart';

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

      expect(
        find.byKey(const ValueKey('tts-service-settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('llm-provider-settings')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tts-provider-selector')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('language and theme menus anchor to the trailing value', (
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

    final languageRow = find.byKey(const ValueKey('language-selector'));
    await tester.tap(languageRow);
    await tester.pumpAndSettle();
    final languageItems = find.byType(PopupMenuItem<AppLanguage>);
    expect(languageItems, findsNWidgets(AppLanguage.values.length));
    expect(
      tester.getCenter(languageItems.first).dx,
      greaterThan(tester.getCenter(languageRow).dx),
    );
    expect(
      find.descendant(of: languageItems, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final themeRow = find.byKey(const ValueKey('theme-selector'));
    await tester.tap(themeRow);
    await tester.pumpAndSettle();
    final themeItems = find.byType(PopupMenuItem<AppThemePreference>);
    expect(themeItems, findsNWidgets(AppThemePreference.values.length));
    expect(
      tester.getCenter(themeItems.first).dx,
      greaterThan(tester.getCenter(themeRow).dx),
    );
    expect(
      find.descendant(of: themeItems, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });
}
