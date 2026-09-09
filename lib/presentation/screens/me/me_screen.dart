import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_sheet.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/listening_goals.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../domain/models/listening_statistics.dart';
import '../../widgets/design_system/editorial_type.dart';
import '../settings/settings_screen.dart';

/// Weeks of history in the activity heat map.
const _heatmapWeeks = 18;

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  late final Stream<List<drift_db.ListeningDay>> _listeningDaysStream;
  late final Stream<int> _readBookCountStream;
  int _savedWordCount = 0;

  @override
  void initState() {
    super.initState();
    final database = ref.read(appDatabaseProvider);
    _listeningDaysStream = database.watchListeningDays();
    _readBookCountStream = database.watchReadBookCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listeningGoalsProvider.notifier).load();
      _loadSavedWordCount();
    });
  }

  Future<void> _loadSavedWordCount() async {
    final favorites = await ref.read(dictionaryRepositoryProvider).favorites();
    if (mounted) setState(() => _savedWordCount = favorites.length);
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final listGutter = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final gutter = listGutter + 6;
    final goals = ref.watch(listeningGoalsProvider);

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<drift_db.ListeningDay>>(
          stream: _listeningDaysStream,
          initialData: const [],
          builder: (context, listeningSnapshot) {
            final days = listeningSnapshot.data ?? const [];
            final dailyMs = {
              for (final day in days) day.dateKey: day.listenedMs,
            };
            final summary = ListeningSummary.fromDailyMs(dailyMs);

            return StreamBuilder<int>(
              stream: _readBookCountStream,
              initialData: 0,
              builder: (context, booksSnapshot) {
                final booksRead = booksSnapshot.data ?? 0;

                return ListView(
                  key: const PageStorageKey('me-overview-list'),
                  padding: EdgeInsets.only(
                    top: 18,
                    bottom: MediaQuery.paddingOf(context).bottom + 20,
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: gutter),
                      child: _Header(
                        summary: summary,
                        onSettings: _openSettings,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        listGutter,
                        20,
                        listGutter,
                        0,
                      ),
                      child: _TodayCard(
                        summary: summary,
                        dailyMs: dailyMs,
                        goals: goals,
                        onAdjustGoals: _openGoals,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 26, gutter, 0),
                      child: _SectionHeader(
                        label: context.tr(
                          '${DateTime.now().year} 年度书目',
                          '${DateTime.now().year} BOOKS',
                          '${DateTime.now().year}年の読書数',
                        ),
                        trailing: context.tr(
                          '目标 ${goals.yearlyBooks} 本',
                          'Goal ${goals.yearlyBooks}',
                          '目標: ${goals.yearlyBooks}冊',
                        ),
                        onTrailingTap: _openGoals,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        listGutter,
                        12,
                        listGutter,
                        0,
                      ),
                      child: _YearBooksCard(
                        booksRead: booksRead,
                        goal: goals.yearlyBooks,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 26, gutter, 0),
                      child: Text(
                        context.tr('总览', 'OVERVIEW', '概要'),
                        style: kickerTextStyle(context),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        listGutter,
                        12,
                        listGutter,
                        0,
                      ),
                      child: _StatGrid(
                        summary: summary,
                        savedWordCount: _savedWordCount,
                      ),
                    ),
                    ..._buildBadges(
                      gutter,
                      listGutter,
                      summary: summary,
                      booksRead: booksRead,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 26, gutter, 0),
                      child: _SectionHeader(
                        label: context.tr('收听记录', 'ACTIVITY', '視聴履歴'),
                        trailing: context.tr(
                          '${summary.activeDays} 天有记录',
                          '${summary.activeDays} active days',
                          '${summary.activeDays}日視聴',
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        listGutter,
                        12,
                        listGutter,
                        0,
                      ),
                      child: _HeatmapCard(
                        dailyMs: dailyMs,
                        goalMinutes: goals.dailyMinutes,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBadges(
    double gutter,
    double listGutter, {
    required ListeningSummary summary,
    required int booksRead,
  }) {
    final badges = _badgesFor(
      context,
      summary: summary,
      booksRead: booksRead,
      savedWordCount: _savedWordCount,
    );
    final earned = badges.where((badge) => badge.earned).length;

    return [
      Padding(
        padding: EdgeInsets.fromLTRB(gutter, 26, gutter, 0),
        child: _SectionHeader(
          label: context.tr('徽章', 'BADGES', 'バッジ'),
          trailing: '$earned / ${badges.length}',
        ),
      ),
      SizedBox(
        height: 132,
        child: ListView.separated(
          key: const ValueKey('me-badge-strip'),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(listGutter, 12, listGutter, 2),
          itemCount: badges.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) => _BadgeCard(badge: badges[index]),
        ),
      ),
    ];
  }

  void _openGoals() {
    showAppSheet<void>(context: context, builder: (_) => const _GoalsSheet());
  }

  void _openSettings() {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    if (isMac) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } else {
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }
}

class _Header extends StatelessWidget {
  final ListeningSummary summary;
  final VoidCallback onSettings;

  const _Header({required this.summary, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final hours = summary.totalMs ~/ 3600000;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('我的', 'Me', 'マイページ'),
                style: TextStyle(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.tr(
                  '连续 ${summary.currentStreak} 天 · 累计 $hours 小时',
                  '${summary.currentStreak}-day streak · $hours h total',
                  '${summary.currentStreak}日連続 · 合計$hours時間',
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: ink.withValues(alpha: 0.42),
                ),
              ),
            ],
          ),
        ),
        _SquareIconButton(
          key: const ValueKey('me-settings-action'),
          icon: AppIcons.settings02,
          tooltip: context.tr('设置', 'Settings', '設定'),
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final AppIconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(13),
          ),
          child: AppIcon(icon, size: 19, color: ink),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String trailing;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.label,
    required this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    final trailingText = Text(
      trailing,
      style: technicalTextStyle(
        context,
        size: 12.5,
        alpha: 0.35,
        weight: FontWeight.w400,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: kickerTextStyle(context))),
        if (onTrailingTap == null)
          trailingText
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTrailingTap,
            child: trailingText,
          ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  final ListeningSummary summary;
  final Map<String, int> dailyMs;
  final ListeningGoals goals;
  final VoidCallback onAdjustGoals;

  const _TodayCard({
    required this.summary,
    required this.dailyMs,
    required this.goals,
    required this.onAdjustGoals,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;
    final todayMinutes = summary.todayMs ~/ 60000;
    final progress = (todayMinutes / goals.dailyMinutes).clamp(0.0, 1.0);
    final done = todayMinutes >= goals.dailyMinutes;
    final remaining = math.max(0, goals.dailyMinutes - todayMinutes);
    final weekMinutes = summary.thisWeekMs ~/ 60000;

    return _Card(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: done ? 0.22 : 0.10),
                      accent.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.66],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('me-daily-ring'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onAdjustGoals,
                    child: SizedBox(
                      width: 118,
                      height: 118,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: progress,
                          accent: accent,
                          track: ink.withValues(alpha: 0.07),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$todayMinutes',
                              style: TextStyle(
                                fontSize: 30,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '/ ${goals.dailyMinutes} MIN',
                              style: technicalTextStyle(
                                context,
                                size: 10.5,
                                alpha: 0.35,
                              ).copyWith(letterSpacing: 1.05),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('今天', 'TODAY', '今日'),
                          style: kickerTextStyle(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          done
                              ? context.tr(
                                  '今天目标已完成',
                                  'Goal reached today',
                                  '今日の目標を達成しました',
                                )
                              : context.tr(
                                  '再听 $remaining 分钟达标',
                                  '$remaining min to go',
                                  'あと$remaining分で達成',
                                ),
                          style: TextStyle(
                            fontSize: 21,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.21,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          done
                              ? context.tr(
                                  '连续第 ${summary.currentStreak} 天达标，本周已听 $weekMinutes 分钟。',
                                  'Day ${summary.currentStreak} of your streak · $weekMinutes min this week.',
                                  '連続${summary.currentStreak}日目を達成 · 今週$weekMinutes分',
                                )
                              : context.tr(
                                  '已完成 ${(progress * 100).round()}%，本周已听 $weekMinutes 分钟。',
                                  '${(progress * 100).round()}% done · $weekMinutes min this week.',
                                  '${(progress * 100).round()}%完了 · 今週$weekMinutes分',
                                ),
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: ink.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          key: const ValueKey('me-adjust-goals'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onAdjustGoals,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  AppIcons.arrowUpRight01,
                                  size: 13,
                                  color: ink.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  context.tr('调整目标', 'Adjust goal', '目標を調整'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: ink.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Container(height: 1, color: ink.withValues(alpha: 0.06)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _WeekRow(
                  dailyMs: dailyMs,
                  goalMinutes: goals.dailyMinutes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final Map<String, int> dailyMs;
  final int goalMinutes;

  const _WeekRow({required this.dailyMs, required this.goalMinutes});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;
    final today = dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final labels = context.usesChinese
        ? const ['一', '二', '三', '四', '五', '六', '日']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < 7; index++)
          Builder(
            builder: (context) {
              final date = monday.add(Duration(days: index));
              final minutes = (dailyMs[listeningDateKey(date)] ?? 0) ~/ 60000;
              final progress = (minutes / goalMinutes).clamp(0.0, 1.0);
              final hit = minutes >= goalMinutes;
              return Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: hit
                          ? accent
                          : progress > 0
                          ? accent.withValues(alpha: 0.18 + progress * 0.2)
                          : ink.withValues(alpha: 0.06),
                    ),
                    child: hit
                        ? AppIcon(
                            AppIcons.tick02,
                            size: 15,
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[index],
                    style: technicalTextStyle(
                      context,
                      size: 11.5,
                      alpha: hit ? 1 : 0.35,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _YearBooksCard extends StatelessWidget {
  final int booksRead;
  final int goal;

  const _YearBooksCard({required this.booksRead, required this.goal});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final percent = goal <= 0
        ? 0
        : math.min(100, ((booksRead / goal) * 100).round());
    final spineCount = math.min(24, math.max(goal, booksRead));

    return _Card(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$booksRead',
                style: TextStyle(
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: ink,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  context.tr('本已读完', 'finished', '読了'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink.withValues(alpha: 0.42),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '$percent%',
                  style: technicalTextStyle(context, size: 12.5, alpha: 0.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < spineCount; index++) ...[
                  if (index > 0) const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: index < booksRead
                          ? 34 + ((index * 37) % 5) * 6
                          : 26 + ((index * 37) % 5) * 6,
                      decoration: BoxDecoration(
                        color: index < booksRead
                            ? ink
                            : ink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(
                AppIcons.clock01,
                size: 14,
                color: ink.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pacingLine(context, booksRead: booksRead, goal: goal),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: ink.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compares finished books against where the year's pace says you should be.
  String _pacingLine(
    BuildContext context, {
    required int booksRead,
    required int goal,
  }) {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year);
    final endOfYear = DateTime(now.year + 1);
    final yearFraction =
        now.difference(startOfYear).inMinutes /
        endOfYear.difference(startOfYear).inMinutes;
    final expected = goal * yearFraction;
    final difference = booksRead - expected;
    final monthsLeft = math.max(0.5, 12 - yearFraction * 12);

    if (difference >= 0) {
      final projected = yearFraction <= 0
          ? booksRead
          : (booksRead / yearFraction).round();
      return context.tr(
        '领先计划 ${difference.toStringAsFixed(1)} 本，按当前节奏年底约 $projected 本。',
        '${difference.toStringAsFixed(1)} books ahead — about $projected by year end at this pace.',
        '計画より${difference.toStringAsFixed(1)}冊先行 · このペースなら年末に約$projected冊',
      );
    }
    final perMonth = (goal - booksRead) / monthsLeft;
    return context.tr(
      '落后计划 ${(-difference).toStringAsFixed(1)} 本，每月 ${perMonth.toStringAsFixed(1)} 本可追平。',
      '${(-difference).toStringAsFixed(1)} books behind — ${perMonth.toStringAsFixed(1)} a month catches up.',
      '計画より${(-difference).toStringAsFixed(1)}冊遅れ · 毎月${perMonth.toStringAsFixed(1)}冊で追いつけます',
    );
  }
}

class _StatGrid extends StatelessWidget {
  final ListeningSummary summary;
  final int savedWordCount;

  const _StatGrid({required this.summary, required this.savedWordCount});

  @override
  Widget build(BuildContext context) {
    final hours = summary.totalMs ~/ 3600000;
    final items = <_StatData>[
      _StatData(
        label: context.tr('累计时长', 'TOTAL TIME', '合計時間'),
        value: '$hours',
        unit: context.tr('小时', 'h', '時間'),
      ),
      _StatData(
        label: context.tr('最长连续', 'LONGEST STREAK', '最長連続'),
        value: '${summary.longestStreak}',
        unit: context.tr('天', 'd', '日'),
      ),
      _StatData(
        label: context.tr('收听天数', 'ACTIVE DAYS', '視聴日数'),
        value: '${summary.activeDays}',
        unit: context.tr('天', 'd', '日'),
      ),
      _StatData(
        label: context.tr('生词本', 'SAVED WORDS', '単語帳'),
        value: '$savedWordCount',
        unit: context.tr('个', '', '語'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _StatCard(data: item),
              ),
          ],
        );
      },
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final String unit;

  const _StatData({
    required this.label,
    required this.value,
    required this.unit,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return _Card(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kickerTextStyle(context).copyWith(letterSpacing: 1.05),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.52,
                  color: ink,
                ),
              ),
              if (data.unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  data.unit,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ink.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge {
  final AppIconData icon;
  final String title;
  final String meta;
  final bool earned;

  const _Badge({
    required this.icon,
    required this.title,
    required this.meta,
    required this.earned,
  });
}

List<_Badge> _badgesFor(
  BuildContext context, {
  required ListeningSummary summary,
  required int booksRead,
  required int savedWordCount,
}) {
  return [
    _Badge(
      icon: AppIcons.fire,
      title: context.tr('连续 7 天', '7-day streak', '7日連続'),
      meta: summary.longestStreak >= 7
          ? context.tr('已达成', 'Earned', '達成済み')
          : context.tr(
              '还差 ${7 - summary.longestStreak} 天',
              '${7 - summary.longestStreak} days to go',
              'あと${7 - summary.longestStreak}日',
            ),
      earned: summary.longestStreak >= 7,
    ),
    _Badge(
      icon: AppIcons.bookOpen02,
      title: context.tr('第一本读完', 'First book', '最初の1冊'),
      meta: booksRead > 0
          ? context.tr(
              '已读完 $booksRead 本',
              '$booksRead finished',
              '$booksRead冊を読了',
            )
          : context.tr('还没有读完的书', 'None finished yet', '未読了の本はありません'),
      earned: booksRead > 0,
    ),
    _Badge(
      icon: AppIcons.bookmark02,
      title: context.tr('生词 100', '100 words', '単語100個'),
      meta: savedWordCount >= 100
          ? context.tr('已达成', 'Earned', '達成済み')
          : context.tr(
              '还差 ${100 - savedWordCount} 个',
              '${100 - savedWordCount} to go',
              'あと${100 - savedWordCount}語',
            ),
      earned: savedWordCount >= 100,
    ),
    _Badge(
      icon: AppIcons.champion,
      title: context.tr('连续 30 天', '30-day streak', '30日連続'),
      meta: summary.longestStreak >= 30
          ? context.tr('已达成', 'Earned', '達成済み')
          : context.tr(
              '还差 ${30 - summary.longestStreak} 天',
              '${30 - summary.longestStreak} days to go',
              'あと${30 - summary.longestStreak}日',
            ),
      earned: summary.longestStreak >= 30,
    ),
  ];
}

class _BadgeCard extends StatelessWidget {
  final _Badge badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;

    return Opacity(
      opacity: badge.earned ? 1 : 0.6,
      child: SizedBox(
        width: 132,
        child: _Card(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(15, 16, 15, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badge.earned
                      ? accent.withValues(alpha: 0.16)
                      : ink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AppIcon(
                  badge.icon,
                  size: 21,
                  color: badge.earned ? ink : ink.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                badge.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                badge.meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: technicalTextStyle(
                  context,
                  size: 11.5,
                  alpha: 0.35,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  final Map<String, int> dailyMs;
  final int goalMinutes;

  const _HeatmapCard({required this.dailyMs, required this.goalMinutes});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;
    final today = dateOnly(DateTime.now());
    final start = today.subtract(
      Duration(days: (_heatmapWeeks - 1) * 7 + today.weekday - 1),
    );

    return _Card(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 4.0;
          final cell = math.min(
            14.0,
            (constraints.maxWidth - (_heatmapWeeks - 1) * gap) / _heatmapWeeks,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    context.tr('少', 'Less', '少ない'),
                    style: technicalTextStyle(
                      context,
                      size: 11.5,
                      alpha: 0.35,
                      weight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  for (final level in const [0, 1, 2, 3, 4]) ...[
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: level == 0
                            ? ink.withValues(alpha: 0.07)
                            : accent.withValues(alpha: 0.18 + level * 0.2),
                        borderRadius: BorderRadius.circular(3.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const SizedBox(width: 2),
                  Text(
                    context.tr('多', 'More', '多い'),
                    style: technicalTextStyle(
                      context,
                      size: 11.5,
                      alpha: 0.35,
                      weight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.tr('达标日描边', 'Goal days ringed', '目標達成日を枠で表示'),
                    style: technicalTextStyle(
                      context,
                      size: 11.5,
                      alpha: 0.35,
                      weight: FontWeight.w400,
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
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;
    final isFuture = date.isAfter(today);
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
          color: isFuture
              ? Colors.transparent
              : level == 0
              ? ink.withValues(alpha: 0.07)
              : accent.withValues(alpha: 0.18 + level * 0.2),
          borderRadius: BorderRadius.circular(3.5),
          border: level >= 4
              ? Border.all(color: accent.withValues(alpha: 0.85), width: 1.5)
              : null,
        ),
      ),
    );
  }
}

class _GoalsSheet extends ConsumerWidget {
  const _GoalsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = context.appTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;
    final goals = ref.watch(listeningGoalsProvider);
    final controller = ref.read(listeningGoalsProvider.notifier);
    final yearlyHours = (goals.dailyMinutes * 365 / 60).round();

    return Container(
      key: const ValueKey('me-goals-sheet'),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                children: [
                  Text(
                    context.tr('设定目标', 'Set your goals', '目標を設定'),
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.52,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      '目标只影响提醒与进度环，不会限制你听多久。',
                      'Goals only drive the ring and the pacing copy — they never limit your listening.',
                      '目標はリングと進捗表示にのみ反映され、視聴時間を制限しません。',
                    ),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: ink.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _GoalRow(
                    label: context.tr('每日收听', 'DAILY LISTENING', '毎日の視聴'),
                    value: context.tr(
                      '${goals.dailyMinutes} 分钟',
                      '${goals.dailyMinutes} min',
                      '${goals.dailyMinutes}分',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in dailyGoalPresets)
                        _GoalChip(
                          label: context.tr('$preset 分', '$preset', '$preset分'),
                          selected: goals.dailyMinutes == preset,
                          onTap: () => controller.setDailyMinutes(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _GoalStepper(
                    key: const ValueKey('me-daily-goal-stepper'),
                    progress:
                        goals.dailyMinutes / ListeningGoals.maxDailyMinutes,
                    onDecrease: () =>
                        controller.setDailyMinutes(goals.dailyMinutes - 5),
                    onIncrease: () =>
                        controller.setDailyMinutes(goals.dailyMinutes + 5),
                  ),
                  const SizedBox(height: 30),
                  _GoalRow(
                    label: context.tr('年度书目', 'BOOKS THIS YEAR', '今年の読書数'),
                    value: context.tr(
                      '${goals.yearlyBooks} 本',
                      '${goals.yearlyBooks}',
                      '${goals.yearlyBooks}冊',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in yearlyGoalPresets)
                        _GoalChip(
                          label: context.tr('$preset 本', '$preset', '$preset冊'),
                          selected: goals.yearlyBooks == preset,
                          onTap: () => controller.setYearlyBooks(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _GoalStepper(
                    key: const ValueKey('me-yearly-goal-stepper'),
                    progress: goals.yearlyBooks / ListeningGoals.maxYearlyBooks,
                    onDecrease: () =>
                        controller.setYearlyBooks(goals.yearlyBooks - 2),
                    onIncrease: () =>
                        controller.setYearlyBooks(goals.yearlyBooks + 2),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      context.tr(
                        '每天 ${goals.dailyMinutes} 分钟，一年约 $yearlyHours 小时。',
                        '${goals.dailyMinutes} minutes a day adds up to about $yearlyHours hours a year.',
                        '毎日${goals.dailyMinutes}分で、年間約$yearlyHours時間になります。',
                      ),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: ink.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    key: const ValueKey('me-goals-save'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        context.tr('保存目标', 'Save goals', '目標を保存'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String label;
  final String value;

  const _GoalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: kickerTextStyle(context))),
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _GoalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GoalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? ink : ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected
                ? context.appBackground
                : ink.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _GoalStepper extends StatelessWidget {
  final double progress;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _GoalStepper({
    super.key,
    required this.progress,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Row(
      children: [
        _StepButton(icon: AppIcons.minusSign, onTap: onDecrease),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: ink.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(ink),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StepButton(icon: AppIcons.add01, onTap: onIncrease),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final AppIconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AppIcon(icon, size: 18, color: ink),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final double radius;
  final EdgeInsets padding;
  final Widget child;

  const _Card({
    required this.radius,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color track;

  const _RingPainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 11.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}

String formatListeningTime(int milliseconds) {
  if (milliseconds <= 0) return '0m';
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (duration.inMinutes > 0) return '${duration.inMinutes}m';
  return '<1m';
}
