import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

const _dailyMinutesKey = 'goal_daily_minutes';
const _yearlyBooksKey = 'goal_yearly_books';

const dailyGoalPresets = [15, 30, 45, 60, 90];
const yearlyGoalPresets = [12, 24, 36, 52];

/// Targets the profile page measures against. They drive the progress ring and
/// the pacing copy only — nothing in the app is gated on them.
class ListeningGoals {
  final int dailyMinutes;
  final int yearlyBooks;
  final bool loaded;

  const ListeningGoals({
    this.dailyMinutes = 30,
    this.yearlyBooks = 12,
    this.loaded = false,
  });

  static const int minDailyMinutes = 10;
  static const int maxDailyMinutes = 240;
  static const int minYearlyBooks = 4;
  static const int maxYearlyBooks = 120;

  ListeningGoals copyWith({int? dailyMinutes, int? yearlyBooks, bool? loaded}) {
    return ListeningGoals(
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      yearlyBooks: yearlyBooks ?? this.yearlyBooks,
      loaded: loaded ?? this.loaded,
    );
  }
}

class ListeningGoalsController extends Notifier<ListeningGoals> {
  @override
  ListeningGoals build() => const ListeningGoals();

  Future<void> load() async {
    if (state.loaded) return;
    final database = ref.read(appDatabaseProvider);
    final daily = int.tryParse(
      await database.getSetting(_dailyMinutesKey) ?? '',
    );
    final yearly = int.tryParse(
      await database.getSetting(_yearlyBooksKey) ?? '',
    );
    state = state.copyWith(
      dailyMinutes: daily == null ? state.dailyMinutes : clampDaily(daily),
      yearlyBooks: yearly == null ? state.yearlyBooks : clampYearly(yearly),
      loaded: true,
    );
  }

  Future<void> setDailyMinutes(int minutes) async {
    final value = clampDaily(minutes);
    state = state.copyWith(dailyMinutes: value, loaded: true);
    await ref.read(appDatabaseProvider).setSetting(_dailyMinutesKey, '$value');
  }

  Future<void> setYearlyBooks(int books) async {
    final value = clampYearly(books);
    state = state.copyWith(yearlyBooks: value, loaded: true);
    await ref.read(appDatabaseProvider).setSetting(_yearlyBooksKey, '$value');
  }

  static int clampDaily(int value) => value.clamp(
    ListeningGoals.minDailyMinutes,
    ListeningGoals.maxDailyMinutes,
  );

  static int clampYearly(int value) =>
      value.clamp(ListeningGoals.minYearlyBooks, ListeningGoals.maxYearlyBooks);
}

final listeningGoalsProvider =
    NotifierProvider<ListeningGoalsController, ListeningGoals>(
      ListeningGoalsController.new,
    );
