import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/listening_statistics.dart';
import 'package:lumina/presentation/screens/me/me_screen.dart';

void main() {
  testWidgets('profile ring follows the saved daily goal', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.listeningDays)
        .insert(
          ListeningDaysCompanion.insert(
            dateKey: listeningDateKey(DateTime.now()),
            listenedMs: const Value(20 * 60000),
            updatedAt: 1,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(theme: AppTheme.darkTheme(), home: const MeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 20 of the default 30 minutes.
    expect(find.text('20'), findsOneWidget);
    expect(find.text('/ 30 MIN'), findsOneWidget);
    expect(find.text('10 min to go'), findsOneWidget);
    for (final (label, weight) in [
      ('20', FontWeight.w600),
      ('10 min to go', FontWeight.w500),
      ('Adjust goal', FontWeight.w500),
    ]) {
      expect(
        tester.widget<Text>(find.text(label)).style?.fontWeight,
        weight,
        reason: label,
      );
    }

    await tester.tap(find.byKey(const ValueKey('me-adjust-goals')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-goals-sheet')), findsOneWidget);
    for (final (label, weight) in [
      ('Save goals', FontWeight.w500),
      ('15', FontWeight.normal),
    ]) {
      expect(
        tester.widget<Text>(find.text(label)).style?.fontWeight,
        weight,
        reason: label,
      );
    }

    await tester.tap(find.widgetWithText(GestureDetector, '15').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-goals-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('me-goals-sheet')), findsNothing);
    expect(find.text('/ 15 MIN'), findsOneWidget);
    expect(find.text('Goal reached today'), findsOneWidget);
    expect(await database.getSetting('goal_daily_minutes'), '15');

    // Let the drift stream subscriptions tear down before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
