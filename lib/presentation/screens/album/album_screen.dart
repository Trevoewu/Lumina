import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../domain/models/chapter_manifest.dart';
import '../../../services/app_log_service.dart';
import '../../../services/generation_orchestrator.dart';
import '../../../services/manifest_store.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/book_cover.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToInitialChapter = false;
  bool _albumPlayPending = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playChapter(
    drift_db.Chapter chapter,
    int index, {
    int? resumeParagraphIndex,
    int resumeOffsetMs = 0,
    bool playAfterGeneration = false,
    bool openPlayer = true,
  }) async {
    final manifestStore = ref.read(manifestStoreProvider);

    final manifest = await manifestStore.load(widget.book.id, chapter.id);
    if (manifest != null && manifest.readyCount > 0) {
      if (!manifest.isReady) {
        _showSnackBar(
          '播放已缓存的 ${manifest.readyCount}/${manifest.segments.length} 段',
        );
      }
      await _loadAndOpenPlayer(
        manifest,
        chapter,
        resumeParagraphIndex: resumeParagraphIndex,
        resumeOffsetMs: resumeOffsetMs,
        openPlayer: openPlayer,
      );
      return;
    }

    if (_generatingChapterIds.contains(chapter.id)) {
      AppLogger.info('Generation', '章节已经在生成中 chapter=${chapter.id}');
      return;
    }

    await _generateChapterAudio(chapter);
    if (!playAfterGeneration || !mounted) return;

    final generatedManifest = await manifestStore.load(
      widget.book.id,
      chapter.id,
    );
    if (generatedManifest == null || generatedManifest.readyCount == 0) return;
    await _loadAndOpenPlayer(
      generatedManifest,
      chapter,
      resumeParagraphIndex: resumeParagraphIndex,
      resumeOffsetMs: resumeOffsetMs,
      openPlayer: openPlayer,
    );
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
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await handler.unloadIfChapter(widget.book.id, chapter.id);
    await ref
        .read(cacheManagerProvider)
        .clearChapter(widget.book.id, chapter.id);
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
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await handler.unloadIfChapter(widget.book.id, chapter.id);
    await ref
        .read(cacheManagerProvider)
        .clearChapter(widget.book.id, chapter.id);
    await _generateChapterAudio(chapter);
  }

  Future<void> _loadAndOpenPlayer(
    ChapterManifest manifest,
    drift_db.Chapter chapter, {
    int? resumeParagraphIndex,
    int resumeOffsetMs = 0,
    bool openPlayer = true,
  }) async {
    try {
      final handler = await ref.read(luminaAudioHandlerProvider.future);
      final audioRoot = await ref
          .read(manifestStoreProvider)
          .audioRoot(widget.book.id);
      await handler.loadChapter(
        manifest: manifest,
        audioRoot: audioRoot.path,
        bookTitle: widget.book.title,
        chapterTitle: chapter.title,
      );
      if (resumeParagraphIndex != null) {
        final restored = await handler.seekToProgress(
          paragraphIndex: resumeParagraphIndex,
          position: Duration(milliseconds: resumeOffsetMs),
        );
        if (!restored) {
          _showSnackBar('保存位置尚未缓存，已从本章开头播放');
        }
      }
      unawaited(handler.play());
    } catch (error, stackTrace) {
      AppLogger.error(
        'Playback',
        '播放章节缓存失败 '
            '(book=${widget.book.id}, chapter=${chapter.id})',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _showSnackBar('播放缓存失败，请清除音频后重新生成');
      return;
    }

    if (!mounted || !openPlayer) return;
    _openPlayer(chapter);
  }

  void _openPlayer(drift_db.Chapter chapter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerScreen(book: widget.book, initialChapter: chapter),
    );
  }

  Future<void> _resumeOrStart(List<drift_db.Chapter> chapters) async {
    if (_albumPlayPending || chapters.isEmpty) return;
    setState(() => _albumPlayPending = true);

    try {
      final handler = await ref.read(luminaAudioHandlerProvider.future);
      if (handler.currentBookId == widget.book.id) {
        final liveIndex = chapters.indexWhere(
          (chapter) => chapter.id == handler.currentChapterId,
        );
        if (liveIndex >= 0) {
          unawaited(handler.play());
          return;
        }
      }

      final savedBook =
          await ref.read(appDatabaseProvider).getBook(widget.book.id) ??
          widget.book;
      final savedIndex = savedBook.currentChapterId == null
          ? -1
          : chapters.indexWhere(
              (chapter) => chapter.id == savedBook.currentChapterId,
            );

      if (savedIndex >= 0) {
        await _playChapter(
          chapters[savedIndex],
          savedIndex,
          resumeParagraphIndex: savedBook.currentParagraphIndex,
          resumeOffsetMs: savedBook.playbackOffsetMs,
          playAfterGeneration: true,
          openPlayer: false,
        );
      } else {
        await _playChapter(
          chapters.first,
          0,
          playAfterGeneration: true,
          openPlayer: false,
        );
      }
    } finally {
      if (mounted) setState(() => _albumPlayPending = false);
    }
  }

  Future<void> _generateChapterAudio(drift_db.Chapter chapter) async {
    _generatingChapterIds.add(chapter.id);
    setState(() {});

    try {
      final provider = await _resolveProvider();
      final voice = await _resolveVoice(provider);
      if (voice == null) {
        _showSnackBar('${provider.displayName} 没有可用音色');
        return;
      }

      final valid = await provider.validate();
      if (!valid) {
        _showSnackBar('${provider.displayName} 未配置完成，无法合成音频');
        return;
      }

      AppLogger.info(
        'Generation',
        '开始生成章节 book=${widget.book.id} chapter=${chapter.id} '
            'provider=${provider.id} voice=${voice.id}',
      );

      final orchestrator = ref.read(generationOrchestratorProvider);
      await for (final progress in orchestrator.generateChapter(
        bookId: widget.book.id,
        chapterId: chapter.id,
        provider: provider,
        voice: voice,
      )) {
        if (!mounted) return;
        setState(() => _generationProgress[chapter.id] = progress);
      }

      final manifest = await ref
          .read(manifestStoreProvider)
          .load(widget.book.id, chapter.id);
      if (manifest != null && manifest.readyCount > 0) {
        if (!mounted) return;
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
    } finally {
      if (mounted) {
        setState(() {
          _generatingChapterIds.remove(chapter.id);
          _generationProgress.remove(chapter.id);
        });
      }
    }
  }

  Future<TtsProvider> _resolveProvider() async {
    final registry = ref.read(providerRegistryProvider);
    final savedProviderId = await ref
        .read(appDatabaseProvider)
        .getSetting('active_provider_id');
    if (savedProviderId != null) {
      final savedProvider = registry.get(savedProviderId);
      if (savedProvider != null) {
        return savedProvider;
      }
    }
    return ref.read(activeTtsProviderProvider);
  }

  Future<TtsVoice?> _resolveVoice(TtsProvider provider) async {
    final db = ref.read(appDatabaseProvider);
    final savedVoices = await db.getVoicesByProvider(provider.id);
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

    final activeVoiceId = await db.getSetting('active_voice_id');
    for (final preferredVoiceId in [widget.book.voiceId, activeVoiceId]) {
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
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: const EdgeInsets.symmetric(
                    horizontal: 64,
                    vertical: 16,
                  ),
                  title: Text(
                    widget.book.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                            colors: [
                              context.appSurfaceHighlight,
                              context.appBackground,
                            ],
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

              // 播放按钮栏
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Album • ${widget.book.author ?? "Unknown"}',
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      // 巨大的随机播放/播放按钮
                      _buildAlbumPlayButton(chapters),
                    ],
                  ),
                ),
              ),

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
                    final highlighted = chapter.id == widget.initialChapterId;
                    return ListTile(
                      tileColor: highlighted
                          ? context.appSurface.withValues(alpha: 0.55)
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: context.appTextSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        chapter.title,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        widget.book.author ?? "Unknown Artist",
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                      trailing: _ChapterActions(
                        bookId: widget.book.id,
                        chapterId: chapter.id,
                        progress: _generationProgress[chapter.id],
                        onClearCache: () => _clearChapterCache(chapter),
                        onRegenerate: () => _regenerateChapter(chapter),
                      ),
                      onTap: () => _playChapter(chapter, index),
                    );
                  }, childCount: chapters.length),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
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
      final target = 300.0 + 56.0 + index * 64.0;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildAlbumPlayButton(List<drift_db.Chapter> chapters) {
    final accent = Theme.of(context).colorScheme.primary;
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);

    return handlerAsync.when(
      loading: () => _albumControlButton(accent: accent, busy: true),
      error: (_, _) => _albumControlButton(accent: accent),
      data: (handler) => StreamBuilder(
        stream: handler.playbackState,
        initialData: handler.playbackState.value,
        builder: (context, snapshot) {
          final isCurrentBook = handler.currentBookId == widget.book.id;
          final playing = isCurrentBook && (snapshot.data?.playing ?? false);
          return _albumControlButton(
            accent: accent,
            busy: _albumPlayPending,
            playing: playing,
            onPressed: () {
              if (isCurrentBook) {
                unawaited(playing ? handler.pause() : handler.play());
              } else {
                unawaited(_resumeOrStart(chapters));
              }
            },
          );
        },
      ),
    );
  }

  Widget _albumControlButton({
    required Color accent,
    bool busy = false,
    bool playing = false,
    VoidCallback? onPressed,
  }) {
    return IconButton.filled(
      tooltip: playing ? '暂停' : '播放',
      iconSize: 36,
      padding: const EdgeInsets.all(16),
      style: IconButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      icon: busy
          ? const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.black,
              ),
            )
          : Icon(playing ? Icons.pause : Icons.play_arrow),
      onPressed: busy ? null : onPressed,
    );
  }
}

class _ChapterActions extends StatelessWidget {
  final String bookId;
  final String chapterId;
  final GenerationProgress? progress;
  final VoidCallback onClearCache;
  final VoidCallback onRegenerate;

  const _ChapterActions({
    required this.bookId,
    required this.chapterId,
    required this.onClearCache,
    required this.onRegenerate,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final progress = this.progress;
    if (progress != null) {
      return _TrailingRow(
        status: SizedBox(
          width: 38,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: progress.percent == 0 ? null : progress.percent,
                  strokeWidth: 2,
                  color: accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress.percent * 100).round()}%',
                style: TextStyle(color: context.appTextSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
        onClearCache: onClearCache,
        onRegenerate: onRegenerate,
      );
    }

    return FutureBuilder<ChapterManifest?>(
      future: ManifestStore().load(bookId, chapterId),
      builder: (context, snapshot) {
        final manifest = snapshot.data;
        Widget status;
        if (manifest != null && manifest.isReady) {
          status = Tooltip(
            message: '音频已缓存',
            child: Icon(Icons.download_done, color: accent),
          );
        } else if (manifest != null && manifest.readyCount > 0) {
          status = Tooltip(
            message: '部分音频已缓存',
            child: Text(
              '${manifest.readyCount}/${manifest.segments.length}',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else {
          status = Tooltip(
            message: '音频未缓存',
            child: Icon(
              Icons.download_for_offline_outlined,
              color: context.appTextSecondary,
            ),
          );
        }
        return _TrailingRow(
          status: status,
          onClearCache: onClearCache,
          onRegenerate: onRegenerate,
        );
      },
    );
  }
}

class _TrailingRow extends StatelessWidget {
  final Widget status;
  final VoidCallback onClearCache;
  final VoidCallback onRegenerate;

  const _TrailingRow({
    required this.status,
    required this.onClearCache,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(width: 38, child: Center(child: status)),
          PopupMenuButton<String>(
            tooltip: '章节操作',
            color: context.appSurface,
            icon: Icon(Icons.more_vert, color: context.appTextSecondary),
            onSelected: (value) {
              if (value == 'clear') onClearCache();
              if (value == 'regenerate') onRegenerate();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('清除音频'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'regenerate',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 8),
                    Text('重新生成'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
