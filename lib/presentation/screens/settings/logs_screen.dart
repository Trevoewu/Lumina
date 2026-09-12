import '../../widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../services/app_log_service.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';

/// The log console: subsystem filter chips over a dark terminal-style card,
/// with export and clear beneath it.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  /// Null means "All"; `sys` entries only surface there, as in the spec.
  AppLogCategory? _filter;
  final Set<AppLogEntry> _selected = {};

  void _setFilter(AppLogCategory? filter) => setState(() {
    _filter = filter;
    _selected.clear();
  });

  void _toggle(AppLogEntry entry) => setState(() {
    if (!_selected.add(entry)) _selected.remove(entry);
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final scheme = Theme.of(context).colorScheme;

    return CollapsingPageScaffold(
      title: context.tr('日志', 'Logs', 'ログ'),
      showBackButton: true,
      body: ValueListenableBuilder<List<AppLogEntry>>(
        valueListenable: AppLogService.instance.entries,
        builder: (context, entries, _) {
          final visible = _filter == null
              ? entries
              : entries.where((e) => e.category == _filter).toList();
          final selected = visible.where(_selected.contains).toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
            children: [
              Row(
                children: [
                  SettingsChip(
                    label: context.tr('全部', 'All', 'すべて'),
                    selected: _filter == null,
                    expand: true,
                    onTap: () => _setFilter(null),
                  ),
                  for (final category in const [
                    AppLogCategory.asr,
                    AppLogCategory.ai,
                    AppLogCategory.tts,
                  ]) ...[
                    const SizedBox(width: 8),
                    SettingsChip(
                      label: category.label,
                      selected: _filter == category,
                      expand: true,
                      onTap: () => _setFilter(category),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (visible.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(
                          '已选 ${selected.length} 条',
                          '${selected.length} selected',
                          '${selected.length} 件選択中',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        if (selected.length == visible.length) {
                          _selected.clear();
                        } else {
                          _selected.addAll(visible);
                        }
                      }),
                      child: Text(
                        selected.length == visible.length
                            ? context.tr('取消全选', 'Deselect all', 'すべて解除')
                            : context.tr('全选', 'Select all', 'すべて選択'),
                      ),
                    ),
                  ],
                ),
              _Console(
                entries: visible,
                selected: _selected,
                onToggle: _toggle,
                onExport: (entry) => _export([entry]),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FlatButton(
                      key: const ValueKey('export-logs'),
                      label: selected.isEmpty
                          ? context.tr(
                              '导出当前日志',
                              'Export visible logs',
                              '表示中のログを書き出す',
                            )
                          : context.tr(
                              '导出所选（${selected.length}）',
                              'Export selected (${selected.length})',
                              '選択分を書き出す（${selected.length}）',
                            ),
                      emphasised: true,
                      onTap: visible.isEmpty
                          ? null
                          : () =>
                                _export(selected.isEmpty ? visible : selected),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FlatButton(
                      key: const ValueKey('clear-logs'),
                      label: context.tr('清空', 'Clear', '消去'),
                      emphasised: false,
                      onTap: entries.isEmpty ? null : _confirmClear,
                    ),
                  ),
                ],
              ),
              if (visible.isEmpty) ...[
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    context.tr('暂无日志', 'No logs yet', 'ログはありません'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(List<AppLogEntry> entries) async {
    await Clipboard.setData(
      ClipboardData(text: entries.map((entry) => entry.formatted).join('\n\n')),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            '已复制 ${entries.length} 条日志到剪贴板',
            'Copied ${entries.length} logs to the clipboard',
            '${entries.length} 件のログをクリップボードにコピーしました',
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('清空日志？', 'Clear logs?', 'ログを消去しますか？')),
        content: Text(
          context.tr(
            '记录会被永久删除，不影响书库与缓存。',
            'The records are deleted for good. Your library and cache are untouched.',
            '記録は完全に削除されます。ライブラリとキャッシュには影響しません。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('confirm-clear-logs'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.tr('清空', 'Clear', '消去')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppLogService.instance.clear();
    if (mounted) setState(_selected.clear);
  }
}

class _Console extends StatelessWidget {
  final List<AppLogEntry> entries;

  final Set<AppLogEntry> selected;
  final ValueChanged<AppLogEntry> onToggle;
  final ValueChanged<AppLogEntry> onExport;

  const _Console({
    required this.entries,
    required this.selected,
    required this.onToggle,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    // The console is intentionally dark in both themes, like a terminal.
    const background = Color(0xFF12161C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected.contains(entries[i]),
                  side: const BorderSide(color: Color(0x99FFFFFF)),
                  onChanged: (_) => onToggle(entries[i]),
                  semanticLabel: context.tr('选择日志', 'Select log', 'ログを選択'),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _ConsoleLine(entry: entries[i]),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('导出此条日志', 'Export this log', 'このログを書き出す'),
                  onPressed: () => onExport(entries[i]),
                  icon: const AppIcon(
                    AppIcons.download01,
                    size: 18,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ),
          ],
          if (entries.isEmpty)
            Text(
              context.tr('没有匹配的记录', 'Nothing matches', '該当する記録はありません'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0x59FFFFFF),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsoleLine extends StatelessWidget {
  final AppLogEntry entry;

  const _ConsoleLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final tagColor = switch (entry.level) {
      AppLogLevel.error => const Color(0xFFF08A7E),
      AppLogLevel.warning => const Color(0xFFE8C06A),
      AppLogLevel.debug => Theme.of(context).colorScheme.primary,
    };
    final time = entry.timestamp.toLocal();
    final stamp =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stamp,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: Color(0x59FFFFFF),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            entry.category.label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.normal,
              color: tagColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            entry.error?.isNotEmpty == true
                ? '${entry.message} — ${entry.error}'
                : entry.message,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.5,
              color: Color(0xB3FFFFFF),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlatButton extends StatelessWidget {
  final String label;
  final bool emphasised;
  final VoidCallback? onTap;

  const _FlatButton({
    super.key,
    required this.label,
    required this.emphasised,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.normal,
                color: onTap == null
                    ? scheme.onSurface.withValues(alpha: 0.3)
                    : emphasised
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
