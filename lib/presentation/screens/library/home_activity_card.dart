import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../domain/models/listening_statistics.dart';
import '../../widgets/design_system/editorial_type.dart';

/// Height of a day that reached the scale's top.
const _barMaxHeight = 36.0;
const _barWidth = 8.0;

/// The least a full-height bar can stand for.
const _scaleFloorMs = 15 * 60000;

/// The one piece of the old Me tab worth keeping in view: this week's
/// listening, Monday to Sunday, with the current streak. It sits flat on the
/// page under a kicker like Home's other sections. Home loads the listening
/// days with the rest of its data and refreshes them on the same reloads.
class HomeWeekActivity extends StatelessWidget {
  final Map<String, int> dailyMs;

  const HomeWeekActivity({super.key, required this.dailyMs});

  @override
  Widget build(BuildContext context) {
    final summary = ListeningSummary.fromDailyMs(dailyMs);
    final today = dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final dayMs = [for (final day in days) dailyMs[listeningDateKey(day)] ?? 0];
    // The week's longest day fills the height, so ordinary days still read
    // as bars; the floor keeps one short session from looking like a lot.
    final scaleMs = math.max(_scaleFloorMs, dayMs.reduce(math.max));

    return Column(
      key: const ValueKey('home-week-activity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              context.tr('本周', 'THIS WEEK', '今週'),
              style: kickerTextStyle(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _summaryLine(context, summary),
                key: const ValueKey('home-week-summary'),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: technicalTextStyle(context, size: 12, alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (index, day) in days.indexed)
              Expanded(
                child: _DayBar(
                  date: day,
                  listenedMs: dayMs[index],
                  scaleMs: scaleMs,
                  isToday: day == today,
                  isFuture: day.isAfter(today),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _summaryLine(BuildContext context, ListeningSummary summary) {
    final streak = summary.currentStreak;
    if (streak == 0 && summary.thisWeekMs == 0) {
      return context.tr(
        '今天听一会儿，开始连续记录',
        'Listen today to start a streak',
        '今日聴いて連続記録を始めましょう',
      );
    }
    final week = formatListeningTime(summary.thisWeekMs);
    if (streak == 0) return week;
    return '${context.tr('连续 $streak 天', '$streak-day streak', '$streak日連続')}'
        ' · $week';
  }
}

class _DayBar extends StatelessWidget {
  final DateTime date;
  final int listenedMs;
  final int scaleMs;
  final bool isToday;
  final bool isFuture;

  const _DayBar({
    required this.date,
    required this.listenedMs,
    required this.scaleMs,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;
    final listened = listenedMs > 0;
    // An empty or upcoming day is a faint dot, so the week reads as a row.
    final height = listened
        ? math.max(_barWidth, _barMaxHeight * listenedMs / scaleMs)
        : _barWidth / 2;
    final color = !listened
        ? ink.withValues(alpha: isFuture ? 0.06 : 0.14)
        : isToday
        ? accent
        : accent.withValues(alpha: 0.45);

    return Semantics(
      label:
          '${localizations.formatFullDate(date)}, '
          '${formatListeningTime(listenedMs)}',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: _barMaxHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: listened ? _barWidth : _barWidth / 2,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(_barWidth / 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // Narrow weekdays start on Sunday.
            localizations.narrowWeekdays[date.weekday % 7],
            style: technicalTextStyle(
              context,
              size: 11,
              alpha: isToday ? 0.85 : 0.4,
              weight: isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
