import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../services/app_log_service.dart';
import '../../widgets/collapsing_page_scaffold.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = AppLogService.instance;

    return CollapsingPageScaffold(
      title: context.tr('日志', 'Logs'),
      showBackButton: true,
      actions: [
        Tooltip(
          message: context.tr('复制日志', 'Copy Logs'),
          child: IconButton(
            icon: Icon(Icons.copy_all_outlined),
            onPressed: () => _copyLogs(context, logger),
          ),
        ),
        Tooltip(
          message: context.tr('清空日志', 'Clear Logs'),
          child: IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () => _confirmClear(context, logger),
          ),
        ),
      ],
      body: ValueListenableBuilder<List<AppLogEntry>>(
        valueListenable: logger.entries,
        builder: (context, entries, _) {
          if (entries.isEmpty) {
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
                  Text(
                    '暂无日志',
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                ],
              ),
            );
          }

          final newestFirst = entries.reversed.toList(growable: false);
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
    );
  }

  Future<void> _copyLogs(BuildContext context, AppLogService logger) async {
    final text = logger.exportText();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无日志可复制')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('日志已复制')));
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
}

class _LogEntryView extends StatelessWidget {
  final AppLogEntry entry;

  const _LogEntryView({required this.entry});

  @override
  Widget build(BuildContext context) {
    final levelColor = switch (entry.level) {
      AppLogLevel.info => context.appTextSecondary,
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
                  : Icons.info_outline,
              size: 16,
              color: levelColor,
            ),
            const SizedBox(width: 8),
            Text(
              '$time · ${entry.source}',
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 12,
                fontFamily: 'monospace',
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
}
