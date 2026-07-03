class ListeningSummary {
  final int totalMs;
  final int todayMs;
  final int thisWeekMs;
  final int activeDays;
  final int currentStreak;
  final int longestStreak;

  const ListeningSummary({
    required this.totalMs,
    required this.todayMs,
    required this.thisWeekMs,
    required this.activeDays,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory ListeningSummary.fromDailyMs(
    Map<String, int> dailyMs, {
    DateTime? now,
  }) {
    final today = dateOnly((now ?? DateTime.now()).toLocal());
    final activeDates = dailyMs.entries
        .where((entry) => entry.value > 0)
        .map((entry) => parseDateKey(entry.key))
        .whereType<DateTime>()
        .map(dateOnly)
        .toSet();
    final normalizedMs = <String, int>{
      for (final entry in dailyMs.entries)
        if (entry.value > 0) entry.key: entry.value,
    };

    var streakCursor = today;
    if (!activeDates.contains(streakCursor)) {
      streakCursor = streakCursor.subtract(const Duration(days: 1));
    }
    var currentStreak = 0;
    while (activeDates.contains(streakCursor)) {
      currentStreak++;
      streakCursor = streakCursor.subtract(const Duration(days: 1));
    }

    var longestStreak = 0;
    var runningStreak = 0;
    DateTime? previous;
    final sortedDates = activeDates.toList()..sort();
    for (final date in sortedDates) {
      if (previous != null && date.difference(previous).inDays == 1) {
        runningStreak++;
      } else {
        runningStreak = 1;
      }
      if (runningStreak > longestStreak) longestStreak = runningStreak;
      previous = date;
    }

    final monday = today.subtract(Duration(days: today.weekday - 1));
    final thisWeekMs = normalizedMs.entries.fold<int>(0, (total, entry) {
      final date = parseDateKey(entry.key);
      if (date == null || date.isBefore(monday) || date.isAfter(today)) {
        return total;
      }
      return total + entry.value;
    });

    return ListeningSummary(
      totalMs: normalizedMs.values.fold(0, (sum, value) => sum + value),
      todayMs: normalizedMs[listeningDateKey(today)] ?? 0,
      thisWeekMs: thisWeekMs,
      activeDays: activeDates.length,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String listeningDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime? parseDateKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}
