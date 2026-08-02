import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../data/settings/provider_selection_repository.dart';
import '../../../domain/models/chapter_manifest.dart';
import '../../../services/app_log_service.dart';
import '../../../services/book_introduction_service.dart';
import '../../../services/book_parser.dart';
import '../../../services/cover_palette_service.dart';
import '../../../services/generation_orchestrator.dart';
import '../../../services/generation_task_store.dart';
import '../../../services/manifest_store.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/animated_pressable_card.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/half_screen_action_sheet.dart';
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
  bool _didScrollToInitialChapter = false;
  late Future<String?> _bookIntroductionFuture;
  late Future<_AlbumChapterData> _chapterDataFuture;
  late Future<Color?> _coverSeedFuture;
  _AlbumChapterData? _chapterData;
  late String? _currentChapterId;
  late int _currentParagraphIndex;
  late int _playbackOffsetMs;
  late bool _isRead;

  @override
  void initState() {
    super.initState();
    _bookIntroductionFuture = _loadBookIntroduction();
    _chapterDataFuture = _loadChapterData(ref.read(appDatabaseProvider));
    _coverSeedFuture = CoverPaletteService.seedForPath(widget.book.coverPath);
    _currentChapterId = widget.book.currentChapterId;
    _currentParagraphIndex = widget.book.currentParagraphIndex;
    _playbackOffsetMs = widget.book.playbackOffsetMs;
    _isRead = widget.book.isRead;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resumeInterruptedChapter());
    });
  }

  Future<void> _resumeInterruptedChapter() async {
    final chapterId = widget.initialChapterId ?? widget.book.currentChapterId;
    if (chapterId == null) return;
    final database = ref.read(appDatabaseProvider);
    final task = await database.getLatestGenerationTask(
      kind: GenerationTaskKind.tts.name,
      parentId: widget.book.id,
      scopeId: chapterId,
    );
    if (!mounted ||
        task == null ||
        task.status == GenerationChunkStatus.complete.name) {
      return;
    }
    final chapters = await database.getChapters(widget.book.id);
    final chapter = chapters.where((item) => item.id == chapterId).firstOrNull;
    if (chapter == null || !mounted) return;
    // A task stores the exact provider/voice chosen for the interrupted run.
    // Recover with that configuration even if the user changed the active
    // provider while the app was closed.
    await _generateChapterAudio(chapter, recoveryTask: task, silent: true);
  }

  @override
  void didUpdateWidget(covariant AlbumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.book.sourcePath != widget.book.sourcePath ||
        oldWidget.book.externalMetadataJson !=
            widget.book.externalMetadataJson) {
      _bookIntroductionFuture = _loadBookIntroduction();
    }
    if (oldWidget.book.id != widget.book.id) {
      _chapterData = null;
      _chapterDataFuture = _loadChapterData(ref.read(appDatabaseProvider));
      _didScrollToInitialChapter = false;
    }
    if (oldWidget.book.coverPath != widget.book.coverPath) {
      _coverSeedFuture = CoverPaletteService.seedForPath(widget.book.coverPath);
    }
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.book.currentChapterId != widget.book.currentChapterId ||
        oldWidget.book.currentParagraphIndex !=
            widget.book.currentParagraphIndex ||
        oldWidget.book.playbackOffsetMs != widget.book.playbackOffsetMs) {
      _currentChapterId = widget.book.currentChapterId;
      _currentParagraphIndex = widget.book.currentParagraphIndex;
      _playbackOffsetMs = widget.book.playbackOffsetMs;
      _isRead = widget.book.isRead;
    }
  }

  Future<void> _toggleBookReadStatus() async {
    final isRead = !_isRead;
    await ref
        .read(appDatabaseProvider)
        .updateBookReadStatus(widget.book.id, isRead);
    if (!mounted) return;
    setState(() => _isRead = isRead);
    _showSnackBar(
      isRead
          ? context.tr('已标记为已读', 'Marked as read')
          : context.tr('已标记为未读', 'Marked as unread'),
    );
  }

  Future<void> _openChapter(drift_db.Chapter chapter) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          book: widget.book,
          initialChapter: chapter,
          autoplayOnOpen: true,
        ),
      ),
    );
    final database = ref.read(appDatabaseProvider);
    final results = await Future.wait<Object?>([
      database.getBook(widget.book.id),
      _loadChapterData(database),
    ]);
    if (!mounted) return;
    final latestBook = results[0] as drift_db.Book?;
    final chapterData = results[1] as _AlbumChapterData;
    setState(() {
      _currentChapterId = latestBook?.currentChapterId ?? chapter.id;
      _currentParagraphIndex = latestBook?.currentParagraphIndex ?? 0;
      _playbackOffsetMs = latestBook?.playbackOffsetMs ?? 0;
      _chapterData = chapterData;
      _chapterDataFuture = Future<_AlbumChapterData>.value(chapterData);
    });
  }

  Future<_AlbumChapterData> _loadChapterData(
    drift_db.AppDatabase database,
  ) async {
    final results = await Future.wait<Object>([
      database.getChapters(widget.book.id),
      database.getChapterPlaybackProgresses(widget.book.id),
    ]);
    final chapters = results[0] as List<drift_db.Chapter>;
    final progresses = results[1] as List<drift_db.ChapterPlaybackProgress>;
    return _AlbumChapterData(
      chapters: chapters,
      progressByChapterId: {
        for (final progress in progresses) progress.chapterId: progress,
      },
    );
  }

  Future<void> _refreshChapterData() async {
    final chapterData = await _loadChapterData(ref.read(appDatabaseProvider));
    if (!mounted) return;
    setState(() {
      _chapterData = chapterData;
      _chapterDataFuture = Future<_AlbumChapterData>.value(chapterData);
    });
  }

  Future<void> _markChapterFinished(drift_db.Chapter chapter) async {
    await ref
        .read(appDatabaseProvider)
        .markChapterFinished(widget.book.id, chapter.id);
    await _refreshChapterData();
    if (!mounted) return;
    _showSnackBar(context.tr('已标记为已听完', 'Marked as finished'));
  }

  Future<String?> _loadBookIntroduction() async {
    final stored = bookIntroductionFromMetadataJson(
      widget.book.externalMetadataJson,
    );
    if (stored != null) return stored;
    final embedded = normalizeBookIntroduction(
      await BookParser.extractDescription(sourcePath: widget.book.sourcePath),
    );
    if (embedded == null) return null;
    try {
      await ref
          .read(appDatabaseProvider)
          .updateBookExternalMetadata(
            widget.book.id,
            metadataJsonWithBookIntroduction(
              widget.book.externalMetadataJson,
              embedded,
            ),
          );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Library',
        '缓存书籍简介失败 book=${widget.book.id}',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return embedded;
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

  Future<void> _generateChapterAudio(
    drift_db.Chapter chapter, {
    drift_db.GenerationTask? recoveryTask,
    bool silent = false,
    int? priorityParagraphIndex,
  }) async {
    final registry = ref.read(providerRegistryProvider);
    final recoveryConfig = recoveryTask == null
        ? const <String, dynamic>{}
        : (jsonDecode(recoveryTask.configJson) as Map?)
                  ?.cast<String, dynamic>() ??
              const <String, dynamic>{};
    final recoveryProviderId = recoveryConfig['providerId'] as String?;
    final TtsProvider provider =
        (recoveryProviderId == null
            ? null
            : registry.get(recoveryProviderId)) ??
        ref.read(activeTtsProviderProvider);
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
        chapterVoiceId: recoveryConfig['voiceId'] as String? ?? chapter.voiceId,
      );
      if (voice == null) {
        if (mounted && !silent) _showSnackBar('${provider.displayName} 没有可用音色');
        return;
      }

      final valid = await provider.validate();
      if (!valid) {
        if (mounted && !silent) {
          _showSnackBar('${provider.displayName} 未配置完成，无法合成音频');
        }
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
        speed: (recoveryConfig['speed'] as num?)?.toDouble() ?? 1.0,
        priorityParagraphIndex: priorityParagraphIndex,
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
      if (mounted && !silent) _showSnackBar('音频合成失败：$error');
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
    await _refreshChapterData();
    if (!mounted) return;
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
    await _refreshChapterData();
    if (!mounted) return;
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
                    await _refreshChapterData();
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
    return CollapsingPageScaffold(
      title: widget.book.title,
      showBackButton: true,
      actions: [
        PopupMenuButton<String>(
          key: const ValueKey('book-detail-more-menu'),
          tooltip: context.tr('更多', 'More'),
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) {
            if (value == 'hidden_chapters') {
              _showHiddenChapters();
            } else if (value == 'toggle_read') {
              _toggleBookReadStatus();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'toggle_read',
              child: Row(
                children: [
                  Icon(
                    _isRead
                        ? Icons.remove_done_outlined
                        : Icons.done_all_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isRead
                        ? context.tr('标记为未读', 'Mark as unread')
                        : context.tr('标记为已读', 'Mark as read'),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'hidden_chapters',
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(context.tr('隐藏章节', 'Hidden chapters')),
                ],
              ),
            ),
          ],
        ),
      ],
      body: FutureBuilder<_AlbumChapterData>(
        future: _chapterDataFuture,
        builder: (context, snapshot) {
          final chapterData = _chapterData ?? snapshot.data;
          if (chapterData == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final resolvedChapterData = chapterData ?? const _AlbumChapterData();
          final chapters = resolvedChapterData.chapters;
          final design = context.appDesign;
          final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
          return FutureBuilder<Color?>(
            future: _coverSeedFuture,
            builder: (context, seedSnapshot) {
              final coverSeed = seedSnapshot.data;
              return Builder(
                builder: (scrollContext) {
                  _scrollToInitialChapter(chapters, scrollContext);
                  return ListView.builder(
                    key: const ValueKey('book-detail-scroll-view'),
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      design.spaceLg,
                      inset,
                      120,
                    ),
                    itemCount: chapters.length + 1,
                    itemBuilder: (context, itemIndex) {
                      if (itemIndex == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBookHeader(chapters),
                            SizedBox(height: design.spaceXl),
                            _buildBookIntroduction(),
                            SizedBox(height: design.spaceXxl),
                            Text(
                              context.tr('所有章节', 'All chapters'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: context.appTextPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            SizedBox(height: design.spaceSm),
                            if (chapters.isEmpty)
                              SizedBox(
                                width: double.infinity,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: design.spaceXxl,
                                  ),
                                  child: Text(
                                    context.tr(
                                      '这本书没有可阅读章节',
                                      'No readable chapters',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.appTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }

                      final chapterIndex = itemIndex - 1;
                      final chapter = chapters[chapterIndex];
                      return _ChapterCard(
                        title: chapter.title,
                        chapterNumber: chapter.chapterIndex + 1,
                        highlighted:
                            chapter.id == widget.initialChapterId ||
                            chapter.id == _currentChapterId,
                        coverSeed: coverSeed,
                        progress: _generationProgress[chapter.id],
                        savedPlaybackPositionMs: resolvedChapterData
                            .progressByChapterId[chapter.id]
                            ?.positionMs,
                        savedIsFinished:
                            resolvedChapterData
                                .progressByChapterId[chapter.id]
                                ?.isFinished ??
                            false,
                        legacyParagraphIndex: chapter.id == _currentChapterId
                            ? _currentParagraphIndex
                            : null,
                        legacyParagraphOffsetMs: chapter.id == _currentChapterId
                            ? _playbackOffsetMs
                            : 0,
                        manifestStore: ref.read(manifestStoreProvider),
                        bookId: widget.book.id,
                        chapterId: chapter.id,
                        onPlay: () => _openChapter(chapter),
                        onDownload: () => _toggleChapterDownload(chapter),
                        onCancelDownload: () => _cancelChapterDownload(chapter),
                        paused: _pausedChapterIds.contains(chapter.id),
                        onClearCache: () => _clearChapterCache(chapter),
                        onRegenerate: () => _regenerateChapter(chapter),
                        onMarkAsFinished: () => _markChapterFinished(chapter),
                        onChangeNarrator: () => _changeChapterNarrator(chapter),
                        onHideInBook: () => _hideChapter(chapter),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookHeader(List<drift_db.Chapter> chapters) {
    final design = context.appDesign;
    final currentIndex = chapters.indexWhere(
      (chapter) => chapter.id == _currentChapterId,
    );
    final currentChapter = chapters.isEmpty
        ? null
        : currentIndex < 0
        ? chapters.first
        : chapters[currentIndex];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          height: 150,
          child: BookCover(
            coverPath: widget.book.coverPath,
            iconSize: 48,
            borderRadius: design.radiusMedium,
          ),
        ),
        SizedBox(width: design.spaceLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.book.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: design.spaceSm),
              Text(
                widget.book.author ?? context.tr('未知作者', 'Unknown author'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.appTextSecondary),
              ),
              SizedBox(height: design.spaceLg),
              FilledButton.icon(
                onPressed: currentChapter == null
                    ? null
                    : () => _openChapter(currentChapter),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _currentChapterId == null
                      ? context.tr('开始阅读', 'Start reading')
                      : context.tr('继续阅读', 'Continue reading'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookIntroduction() {
    return FutureBuilder<String?>(
      future: _bookIntroductionFuture,
      builder: (context, snapshot) {
        final introduction = snapshot.data ?? _fallbackBookIntroduction();
        return Text(
          introduction,
          key: const ValueKey('book-introduction'),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.appTextSecondary,
            height: 1.45,
          ),
        );
      },
    );
  }

  String _fallbackBookIntroduction() {
    final author = widget.book.author?.trim();
    final format = widget.book.format.toUpperCase();
    final chapterCount = widget.book.chapterCount;
    return author == null || author.isEmpty
        ? context.tr(
            '《${widget.book.title}》当前以 $format 格式收录，共 $chapterCount 章。',
            '“${widget.book.title}” is available as a $format edition with '
                '$chapterCount chapters.',
          )
        : context.tr(
            '《${widget.book.title}》由 $author 创作，当前以 $format 格式收录，共 $chapterCount 章。',
            '“${widget.book.title}” by $author is available as a $format '
                'edition with $chapterCount chapters.',
          );
  }

  void _scrollToInitialChapter(
    List<drift_db.Chapter> chapters,
    BuildContext scrollContext,
  ) {
    final targetId = widget.initialChapterId;
    if (targetId == null || _didScrollToInitialChapter) return;
    final index = chapters.indexWhere((chapter) => chapter.id == targetId);
    if (index < 0) return;
    _didScrollToInitialChapter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = PrimaryScrollController.maybeOf(scrollContext);
      if (controller == null || !controller.hasClients) return;
      final target = 300.0 + index * 68.0;
      controller.animateTo(
        target.clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }
}

class _AlbumChapterData {
  final List<drift_db.Chapter> chapters;
  final Map<String, drift_db.ChapterPlaybackProgress> progressByChapterId;

  const _AlbumChapterData({
    this.chapters = const <drift_db.Chapter>[],
    this.progressByChapterId =
        const <String, drift_db.ChapterPlaybackProgress>{},
  });
}

class _ChapterCard extends StatelessWidget {
  final String title;
  final int chapterNumber;
  final bool highlighted;
  final Color? coverSeed;
  final GenerationProgress? progress;
  final int? savedPlaybackPositionMs;
  final bool savedIsFinished;
  final int? legacyParagraphIndex;
  final int legacyParagraphOffsetMs;
  final ManifestStore manifestStore;
  final String bookId;
  final String chapterId;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onCancelDownload;
  final bool paused;
  final VoidCallback onClearCache;
  final VoidCallback onRegenerate;
  final VoidCallback onMarkAsFinished;
  final VoidCallback onChangeNarrator;
  final VoidCallback onHideInBook;

  const _ChapterCard({
    required this.title,
    required this.chapterNumber,
    required this.highlighted,
    required this.coverSeed,
    required this.savedPlaybackPositionMs,
    required this.savedIsFinished,
    required this.legacyParagraphIndex,
    required this.legacyParagraphOffsetMs,
    required this.manifestStore,
    required this.bookId,
    required this.chapterId,
    required this.onPlay,
    required this.onDownload,
    required this.onCancelDownload,
    required this.paused,
    required this.onClearCache,
    required this.onRegenerate,
    required this.onMarkAsFinished,
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
    final brightness = Theme.of(context).brightness;
    final accent = coverSeed != null
        ? CoverPaletteService.accentForSeed(coverSeed!, brightness)
        : Theme.of(context).colorScheme.primary;
    return FutureBuilder<ChapterManifest?>(
      future: manifestStore.load(bookId, chapterId),
      builder: (context, snapshot) {
        final manifest = snapshot.data;
        final durationMs = manifest?.totalDurationMs ?? 0;
        final playbackPositionMs = resolveAudiobookChapterPositionMs(
          manifest: manifest,
          savedPositionMs: savedPlaybackPositionMs,
          legacyParagraphIndex: legacyParagraphIndex,
          legacyParagraphOffsetMs: legacyParagraphOffsetMs,
        );
        final playbackProgress = playbackPositionMs <= 0 || durationMs <= 0
            ? null
            : (playbackPositionMs / durationMs).clamp(0.0, 1.0).toDouble();
        final finished =
            savedIsFinished ||
            (playbackProgress != null && playbackProgress >= 0.97);
        final inProgress = playbackProgress != null && !finished;
        final remainingMs = durationMs - playbackPositionMs;
        final remainingText = _formatDuration(
          remainingMs < 0 ? 0 : remainingMs,
        );
        final metadata = <String>[
          if (durationMs > 0) _formatDuration(durationMs),
          if (finished)
            context.tr('已听完', 'Finished')
          else if (inProgress)
            context.tr('剩 $remainingText', '$remainingText left'),
        ].join(' · ');
        final metaStyle = TextStyle(
          color: context.appTextSecondary,
          fontSize: 12,
          height: 1.3,
        );
        return AnimatedPressableCard(
          key: ValueKey('book-chapter-$chapterId'),
          onTap: onPlay,
          onLongPress: () => _showActions(context, manifest, finished),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ChapterBadge(
                  number: chapterNumber,
                  current: highlighted,
                  accent: accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: highlighted ? accent : context.appTextPrimary,
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                      ],
                      if (inProgress) ...[
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            key: ValueKey(
                              'book-chapter-playback-progress-$chapterId',
                            ),
                            value: playbackProgress,
                            minHeight: 3,
                            backgroundColor: context.appSurfaceHighlight,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (finished) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: context.appTextSecondary.withValues(alpha: 0.65),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActions(
    BuildContext context,
    ChapterManifest? manifest,
    bool finished,
  ) {
    final isGenerating = progress != null;
    final hasCache = (manifest?.readyCount ?? 0) > 0;
    final isFullyCached = manifest?.isReady ?? false;
    showHalfScreenActionSheet(
      context,
      title: title,
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
          label: context.tr('标记为已听完', 'Mark as finished'),
          icon: Icons.check_circle_outline_rounded,
          onPressed: finished ? null : onMarkAsFinished,
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
  }
}

class _ChapterBadge extends StatelessWidget {
  final int number;
  final bool current;
  final Color accent;

  const _ChapterBadge({
    required this.number,
    required this.current,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: current
            ? accent
            : accent.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: current
          ? Icon(
              Icons.graphic_eq_rounded,
              size: 20,
              color: CoverPaletteService.foregroundFor(accent),
            )
          : Text(
              '$number',
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
