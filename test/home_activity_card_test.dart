import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/domain/models/listening_statistics.dart';
import 'package:lumina/presentation/screens/library/home_activity_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    Map<DateTime, int> minutesByDay,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: HomeActivityCard(
            dailyMs: {
              for (final entry in minutesByDay.entries)
                listeningDateKey(entry.key): entry.value * 60000,
            },
            goalMinutes: 30,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the current streak above the heat map', (tester) async {
    final today = DateTime.now();
    await pumpCard(tester, {
      today: 20,
      today.subtract(const Duration(days: 1)): 35,
      today.subtract(const Duration(days: 2)): 5,
    });

    expect(find.text('3-day streak'), findsOneWidget);
    // 18 weeks of seven days.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-activity-card')),
        matching: find.byType(Tooltip),
      ),
      findsNWidgets(18 * 7),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invites a first session when there is no streak', (
    tester,
  ) async {
    await pumpCard(tester, const {});

    expect(find.text('Listen today to start a streak'), findsOneWidget);
    expect(find.text('0m this week'), findsOneWidget);
  });
}
