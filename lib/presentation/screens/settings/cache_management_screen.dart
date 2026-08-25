import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../services/app_log_service.dart';
import '../../../services/cache_manager.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';

/// Cache management: a usage summary, then grouped rows that can be ticked and
/// deleted in one go. Rows expand to chapters and episodes so a single chapter
/// or one episode's audio can still be cleared on its own.
class CacheManagementScreen extends ConsumerStatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  ConsumerState<CacheManagementScreen> createState() =>
      _CacheManagementScreenState();
}

class _CacheManagementScreenState extends ConsumerState<CacheManagementScreen> {
  final Set<String> _selected = {};
  final Map<String, List<_CacheEntry>> _expanded = {};
  final Set<String> _loadingChildren = {};
  Future<_CachePageData>? _data;
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final db = ref.watch(appDatabaseProvider);
    final cache = ref.watch(cacheManagerProvider);
    _data ??= _loadData(db, cache);

    return CollapsingPageScaffold(
      title: context.tr('缓存管理', 'Cache Management', 'キャッシュ管理'),
      showBackButton: true,
      body: FutureBuilder<_CachePageData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 140),
                children: [
                  _SummaryCard(data: data, selectedBytes: _selectedBytes(data)),
                  for (final group in data.groups) ..._groupSection(group),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      context.tr(
                        '删除只影响缓存文件，书籍、订阅与生词本都会保留，需要时可重新生成。',
                        'Deleting only removes cached files. Books, subscriptions and vocabulary stay, and can be regenerated.',
                        '削除されるのはキャッシュのみです。書籍・購読・単語帳は残り、必要なら再生成できます。',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
              _DeleteBar(
                visible: _selected.isNotEmpty,
                busy: _deleting,
                label: context.tr(
                  '删除 ${_selected.length} 项 · ${CacheUsage(_selectedBytes(data)).humanReadable}',
                  'Delete ${_selected.length} · ${CacheUsage(_selectedBytes(data)).humanReadable}',
                  '${_selected.length} 件を削除 · ${CacheUsage(_selectedBytes(data)).humanReadable}',
                ),
                onClear: () => setState(_selected.clear),
                onDelete: () => _deleteSelected(data),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _groupSection(_CacheGroup group) {
    final allSelected =
        group.entries.isNotEmpty &&
        group.entries.every((e) => _selected.contains(e.key));
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 26, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                '${group.label} · ${context.tr('${group.entries.length} 项', '${group.entries.length} ${group.entries.length == 1 ? 'item' : 'items'}', '${group.entries.length} 件')}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 1.3,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (group.entries.isNotEmpty)
              InkWell(
                key: ValueKey('cache-select-all-${group.id}'),
                onTap: () => setState(() {
                  for (final entry in group.entries) {
                    allSelected
                        ? _selected.remove(entry.key)
                        : _selected.add(entry.key);
                  }
                }),
                child: Text(
                  allSelected
                      ? context.tr('取消全选', 'Deselect all', 'すべて解除')
                      : context.tr('全选', 'Select all', 'すべて選択'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (group.entries.isEmpty)
        SettingsCard(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              context.tr('已清空', 'Empty', '空です'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        )
      else
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < group.entries.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                _EntryRow(
                  entry: group.entries[i],
                  selected: _selected.contains(group.entries[i].key),
                  expanded: _expanded.containsKey(group.entries[i].key),
                  loadingChildren: _loadingChildren.contains(
                    group.entries[i].key,
                  ),
                  onToggle: () => _toggle(group.entries[i].key),
                  onExpand: () => _toggleExpanded(group.entries[i]),
                ),
                for (final child in _expanded[group.entries[i].key] ?? const [])
                  _EntryRow(
                    entry: child,
                    selected: _selected.contains(child.key),
                    expanded: false,
                    loadingChildren: false,
                    indented: true,
                    onToggle: () => _toggle(child.key),
                    onExpand: null,
                  ),
              ],
            ],
          ),
        ),
    ];
  }

  void _toggle(String key) {
    setState(() {
      _selected.contains(key) ? _selected.remove(key) : _selected.add(key);
    });
  }

  Future<void> _toggleExpanded(_CacheEntry entry) async {
    if (_expanded.containsKey(entry.key)) {
      setState(() => _expanded.remove(entry.key));
      return;
    }
    setState(() => _loadingChildren.add(entry.key));
    final children = await entry.loadChildren!();
    if (!mounted) return;
    setState(() {
      _loadingChildren.remove(entry.key);
      _expanded[entry.key] = children;
    });
  }

  /// Bytes covered by the current selection. A selected parent already covers
  /// its children, so those are not counted twice.
  int _selectedBytes(_CachePageData data) {
    final all = <String, _CacheEntry>{};
    for (final group in data.groups) {
      for (final entry in group.entries) {
        all[entry.key] = entry;
        for (final child in _expanded[entry.key] ?? const <_CacheEntry>[]) {
          all[child.key] = child;
        }
      }
    }
    var total = 0;
    for (final key in _selected) {
      final entry = all[key];
      if (entry == null) continue;
      if (entry.parentKey != null && _selected.contains(entry.parentKey)) {
        continue;
      }
      total += entry.bytes;
    }
    return total;
  }

  Future<void> _deleteSelected(_CachePageData data) async {
    final all = <String, _CacheEntry>{};
    for (final group in data.groups) {
      for (final entry in group.entries) {
        all[entry.key] = entry;
        for (final child in _expanded[entry.key] ?? const <_CacheEntry>[]) {
          all[child.key] = child;
        }
      }
    }
    final targets = [
      for (final key in _selected)
        if (all[key] case final entry?)
          if (entry.parentKey == null || !_selected.contains(entry.parentKey))
            entry,
    ];
    if (targets.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(
            '删除 ${targets.length} 项缓存？',
            targets.length == 1
                ? 'Delete 1 cached item?'
                : 'Delete ${targets.length} cached items?',
            '${targets.length} 件のキャッシュを削除しますか？',
          ),
        ),
        content: Text(
          context.tr(
            '只删除缓存文件，书籍与订阅会保留。删除的模型可以重新下载。',
            'Only cached files are removed. Books and subscriptions stay, and a deleted model can be downloaded again.',
            'キャッシュのみ削除されます。書籍と購読は残り、削除したモデルは再ダウンロードできます。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-cache'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.tr('删除', 'Delete', '削除')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final cache = ref.read(cacheManagerProvider);
    try {
      for (final entry in targets) {
        await entry.clear(cache);
      }
    } catch (error, stackTrace) {
      AppLogger.error('Cache', '清理缓存失败', error: error, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _selected.clear();
      _expanded.clear();
      _data = _loadData(ref.read(appDatabaseProvider), cache);
    });
  }

  Future<_CachePageData> _loadData(
    drift_db.AppDatabase db,
    CacheManager cache,
  ) async {
    // Resolved up front: the labels need a BuildContext, and everything below
    // this point is asynchronous.
    final bookLabel = context.tr('有声书音频', 'Audiobook audio', 'オーディオブック音声');
    final podcastLabel = context.tr(
      '播客与字幕',
      'Podcasts & transcripts',
      'Podcastと文字起こし',
    );
    final accent = Theme.of(context).colorScheme.primary;
    final modelLabel = context.tr('语音识别模型', 'Speech models', '音声認識モデル');
    final inUseLabel = context.tr('使用中', 'In use', '使用中');
    final modelColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.22);
    String episodeMeta(int episodes, int transcripts) => context.tr(
      '$episodes 集 · $transcripts 份字幕',
      '$episodes ${episodes == 1 ? 'episode' : 'episodes'} · '
          '$transcripts ${transcripts == 1 ? 'transcript' : 'transcripts'}',
      '$episodes エピソード · $transcripts 件の文字起こし',
    );

    final bookEntries = <_CacheEntry>[];
    for (final book in await db.getAllBooks()) {
      final usage = await cache.usageForBook(book.id);
      if (usage.bytes == 0) continue;
      bookEntries.add(
        _CacheEntry(
          key: 'book:${book.id}',
          title: book.title,
          meta: book.author ?? '',
          bytes: usage.bytes,
          art: _swatch(book.id),
          clear: (c) => c.clearBook(book.id),
          loadChildren: () async {
            final rows = <_CacheEntry>[];
            for (final chapter in await db.getChapters(book.id)) {
              final chapterUsage = await cache.usageForChapter(
                book.id,
                chapter.id,
              );
              if (chapterUsage.bytes == 0) continue;
              rows.add(
                _CacheEntry(
                  key: 'chapter:${book.id}:${chapter.id}',
                  parentKey: 'book:${book.id}',
                  title: chapter.title,
                  meta: '',
                  bytes: chapterUsage.bytes,
                  art: _swatch(chapter.id),
                  clear: (c) => c.clearChapter(book.id, chapter.id),
                ),
              );
            }
            return rows;
          },
        ),
      );
    }

    final podcastEntries = <_CacheEntry>[];
    for (final show in await db.getAllPodcastShows()) {
      final episodes = await db.getPodcastEpisodes(show.id);
      var bytes = 0;
      var transcripts = 0;
      final kept = <drift_db.PodcastEpisode>[];
      for (final episode in episodes) {
        final usage = await cache.usageForPodcastEpisode(episode);
        final hasTranscript =
            episode.transcriptJson?.trim().isNotEmpty ?? false;
        if (usage.bytes == 0 && !hasTranscript) continue;
        bytes += usage.bytes;
        if (hasTranscript) transcripts++;
        kept.add(episode);
      }
      if (kept.isEmpty) continue;
      podcastEntries.add(
        _CacheEntry(
          key: 'show:${show.id}',
          title: show.title,
          meta: episodeMeta(kept.length, transcripts),
          bytes: bytes,
          art: _swatch(show.id),
          clear: (c) => c.clearPodcastShowData(show.id),
          loadChildren: () async {
            final rows = <_CacheEntry>[];
            for (final episode in kept) {
              final usage = await cache.usageForPodcastEpisode(episode);
              rows.add(
                _CacheEntry(
                  key: 'episode:${episode.id}',
                  parentKey: 'show:${show.id}',
                  title: episode.title,
                  meta: '',
                  bytes: usage.bytes,
                  art: _swatch(episode.id),
                  clear: (c) => c.clearPodcastEpisodeData(episode.id),
                ),
              );
            }
            return rows;
          },
        ),
      );
    }

    // Downloaded Whisper weights are the largest thing on disk after audio,
    // so they are cleared from here rather than the speech settings page.
    final asr = ref.read(podcastTranscriptionServiceProvider);
    final modelEntries = <_CacheEntry>[];
    var modelBytes = 0;
    for (final info in await asr.listModelInfos()) {
      if (!info.installed) continue;
      modelBytes += info.installedBytes;
      final active = info.model == await asr.selectedModel();
      modelEntries.add(
        _CacheEntry(
          key: 'asr-model:${info.option.id}',
          title: info.option.name,
          meta: active ? inUseLabel : '',
          bytes: info.installedBytes,
          art: _swatch(info.option.id),
          clear: (_) => asr.deleteModel(model: info.model),
        ),
      );
    }

    final bookAudio = await cache.bookAudioUsage();
    final podcastAudio = await cache.podcastAudioUsage();
    return _CachePageData(
      totalBytes: bookAudio.bytes + podcastAudio.bytes + modelBytes,
      groups: [
        _CacheGroup(
          id: 'books',
          label: bookLabel,
          bytes: bookAudio.bytes,
          color: const Color(0xFF12161C),
          entries: bookEntries,
        ),
        _CacheGroup(
          id: 'podcasts',
          label: podcastLabel,
          bytes: podcastAudio.bytes,
          color: accent,
          entries: podcastEntries,
        ),
        _CacheGroup(
          id: 'asr-models',
          label: modelLabel,
          bytes: modelBytes,
          color: modelColor,
          entries: modelEntries,
        ),
      ],
    );
  }

  /// Stable stand-in artwork colour, so rows stay visually distinguishable
  /// without loading cover images.
  static Color _swatch(String seed) {
    const palette = [
      Color(0xFF3A4436),
      Color(0xFF1E2B45),
      Color(0xFF5A4632),
      Color(0xFF4A3550),
      Color(0xFF2E5A4A),
      Color(0xFF7A4A2E),
    ];
    return palette[seed.hashCode.abs() % palette.length];
  }
}

class _CachePageData {
  final int totalBytes;
  final List<_CacheGroup> groups;

  const _CachePageData({required this.totalBytes, required this.groups});
}

class _CacheGroup {
  final String id;
  final String label;
  final int bytes;
  final Color color;
  final List<_CacheEntry> entries;

  const _CacheGroup({
    required this.id,
    required this.label,
    required this.bytes,
    required this.color,
    required this.entries,
  });
}

class _CacheEntry {
  final String key;
  final String? parentKey;
  final String title;
  final String meta;
  final int bytes;
  final Color art;
  final Future<void> Function(CacheManager cache) clear;
  final Future<List<_CacheEntry>> Function()? loadChildren;

  const _CacheEntry({
    required this.key,
    this.parentKey,
    required this.title,
    required this.meta,
    required this.bytes,
    required this.art,
    required this.clear,
    this.loadChildren,
  });
}

/// Proportion of [total] taken by [bytes], as a flex share out of 1000.
int _share(int bytes, int total) {
  if (total <= 0) return 1;
  return (bytes * 1000 ~/ total).clamp(1, 1000);
}

class _SummaryCard extends StatelessWidget {
  final _CachePageData data;
  final int selectedBytes;

  const _SummaryCard({required this.data, required this.selectedBytes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usage = CacheUsage(data.totalBytes);
    final parts = usage.humanReadable.split(' ');
    final nonEmpty = data.groups.where((g) => g.bytes > 0).toList();
    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A Wrap rather than a Row: the badge sits right-aligned when it
          // fits and drops to its own line when it does not, so neither half
          // has to ellipsize at large text scales.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    parts.first,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      context.tr(
                        '${parts.length > 1 ? parts[1] : 'B'} 已占用',
                        '${parts.length > 1 ? parts[1] : 'B'} used',
                        '${parts.length > 1 ? parts[1] : 'B'} 使用中',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedBytes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.tr(
                      '已选 ${CacheUsage(selectedBytes).humanReadable}',
                      'Selected ${CacheUsage(selectedBytes).humanReadable}',
                      '選択 ${CacheUsage(selectedBytes).humanReadable}',
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            // Half the bar's height: a pill, without asking RRect to scale a
            // radius far larger than the box.
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: nonEmpty.isEmpty
                  ? ColoredBox(color: scheme.onSurface.withValues(alpha: 0.06))
                  : Row(
                      // Stretch, or the childless ColoredBox segments collapse
                      // to zero height under the default centre alignment.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < nonEmpty.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(
                            // Flex is a share out of 1000 rather than a raw
                            // byte count, which would be a huge flex factor.
                            flex: _share(nonEmpty[i].bytes, data.totalBytes),
                            child: ColoredBox(color: nonEmpty[i].color),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          // A legend entry can be wider than the card at large text scales, so
          // each one is bounded and allowed to ellipsize.
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final group in data.groups)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: group.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '${group.label} ${CacheUsage(group.bytes).humanReadable}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final _CacheEntry entry;
  final bool selected;
  final bool expanded;
  final bool loadingChildren;
  final bool indented;
  final VoidCallback onToggle;
  final VoidCallback? onExpand;

  const _EntryRow({
    required this.entry,
    required this.selected,
    required this.expanded,
    required this.loadingChildren,
    this.indented = false,
    required this.onToggle,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        key: ValueKey('cache-row-${entry.key}'),
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.fromLTRB(indented ? 32 : 16, 13, 16, 13),
          child: Row(
            children: [
              _Checkbox(selected: selected),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: entry.art,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (entry.meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                CacheUsage(entry.bytes).humanReadable,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (entry.loadChildren != null && onExpand != null)
                IconButton(
                  key: ValueKey('cache-expand-${entry.key}'),
                  onPressed: onExpand,
                  visualDensity: VisualDensity.compact,
                  icon: loadingChildren
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final bool selected;

  const _Checkbox({required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: selected
            ? null
            : Border.all(
                color: scheme.onSurface.withValues(alpha: 0.18),
                width: 2,
              ),
      ),
      child: selected
          ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
          : null,
    );
  }
}

class _DeleteBar extends StatelessWidget {
  final bool visible;
  final bool busy;
  final String label;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  const _DeleteBar({
    required this.visible,
    required this.busy,
    required this.label,
    required this.onClear,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: visible ? 1 : 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [scheme.surface.withValues(alpha: 0), scheme.surface],
                stops: const [0, 0.26],
              ),
            ),
            child: Row(
              children: [
                Material(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('cache-clear-selection'),
                    onTap: busy ? null : onClear,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: scheme.error,
                    borderRadius: BorderRadius.circular(23),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const ValueKey('cache-delete-selection'),
                      onTap: busy ? null : onDelete,
                      child: SizedBox(
                        height: 46,
                        child: Center(
                          child: busy
                              ? SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onError,
                                  ),
                                )
                              : Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: scheme.onError,
                                      ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
