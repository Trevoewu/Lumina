import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../services/app_log_service.dart';
import '../../widgets/collapsing_page_scaffold.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final Set<AppLogLevel> _visibleLevels = {...AppLogLevel.values};

  @override
  Widget build(BuildContext context) {
    final logger = AppLogService.instance;

    return CollapsingPageScaffold(
      title: context.tr('日志', 'Logs'),
      showBackButton: true,
      actions: [
        Tooltip(
          message: context.tr('清空日志', 'Clear Logs'),
          child: IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () => _confirmClear(context, logger),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final level in AppLogLevel.values)
                    FilterChip(
                      label: Text(_levelLabel(context, level)),
                      selected: _visibleLevels.contains(level),
                      avatar: Icon(_levelIcon(level), size: 16),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _visibleLevels.add(level);
                          } else {
                            _visibleLevels.remove(level);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<AppLogEntry>>(
              valueListenable: logger.entries,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  return _EmptyLogsMessage(
                    message: context.tr('暂无日志', 'No logs yet'),
                  );
                }

                final newestFirst = entries.reversed
                    .where((entry) => _visibleLevels.contains(entry.level))
                    .toList(growable: false);
                if (newestFirst.isEmpty) {
                  return _EmptyLogsMessage(
                    message: context.tr('当前级别没有日志', 'No logs at this level'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  itemCount: newestFirst.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 24, color: context.appSurfaceHighlight),
                  itemBuilder: (context, index) {
                    return _LogEntryView(entry: newestFirst[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppLogService logger) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清空日志？'),
        content: Text('该操作会删除当前设备上保存的运行日志。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await logger.clear();
  }

  String _levelLabel(BuildContext context, AppLogLevel level) {
    return switch (level) {
      AppLogLevel.debug => context.tr('Debug', 'Debug'),
      AppLogLevel.warning => context.tr('Warning', 'Warning'),
      AppLogLevel.error => context.tr('Error', 'Error'),
    };
  }

  IconData _levelIcon(AppLogLevel level) {
    return switch (level) {
      AppLogLevel.debug => Icons.bug_report_outlined,
      AppLogLevel.warning => Icons.warning_amber_outlined,
      AppLogLevel.error => Icons.error_outline,
    };
  }
}

class _EmptyLogsMessage extends StatelessWidget {
  final String message;

  const _EmptyLogsMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: context.appTextSecondary,
          ),
          SizedBox(height: 12),
          Text(message, style: TextStyle(color: context.appTextSecondary)),
        ],
      ),
    );
  }
}

class _LogEntryView extends StatelessWidget {
  final AppLogEntry entry;

  const _LogEntryView({required this.entry});

  @override
  Widget build(BuildContext context) {
    final levelColor = switch (entry.level) {
      AppLogLevel.debug => context.appTextSecondary,
      AppLogLevel.warning => Colors.amberAccent,
      AppLogLevel.error => Colors.redAccent,
    };
    final localTime = entry.timestamp.toLocal();
    final time =
        '${localTime.year.toString().padLeft(4, '0')}-'
        '${localTime.month.toString().padLeft(2, '0')}-'
        '${localTime.day.toString().padLeft(2, '0')} '
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}:'
        '${localTime.second.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              entry.level == AppLogLevel.error
                  ? Icons.error_outline
                  : entry.level == AppLogLevel.warning
                  ? Icons.warning_amber_outlined
                  : Icons.bug_report_outlined,
              size: 16,
              color: levelColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$time · ${entry.source}',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Tooltip(
              message: context.tr('复制单条日志', 'Copy Log'),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => _copyEntry(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          entry.formatted.split('\n').skip(1).join('\n').trim().isEmpty
              ? entry.message
              : '${entry.message}\n'
                    '${entry.formatted.split('\n').skip(1).join('\n')}',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 13,
            height: 1.45,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Future<void> _copyEntry(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: entry.formatted));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('日志已复制', 'Log copied'))));
  }
}
