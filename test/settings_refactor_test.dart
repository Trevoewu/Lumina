import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
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
}
