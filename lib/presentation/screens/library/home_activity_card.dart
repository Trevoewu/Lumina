import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../domain/models/listening_statistics.dart';

/// Weeks of history in the activity heat map.
const _heatmapWeeks = 18;

/// The one piece of the old Me tab worth keeping in view: the current streak
/// and the listening heat map, together on Home. Home loads the listening
/// days with the rest of its data and refreshes them on the same reloads.
class HomeActivityCard extends StatelessWidget {
  final Map<String, int> dailyMs;
  final int goalMinutes;

  const HomeActivityCard({
    super.key,
    required this.dailyMs,
    required this.goalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final summary = ListeningSummary.fromDailyMs(dailyMs);

    return Container(
      key: const ValueKey('home-activity-card'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StreakLine(summary: summary),
          const SizedBox(height: 14),
          _Heatmap(dailyMs: dailyMs, goalMinutes: goalMinutes),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }
}

class _StreakLine extends StatelessWidget {
  final ListeningSummary summary;

  const _StreakLine({required this.summary});

  @override
  Widget build(BuildContext context) {
    final streak = summary.currentStreak;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            streak > 0
                ? context.tr(
                    '连续收听 $streak 天',
                    '$streak-day streak',
                    '$streak日連続',
                  )
                : context.tr(
                    '今天听一会儿，开始连续记录',
                    'Listen today to start a streak',
                    '今日聴いて連続記録を始めましょう',
                  ),
            key: const ValueKey('home-activity-streak'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.appTextPrimary,
            ),
          ),
        ),
        Text(
          context.tr(
            '本周 ${formatListeningTime(summary.thisWeekMs)}',
            '${formatListeningTime(summary.thisWeekMs)} this week',
            '今週 ${formatListeningTime(summary.thisWeekMs)}',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.appTextSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Heatmap extends StatelessWidget {
  final Map<String, int> dailyMs;
  final int goalMinutes;

  const _Heatmap({required this.dailyMs, required this.goalMinutes});

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final start = today.subtract(
      Duration(days: (_heatmapWeeks - 1) * 7 + today.weekday - 1),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        final cell = math.min(
          14.0,
          (constraints.maxWidth - (_heatmapWeeks - 1) * gap) / _heatmapWeeks,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var week = 0; week < _heatmapWeeks; week++)
              Column(
                children: [
                  for (var weekday = 0; weekday < 7; weekday++) ...[
                    if (weekday > 0) const SizedBox(height: gap),
                    _HeatCell(
                      date: start.add(Duration(days: week * 7 + weekday)),
                      today: today,
                      listenedMs:
                          dailyMs[listeningDateKey(
                            start.add(Duration(days: week * 7 + weekday)),
                          )] ??
                          0,
                      goalMinutes: goalMinutes,
                      size: cell,
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

Color _levelColor(BuildContext context, int level) => level == 0
    ? context.appTextPrimary.withValues(alpha: 0.07)
    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.18 + level * 0.2);

class _HeatCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final int listenedMs;
  final int goalMinutes;
  final double size;

  const _HeatCell({
    required this.date,
    required this.today,
    required this.listenedMs,
    required this.goalMinutes,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = listenedMs / 60000;
    final level = minutes >= goalMinutes
        ? 4
        : minutes >= goalMinutes * 0.66
        ? 3
        : minutes >= goalMinutes * 0.33
        ? 2
        : minutes > 0
        ? 1
        : 0;

    return Tooltip(
      message: '${listeningDateKey(date)} · ${formatListeningTime(listenedMs)}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: date.isAfter(today)
              ? Colors.transparent
              : _levelColor(context, level),
          borderRadius: BorderRadius.circular(3.5),
          // A ring marks the days that met the daily goal.
          border: level >= 4
              ? Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.85),
                  width: 1.5,
                )
              : null,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w400,
      color: context.appTextSecondary,
    );

    return Row(
      children: [
        Text(context.tr('少', 'Less', '少ない'), style: style),
        const SizedBox(width: 6),
        for (final level in const [0, 1, 2, 3, 4]) ...[
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: _levelColor(context, level),
              borderRadius: BorderRadius.circular(3.5),
            ),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 2),
        Text(context.tr('多', 'More', '多い'), style: style),
      ],
    );
  }
}
