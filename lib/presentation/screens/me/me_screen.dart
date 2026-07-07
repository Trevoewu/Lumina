import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../domain/models/listening_statistics.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../settings/settings_screen.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  late final Stream<List<drift_db.ListeningDay>> _listeningDaysStream;
  late final Stream<List<drift_db.Book>> _booksStream;

  @override
  void initState() {
    super.initState();
    final database = ref.read(appDatabaseProvider);
    _listeningDaysStream = database.watchListeningDays();
    _booksStream = database.watchAllBooks();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

    return CollapsingPageScaffold(
      title: context.tr('我的', 'Me'),
      actions: [
        Tooltip(
          message: context.tr('设置', 'Settings'),
          child: IconButton(
            icon: Icon(Icons.settings_outlined, size: 28),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ),
      ],
      body: StreamBuilder<List<drift_db.ListeningDay>>(
        stream: _listeningDaysStream,
        initialData: const [],
        builder: (context, listeningSnapshot) {
          final days = listeningSnapshot.data ?? const [];
          final dailyMs = {for (final day in days) day.dateKey: day.listenedMs};
          final summary = ListeningSummary.fromDailyMs(dailyMs);

          return StreamBuilder<List<drift_db.Book>>(
            stream: _booksStream,
            initialData: const [],
            builder: (context, booksSnapshot) {
              final books = booksSnapshot.data ?? const [];
              return ListView(
                padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 40),
                children: [
                  _TodaySummary(summary: summary, accent: accent),
                  const SizedBox(height: 12),
                  _StatisticsGrid(
                    summary: summary,
                    bookCount: books.length,
                    accent: accent,
                  ),
                  SizedBox(height: design.spaceXl),
                  _SectionTitle(
                    title: context.tr('收听活动', 'Listening activity'),
                    subtitle: context.tr(
                      '${summary.activeDays} 个活跃日',
                      '${summary.activeDays} active days',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ListeningHeatmap(dailyMs: dailyMs, accent: accent),
                  SizedBox(height: design.spaceXl),
                  _ListeningOverview(summary: summary, accent: accent),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  final ListeningSummary summary;
  final Color accent;

  const _TodaySummary({required this.summary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(context.appDesign.radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.headphones_rounded, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('今天', 'Today'),
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatListeningTime(summary.todayMs),
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.local_fire_department_outlined, color: accent),
          const SizedBox(width: 6),
          Text(
            '${summary.currentStreak}',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsGrid extends StatelessWidget {
  final ListeningSummary summary;
  final int bookCount;
  final Color accent;

  const _StatisticsGrid({
    required this.summary,
    required this.bookCount,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatisticData(
        label: context.tr('收听时长', 'Listening time'),
        value: _formatListeningTime(summary.totalMs),
        icon: Icons.schedule,
      ),
      _StatisticData(
        label: context.tr('连续收听', 'Current streak'),
        value: context.tr(
          '${summary.currentStreak} 天',
          '${summary.currentStreak} d',
        ),
        icon: Icons.local_fire_department_outlined,
      ),
      _StatisticData(
        label: context.tr('收听天数', 'Listening days'),
        value: '${summary.activeDays}',
        icon: Icons.calendar_today_outlined,
      ),
      _StatisticData(
        label: context.tr('书籍', 'Books'),
        value: '$bookCount',
        icon: Icons.library_books_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                height: 112,
                child: _StatisticTile(data: item, accent: accent),
              ),
          ],
        );
      },
    );
  }
}

class _StatisticData {
  final String label;
  final String value;
  final IconData icon;

  const _StatisticData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _StatisticTile extends StatelessWidget {
  final _StatisticData data;
  final Color accent;

  const _StatisticTile({required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(context.appDesign.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(color: context.appTextSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _ListeningHeatmap extends StatelessWidget {
  final Map<String, int> dailyMs;
  final Color accent;

  const _ListeningHeatmap({required this.dailyMs, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(context.appDesign.radiusMedium),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final weekCount = (constraints.maxWidth / 20).floor().clamp(12, 26);
          final gap = 3.0;
          final cellSize = math.min(
            16.0,
            (constraints.maxWidth - (weekCount - 1) * gap) / weekCount,
          );
          final today = dateOnly(DateTime.now());
          final start = today.subtract(
            Duration(days: (weekCount - 1) * 7 + today.weekday - 1),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var week = 0; week < weekCount; week++)
                    Column(
                      children: [
                        for (var weekday = 0; weekday < 7; weekday++) ...[
                          _HeatCell(
                            date: start.add(Duration(days: week * 7 + weekday)),
                            today: today,
                            listenedMs:
                                dailyMs[listeningDateKey(
                                  start.add(Duration(days: week * 7 + weekday)),
                                )] ??
                                0,
                            accent: accent,
                            size: cellSize,
                          ),
                          if (weekday < 6) SizedBox(height: gap),
                        ],
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    context.tr('少', 'Less'),
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 7),
                  for (final opacity in const [0.08, 0.28, 0.5, 0.75, 1.0]) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: opacity == 0.08
                            ? context.appSurfaceHighlight
                            : accent.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const SizedBox(width: 3),
                  Text(
                    context.tr('多', 'More'),
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final int listenedMs;
  final Color accent;
  final double size;

  const _HeatCell({
    required this.date,
    required this.today,
    required this.listenedMs,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isFuture = date.isAfter(today);
    final minutes = listenedMs / 60000;
    final opacity = minutes >= 60
        ? 1.0
        : minutes >= 30
        ? 0.75
        : minutes >= 15
        ? 0.5
        : minutes > 0
        ? 0.28
        : 0.0;
    final color = isFuture
        ? Colors.transparent
        : opacity == 0
        ? context.appSurfaceHighlight
        : accent.withValues(alpha: opacity);

    return Tooltip(
      message:
          '${listeningDateKey(date)} · ${_formatListeningTime(listenedMs)}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _ListeningOverview extends StatelessWidget {
  final ListeningSummary summary;
  final Color accent;

  const _ListeningOverview({required this.summary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(context.appDesign.radiusMedium),
      ),
      child: Column(
        children: [
          _OverviewRow(
            icon: Icons.date_range_outlined,
            label: context.tr('本周', 'This week'),
            value: _formatListeningTime(summary.thisWeekMs),
            accent: accent,
          ),
          Divider(height: 1, color: context.appSurfaceHighlight),
          _OverviewRow(
            icon: Icons.emoji_events_outlined,
            label: context.tr('最长连续收听', 'Longest streak'),
            value: context.tr(
              '${summary.longestStreak} 天',
              '${summary.longestStreak} days',
            ),
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: accent),
      title: Text(
        label,
        style: TextStyle(
          color: context.appTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          color: context.appTextSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatListeningTime(int milliseconds) {
  if (milliseconds <= 0) return '0m';
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (duration.inMinutes > 0) return '${duration.inMinutes}m';
  return '<1m';
}
