import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/domain/models/listening_statistics.dart';
import 'package:lumina/presentation/screens/library/home_activity_card.dart';

void main() {
  Future<void> pumpWeek(
    WidgetTester tester,
    Map<DateTime, int> minutesByDay,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: HomeWeekActivity(
            dailyMs: {
              for (final entry in minutesByDay.entries)
                listeningDateKey(entry.key): entry.value * 60000,
            },
          ),
        ),
      ),
    );
  }

  testWidgets('shows the streak and the week, one bar per day', (tester) async {
    final today = DateTime.now();
    await pumpWeek(tester, {today: 20});

    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('1-day streak · 20m'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-week-activity')),
        matching: find.byType(Semantics),
      ),
      findsAtLeastNWidgets(7),
    );
    expect(find.bySemanticsLabel(RegExp(r', 20m$')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invites a first session when there is no streak', (
    tester,
  ) async {
    await pumpWeek(tester, const {});

    expect(find.text('Listen today to start a streak'), findsOneWidget);
  });
}
