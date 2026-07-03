import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/domain/models/listening_statistics.dart';

void main() {
  test('calculates totals and a streak ending today', () {
    final summary = ListeningSummary.fromDailyMs({
      '2026-06-27': 60000,
      '2026-06-28': 120000,
      '2026-06-29': 180000,
      '2026-06-30': 240000,
    }, now: DateTime(2026, 6, 30, 12));

    expect(summary.totalMs, 600000);
    expect(summary.todayMs, 240000);
    expect(summary.activeDays, 4);
    expect(summary.currentStreak, 4);
    expect(summary.longestStreak, 4);
  });

  test('keeps the current streak alive until the end of today', () {
    final summary = ListeningSummary.fromDailyMs({
      '2026-06-27': 60000,
      '2026-06-28': 60000,
      '2026-06-29': 60000,
    }, now: DateTime(2026, 6, 30, 12));

    expect(summary.currentStreak, 3);
    expect(summary.todayMs, 0);
  });

  test('resets a streak after a missed day', () {
    final summary = ListeningSummary.fromDailyMs({
      '2026-06-26': 60000,
      '2026-06-27': 60000,
      '2026-06-29': 60000,
    }, now: DateTime(2026, 6, 30, 12));

    expect(summary.currentStreak, 1);
    expect(summary.longestStreak, 2);
  });
}
