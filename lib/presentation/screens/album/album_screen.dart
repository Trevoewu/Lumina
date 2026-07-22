import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../data/settings/provider_selection_repository.dart';
import '../../../domain/models/chapter_manifest.dart';
import '../../../services/app_log_service.dart';
import '../../../services/cover_palette_service.dart';
import '../../../services/generation_orchestrator.dart';
import '../../../services/manifest_store.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/half_screen_action_sheet.dart';
import '../../widgets/narrator_label.dart';
import '../player/player_screen.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  final drift_db.Book book;
  final String? initialChapterId;

  const AlbumScreen({super.key, required this.book, this.initialChapterId});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  final Map<String, GenerationProgress> _generationProgress = {};
  final Set<String> _generatingChapterIds = {};
  final Set<String> _pausedChapterIds = {};
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToInitialChapter = false;
  late Future<Color?> _coverSeed;

  @override
  void initState() {
    super.initState();
    _coverSeed = CoverPaletteService.seedForPath(widget.book.coverPath);
  }

  @override
  void didUpdateWidget(covariant AlbumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.coverPath != widget.book.coverPath) {
      _coverSeed = CoverPaletteService.seedForPath(widget.book.coverPath);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openChapter(drift_db.Chapter chapter) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlayerScreen(book: widget.book, initialChapter: chapter),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _clearChapterCache(drift_db.Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清除章节音频？'),
        content: Text('将删除 ${chapter.title} 已生成的音频。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final handlerFuture = ref.read(luminaAudioHandlerProvider.future);
    final cacheManager = ref.read(cacheManagerProvider);
    final handler = await handlerFuture;
    await handler.unloadIfChapter(widget.book.id, chapter.id);
    await cacheManager.clearChapter(widget.book.id, chapter.id);
    if (!mounted) return;
    setState(() {});
    _showSnackBar('已清除：${chapter.title}');
  }

  Future<void> _regenerateChapter(drift_db.Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重新生成音频？'),
        content: Text('将删除 ${chapter.title} 的旧音频，并使用当前 TTS 设置重新合成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('重新生成'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final handlerFuture = ref.read(luminaAudioHandlerProvider.future);
    final cacheManager = ref.read(cacheManagerProvider);
    final handler = await handlerFuture;
    await handler.unloadIfChapter(widget.book.id, chapter.id);
    await cacheManager.clearChapter(widget.book.id, chapter.id);
    if (!mounted) return;
    await _generateChapterAudio(chapter);
  }

  Future<void> _generateChapterAudio(drift_db.Chapter chapter) async {
    final provider = ref.read(activeTtsProviderProvider);
    final database = ref.read(appDatabaseProvider);
    final selections = ref.read(providerSelectionRepositoryProvider);
    final orchestrator = ref.read(generationOrchestratorProvider);
    final manifestStore = ref.read(manifestStoreProvider);

    _generatingChapterIds.add(chapter.id);
    setState(() {});

    try {
      final voice = await _resolveVoice(
        provider,
        database,
        selections,
        chapterVoiceId: chapter.voiceId,
      );
      if (voice == null) {
        if (mounted) _showSnackBar('${provider.displayName} 没有可用音色');
        return;
      }

      final valid = await provider.validate();
      if (!valid) {
        if (mounted) _showSnackBar('${provider.displayName} 未配置完成，无法合成音频');
        return;
      }

      AppLogger.info(
        'Generation',
        '开始生成章节 book=${widget.book.id} chapter=${chapter.id} '
            'provider=${provider.id} voice=${voice.id}',
      );

      final generation = orchestrator.generateChapter(
        bookId: widget.book.id,
        chapterId: chapter.id,
        provider: provider,
        voice: voice,
      );
      if (_pausedChapterIds.contains(chapter.id)) {
        orchestrator.pauseChapter(
          bookId: widget.book.id,
          chapterId: chapter.id,
        );
      }
      await for (final progress in generation) {
        if (mounted) {
          setState(() => _generationProgress[chapter.id] = progress);
        }
      }

      final manifest = await manifestStore.load(widget.book.id, chapter.id);
      if (manifest != null && manifest.readyCount > 0) {
        AppLogger.info(
          'Generation',
          '章节生成结束 chapter=${chapter.id} '
              'ready=${manifest.readyCount}/${manifest.segments.length}',
        );
      } else {
        AppLogger.warning('Generation', '章节生成结束但没有可用音频 chapter=${chapter.id}');
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Generation',
        '章节音频合成失败 '
            '(book=${widget.book.id}, chapter=${chapter.id})',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _showSnackBar('音频合成失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _generatingChapterIds.remove(chapter.id);
          _generationProgress.remove(chapter.id);
          _pausedChapterIds.remove(chapter.id);
        });
      }
    }
  }

  Future<void> _toggleChapterDownload(drift_db.Chapter chapter) async {
    if (!_generatingChapterIds.contains(chapter.id)) {
      await _generateChapterAudio(chapter);
      return;
    }

    final orchestrator = ref.read(generationOrchestratorProvider);
    final isPaused = _pausedChapterIds.contains(chapter.id);
    setState(() {
      if (isPaused) {
        _pausedChapterIds.remove(chapter.id);
      } else {
        _pausedChapterIds.add(chapter.id);
      }
    });
    if (isPaused) {
      orchestrator.resumeChapter(bookId: widget.book.id, chapterId: chapter.id);
    } else {
      orchestrator.pauseChapter(bookId: widget.book.id, chapterId: chapter.id);
    }
  }

  Future<void> _cancelChapterDownload(drift_db.Chapter chapter) async {
    await ref
        .read(generationOrchestratorProvider)
        .cancelChapter(bookId: widget.book.id, chapterId: chapter.id);
    if (!mounted) return;
    setState(() {
      _generatingChapterIds.remove(chapter.id);
      _generationProgress.remove(chapter.id);
      _pausedChapterIds.remove(chapter.id);
    });
  }

  Future<TtsVoice?> _resolveVoice(
    TtsProvider provider,
    drift_db.AppDatabase database,
    ProviderSelectionRepository selections, {
    String? chapterVoiceId,
  }) async {
    final savedVoices = await database.getVoicesByProvider(provider.id);
    final presetVoices = await provider.listPresetVoices();
    final voices = <TtsVoice>[
      for (final voice in savedVoices) _voiceFromDb(voice),
      for (final voice in presetVoices)
        if (!savedVoices.any(
          (saved) =>
              saved.id == voice.id ||
              saved.providerVoiceId == voice.providerVoiceId,
        ))
          voice,
    ];
    if (voices.isEmpty) return null;

    final activeVoiceId = await selections.selectedVoice(provider.id);
    for (final preferredVoiceId in [
      chapterVoiceId,
      widget.book.voiceId,
      activeVoiceId,
    ]) {
      if (preferredVoiceId == null) continue;
      for (final voice in voices) {
        if (voice.id == preferredVoiceId ||
            voice.providerVoiceId == preferredVoiceId) {
          return voice;
        }
      }
    }

    final latestSavedVoices = [...savedVoices]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final voice in latestSavedVoices) {
      if (voice.type == VoiceType.clone.name) {
        return _voiceFromDb(voice);
      }
    }

    return voices.first;
  }

  Future<void> _changeChapterNarrator(drift_db.Chapter chapter) async {
    final provider = ref.read(activeTtsProviderProvider);
    final database = ref.read(appDatabaseProvider);
    final savedVoices = await database.getVoicesByProvider(provider.id);
    final presetVoices = await provider.listPresetVoices();
    final voices = <TtsVoice>[
      for (final voice in savedVoices) _voiceFromDb(voice),
      for (final voice in presetVoices)
        if (!savedVoices.any(
          (saved) =>
              saved.id == voice.id ||
              saved.providerVoiceId == voice.providerVoiceId,
        ))
          voice,
    ];
    if (!mounted) return;
    if (voices.isEmpty) {
      _showSnackBar(context.tr('没有可用音色', 'No narrator is available'));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Text(
                  context.tr('修改旁白', 'Change narrator'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: Icon(
                        chapter.voiceId == null
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text(context.tr('使用书籍默认旁白', 'Use book default')),
                      onTap: () =>
                          _saveChapterNarrator(sheetContext, chapter, null),
                    ),
                    for (final voice in voices)
                      ListTile(
                        leading: Icon(
                          chapter.voiceId == voice.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(voice.name),
                        subtitle: Text(provider.displayName),
                        onTap: () => _saveChapterNarrator(
                          sheetContext,
                          chapter,
                          voice.id,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveChapterNarrator(
    BuildContext sheetContext,
    drift_db.Chapter chapter,
    String? voiceId,
  ) async {
    Navigator.of(sheetContext).pop();
    await ref
        .read(appDatabaseProvider)
        .updateChapterNarrator(chapter.id, voiceId);
    if (!mounted) return;
    setState(() {});
    _showSnackBar(
      context.tr(
        '已更新旁白；重新生成后将应用到音频。',
        'Narrator updated. Regenerate audio to apply it.',
      ),
    );
  }

  Future<void> _hideChapter(drift_db.Chapter chapter) async {
    await ref.read(appDatabaseProvider).updateChapterHidden(chapter.id, true);
    if (!mounted) return;
    setState(() {});
    _showSnackBar(
      context.tr(
        '已在本书中隐藏“${chapter.title}”。',
        '“${chapter.title}” is hidden in this book.',
      ),
    );
  }

  Future<void> _showHiddenChapters() async {
    final chapters = await ref
        .read(appDatabaseProvider)
        .getChapters(widget.book.id, includeHidden: true);
    final hiddenChapters = chapters
        .where((chapter) => chapter.isHidden)
        .toList();
    if (!mounted) return;
    if (hiddenChapters.isEmpty) {
      _showSnackBar(context.tr('没有隐藏章节', 'No hidden chapters'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                context.tr('隐藏章节', 'Hidden chapters'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final chapter in hiddenChapters)
              ListTile(
                title: Text(chapter.title),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(appDatabaseProvider)
                        .updateChapterHidden(chapter.id, false);
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    if (!mounted) return;
                    setState(() {});
                  },
                  child: Text(context.tr('恢复显示', 'Restore')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  TtsVoice _voiceFromDb(drift_db.Voice voice) {
    return TtsVoice(
      id: voice.id,
      name: voice.name,
      providerId: voice.providerId,
      type: VoiceType.values.byName(voice.type),
      providerVoiceId: voice.providerVoiceId,
      samplePath: voice.samplePath,
      description: voice.description,
      presetDescription: voice.presetDescription,
      previewUrl: voice.previewUrl,
      createdAt: voice.createdAt,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return FutureBuilder<Color?>(
      future: _coverSeed,
      builder: (context, paletteSnapshot) {
        final seed = paletteSnapshot.data;
        final topTint = seed == null
            ? context.appSurfaceHighlight
            : CoverPaletteService.pageTopForSeed(
                seed,
                Theme.of(context).brightness,
              );
        return Scaffold(
          body: FutureBuilder<List<drift_db.Chapter>>(
            future: db.getChapters(widget.book.id),
            builder: (context, snapshot) {
              final chapters = snapshot.data ?? const <drift_db.Chapter>[];

              _scrollToInitialChapter(chapters);

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    expandedHeight: 300,
                    pinned: true,
                    backgroundColor: context.appBackground,
                    actions: [
                      IconButton(
                        tooltip: context.tr('管理隐藏章节', 'Manage hidden chapters'),
                        onPressed: _showHiddenChapters,
                        icon: const Icon(Icons.visibility_off_outlined),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      titlePadding: const EdgeInsets.symmetric(
                        horizontal: 64,
                        vertical: 16,
                      ),
                      title: Text(
                        widget.book.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 背景渐变
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [topTint, context.appBackground],
                              ),
                            ),
                          ),
                          // 居中的大封面
                          Center(
                            child: Container(
                              width: 180,
                              height: 180,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: context.appSurface,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: BookCover(
                                coverPath: widget.book.coverPath,
                                iconSize: 80,
                                borderRadius: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 章节列表
                  if (chapters.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final chapter = chapters[index];
                        final highlighted =
                            chapter.id == widget.initialChapterId;
                        final card = _ChapterCard(
                          index: index + 1,
                          title: chapter.title,
                          author: widget.book.author ?? 'Unknown Artist',
                          bookVoiceId: widget.book.voiceId,
                          chapterVoiceId: chapter.voiceId,
                          highlighted: highlighted,
                          progress: _generationProgress[chapter.id],
                          bookId: widget.book.id,
                          chapterId: chapter.id,
                          onPlay: () => _openChapter(chapter),
                          onDownload: () => _toggleChapterDownload(chapter),
                          onCancelDownload: () =>
                              _cancelChapterDownload(chapter),
                          paused: _pausedChapterIds.contains(chapter.id),
                          onClearCache: () => _clearChapterCache(chapter),
                          onRegenerate: () => _regenerateChapter(chapter),
                          onChangeNarrator: () =>
                              _changeChapterNarrator(chapter),
                          onHideInBook: () => _hideChapter(chapter),
                        );
                        if (index == chapters.length - 1) return card;
                        return Column(
                          children: [
                            card,
                            Divider(
                              height: 1,
                              indent: 32,
                              endIndent: 32,
                              color: context.appSurfaceHighlight,
                            ),
                          ],
                        );
                      }, childCount: chapters.length),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _scrollToInitialChapter(List<drift_db.Chapter> chapters) {
    final targetId = widget.initialChapterId;
    if (targetId == null || _didScrollToInitialChapter) return;
    final index = chapters.indexWhere((chapter) => chapter.id == targetId);
    if (index < 0) return;
    _didScrollToInitialChapter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // 章节卡片按紧凑列表的平均高度定位初始章节。
      final target = 300.0 + 8.0 + index * 120.0;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }
}

class _ChapterCard extends StatelessWidget {
  final int index;
  final String title;
  final String author;
  final String? bookVoiceId;
  final String? chapterVoiceId;
  final bool highlighted;
  final GenerationProgress? progress;
  final String bookId;
  final String chapterId;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final bool paused;
  final VoidCallback onClearCache;
  final VoidCallback onRegenerate;
  final VoidCallback onChangeNarrator;
  final VoidCallback onHideInBook;

  const _ChapterCard({
    required this.index,
    required this.title,
    required this.author,
    required this.bookVoiceId,
    required this.chapterVoiceId,
    required this.highlighted,
    required this.bookId,
    required this.chapterId,
    required this.onPlay,
    required this.onDownload,
    required this.onCancelDownload,
    required this.paused,
    required this.onClearCache,
    required this.onRegenerate,
    required this.onChangeNarrator,
    required this.onHideInBook,
    this.progress,
  });

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '$minutes:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? context.appSurface.withValues(alpha: 0.72)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: FutureBuilder<ChapterManifest?>(
              future: ManifestStore().load(bookId, chapterId),
              builder: (context, snapshot) {
                final manifest = snapshot.data;
                final durationMs = manifest?.totalDurationMs ?? 0;
                final metaStyle = TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$index. $title',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appTextPrimary,
                              fontSize: 17,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 作者、朗读者与时长各占一行，避免在窄屏上相互挤压。
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                          const SizedBox(height: 2),
                          NarratorLabel(
                            voiceId:
                                manifest?.voiceId ??
                                chapterVoiceId ??
                                bookVoiceId,
                            compact: true,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            durationMs > 0
                                ? 'Audio • ${_formatDuration(durationMs)}'
                                : 'Audio',
                            style: metaStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 章节缓存统一收纳到更多操作；点击卡片直接进入阅读。
                    _ChapterActions(
                      chapterTitle: title,
                      manifest: manifest,
                      progress: progress,
                      onDownload: onDownload,
                      onCancelDownload: onCancelDownload,
                      paused: paused,
                      onClearCache: onClearCache,
                      onRegenerate: onRegenerate,
                      onChangeNarrator: onChangeNarrator,
                      onHideInBook: onHideInBook,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterActions extends StatelessWidget {
  final String chapterTitle;
  final ChapterManifest? manifest;
  final GenerationProgress? progress;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final bool paused;
  final VoidCallback onClearCache;
  final VoidCallback onRegenerate;
  final VoidCallback onChangeNarrator;
  final VoidCallback onHideInBook;

  const _ChapterActions({
    required this.chapterTitle,
    required this.manifest,
    required this.onDownload,
    required this.onCancelDownload,
    required this.paused,
    required this.onClearCache,
    required this.onRegenerate,
    required this.onChangeNarrator,
    required this.onHideInBook,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isGenerating = progress != null;
    final hasCache = (manifest?.readyCount ?? 0) > 0;
    final isFullyCached = manifest?.isReady ?? false;
    return IconButton(
      tooltip: '章节操作',
      icon: Icon(Icons.more_horiz, color: context.appTextPrimary),
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      onPressed: () {
        showHalfScreenActionSheet(
          context,
          title: chapterTitle,
          actions: [
            if (isGenerating)
              HalfScreenActionSheetItem(
                label: paused ? '继续缓存' : '暂停缓存',
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onPressed: onDownload,
              )
            else if (!isFullyCached)
              HalfScreenActionSheetItem(
                label: hasCache ? '继续缓存音频' : '缓存音频',
                icon: Icons.download_for_offline_outlined,
                onPressed: onDownload,
              ),
            if (isGenerating)
              HalfScreenActionSheetItem(
                label: '取消缓存',
                icon: Icons.cancel_outlined,
                onPressed: onCancelDownload,
              ),
            if (!isGenerating && hasCache)
              HalfScreenActionSheetItem(
                label: '清除音频',
                icon: Icons.cleaning_services_outlined,
                onPressed: onClearCache,
              ),
            if (!isGenerating && hasCache)
              HalfScreenActionSheetItem(
                label: '重新生成',
                icon: Icons.refresh_rounded,
                onPressed: onRegenerate,
              ),
            HalfScreenActionSheetItem(
              label: context.tr('修改旁白', 'Change narrator'),
              icon: Icons.record_voice_over_outlined,
              onPressed: onChangeNarrator,
            ),
            HalfScreenActionSheetItem(
              label: context.tr('在本书中隐藏', 'Hide in this book'),
              icon: Icons.visibility_off_outlined,
              onPressed: onHideInBook,
            ),
          ],
        );
      },
    );
  }
}
