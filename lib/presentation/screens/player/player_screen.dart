import 'dart:async';

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
import '../../../services/book_playback_queue.dart';
import '../../../services/cover_palette_service.dart';
import '../../../services/generation_orchestrator.dart';
import '../../../services/lumina_audio_handler.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/synced_lyrics_list.dart';

enum PlayerPrimaryAudioAction { play, pause }

PlayerPrimaryAudioAction resolvePlayerPrimaryAudioAction({
  required bool playing,
  required bool playbackRequested,
}) {
  return playing || playbackRequested
      ? PlayerPrimaryAudioAction.pause
      : PlayerPrimaryAudioAction.play;
}

class PlayerScreen extends ConsumerStatefulWidget {
  final drift_db.Book book;
  final drift_db.Chapter? initialChapter;

  const PlayerScreen({super.key, required this.book, this.initialChapter});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double _speed = 1.0;
  late Future<Color?> _coverSeed;
  ChapterManifest? _selectedManifest;
  GenerationProgress? _generationProgress;
  StreamSubscription<GenerationProgress>? _generationSubscription;
  Future<void> _generationUpdate = Future.value();
  bool _preparingStream = false;
  bool _streamPlaybackRequested = false;
  bool _startingPlayback = false;
  int _paragraphCount = 0;

  @override
  void initState() {
    super.initState();
    _coverSeed = CoverPaletteService.seedForPath(widget.book.coverPath);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPlaybackSpeed());
      unawaited(_loadSelectedChapterState());
    });
  }

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.coverPath != widget.book.coverPath) {
      _coverSeed = CoverPaletteService.seedForPath(widget.book.coverPath);
    }
  }

  @override
  void dispose() {
    unawaited(_generationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _loadSelectedChapterState() async {
    final chapter = widget.initialChapter;
    if (chapter == null) return;

    final database = ref.read(appDatabaseProvider);
    final manifestStore = ref.read(manifestStoreProvider);
    final results = await Future.wait<Object?>([
      manifestStore.load(widget.book.id, chapter.id),
      database.getParagraphs(chapter.id),
    ]);
    if (!mounted) return;
    final manifest = results[0] as ChapterManifest?;
    final paragraphs = results[1] as List<drift_db.Paragraph>;
    setState(() {
      _selectedManifest = manifest;
      _paragraphCount = paragraphs.length;
    });

    final activeGeneration = ref
        .read(generationOrchestratorProvider)
        .watchChapterGeneration(bookId: widget.book.id, chapterId: chapter.id);
    if (activeGeneration != null) {
      _listenToGeneration(activeGeneration);
    }
  }

  void _listenToGeneration(Stream<GenerationProgress> stream) {
    unawaited(_generationSubscription?.cancel());
    late StreamSubscription<GenerationProgress> subscription;
    subscription = stream.listen(
      (progress) {
        _generationUpdate = _generationUpdate
            .then((_) => _applyGenerationProgress(progress))
            .catchError((Object error, StackTrace stackTrace) {
              AppLogger.error(
                'Playback',
                '追加流式缓存到播放队列失败 '
                    'book=${widget.book.id} chapter=${progress.chapterId}',
                error: error,
                stackTrace: stackTrace,
              );
            });
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error(
          'Generation',
          '阅读页缓存章节失败 book=${widget.book.id} '
              'chapter=${widget.initialChapter?.id}',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted || !identical(_generationSubscription, subscription)) {
          return;
        }
        setState(() {
          _generationSubscription = null;
          _streamPlaybackRequested = false;
        });
        _showSnackBar(
          context.tr('音频缓存失败：$error', 'Unable to cache audio: $error'),
        );
      },
      onDone: () {
        final pendingUpdate = _generationUpdate;
        unawaited(pendingUpdate.then((_) => _finishGeneration(subscription)));
      },
    );
    setState(() => _generationSubscription = subscription);
  }

  Future<void> _applyGenerationProgress(GenerationProgress progress) async {
    final chapter = widget.initialChapter;
    if (chapter == null) return;
    final manifest = await ref
        .read(manifestStoreProvider)
        .load(widget.book.id, chapter.id);
    if (!mounted) return;
    setState(() {
      _generationProgress = progress;
      _selectedManifest = manifest ?? _selectedManifest;
    });
    if (manifest != null) {
      await _syncStreamingPlayback(manifest);
    }
  }

  Future<void> _finishGeneration(
    StreamSubscription<GenerationProgress> subscription,
  ) async {
    final chapter = widget.initialChapter;
    final manifest = chapter == null
        ? null
        : await ref
              .read(manifestStoreProvider)
              .load(widget.book.id, chapter.id);
    if (!mounted || !identical(_generationSubscription, subscription)) return;
    setState(() {
      _selectedManifest = manifest ?? _selectedManifest;
      _generationSubscription = null;
      _streamPlaybackRequested = false;
    });
  }

  Future<bool> _ensureChapterCachingStarted() async {
    final chapter = widget.initialChapter;
    if (chapter == null) return false;
    if (_generationSubscription != null) return true;
    if (_preparingStream) return false;

    setState(() => _preparingStream = true);
    try {
      final provider = ref.read(activeTtsProviderProvider);
      final database = ref.read(appDatabaseProvider);
      final voice = await _resolveVoice(
        provider,
        database,
        ref.read(providerSelectionRepositoryProvider),
        chapterVoiceId: chapter.voiceId,
      );
      if (!mounted) return false;
      if (voice == null) {
        _showSnackBar(
          context.tr(
            '${provider.displayName} 没有可用音色',
            '${provider.displayName} has no available voice',
          ),
        );
        return false;
      }
      if (!await provider.validate()) {
        if (!mounted) return false;
        _showSnackBar(
          context.tr(
            '${provider.displayName} 未配置完成，无法缓存音频',
            '${provider.displayName} is not configured, so audio cannot be cached',
          ),
        );
        return false;
      }

      final stream = ref
          .read(generationOrchestratorProvider)
          .generateChapter(
            bookId: widget.book.id,
            chapterId: chapter.id,
            provider: provider,
            voice: voice,
          );
      _listenToGeneration(stream);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Generation',
        '阅读页启动章节缓存失败 book=${widget.book.id} chapter=${chapter.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar(
          context.tr('无法开始缓存：$error', 'Unable to start caching: $error'),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _preparingStream = false);
    }
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
      if (voice.type == VoiceType.clone.name) return _voiceFromDb(voice);
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

  Future<void> _loadPlaybackSpeed() async {
    final value = await ref
        .read(appDatabaseProvider)
        .getSetting('playback_speed');
    final speed = (double.tryParse(value ?? '') ?? 1.0).clamp(0.5, 3.0);
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await handler.setSpeed(speed);
    if (!mounted) return;
    setState(() => _speed = speed.toDouble());
  }

  bool _isSelectedChapterLoaded(LuminaAudioHandler handler) {
    final chapter = widget.initialChapter;
    if (chapter == null) return handler.currentBookId == widget.book.id;
    return handler.currentBookId == widget.book.id &&
        handler.currentChapterId == chapter.id;
  }

  ChapterManifest? _effectiveManifest(LuminaAudioHandler handler) {
    return widget.initialChapter == null
        ? handler.currentManifest
        : _selectedManifest;
  }

  double _cacheFraction(ChapterManifest? manifest) {
    final progress = _generationProgress;
    if (progress != null && progress.total > 0) {
      return progress.percent.clamp(0.0, 1.0);
    }
    final total = manifest?.segments.length ?? _paragraphCount;
    if (total <= 0) return 0;
    return ((manifest?.readyCount ?? 0) / total).clamp(0.0, 1.0);
  }

  ChapterManifest _playablePrefix(ChapterManifest manifest) {
    final playable = <SegmentEntry>[];
    for (final segment in manifest.segments) {
      if (segment.state != ParagraphAudioState.ready) break;
      playable.add(segment);
    }
    return ChapterManifest(
      chapterId: manifest.chapterId,
      bookId: manifest.bookId,
      providerId: manifest.providerId,
      voiceId: manifest.voiceId,
      speed: manifest.speed,
      segments: playable,
      updatedAt: manifest.updatedAt,
    );
  }

  Future<void> _handlePrimaryAudioAction(
    LuminaAudioHandler handler,
    bool playing,
  ) async {
    if (playing || _streamPlaybackRequested || _startingPlayback) {
      if (mounted) {
        setState(() => _streamPlaybackRequested = false);
      }
      await handler.pause();
      return;
    }

    final chapter = widget.initialChapter;
    if (chapter == null) {
      await handler.play();
      return;
    }

    setState(() => _streamPlaybackRequested = true);
    final manifest = _selectedManifest;
    final hasPlayablePrefix =
        manifest != null && _playablePrefix(manifest).segments.isNotEmpty;
    var startedPlayback = false;
    if (hasPlayablePrefix) {
      startedPlayback = await _startPlayback(handler, manifest);
    }

    final needsCaching = manifest == null || !manifest.isReady;
    var caching = _generationSubscription != null;
    if (needsCaching && !caching) {
      caching = await _ensureChapterCachingStarted();
    }
    if (!mounted) return;

    if (!needsCaching || (!caching && !startedPlayback)) {
      setState(() => _streamPlaybackRequested = false);
    }
  }

  Future<void> _syncStreamingPlayback(ChapterManifest manifest) async {
    final playable = _playablePrefix(manifest);
    if (playable.segments.isEmpty) return;

    final handler = await ref.read(luminaAudioHandlerProvider.future);
    if (!mounted) return;
    final paragraphLabel = context.tr('段落', 'Paragraph');
    if (!_isSelectedChapterLoaded(handler)) {
      if (_streamPlaybackRequested) {
        await _startPlayback(handler, manifest);
      }
      return;
    }

    final audioRoot = await ref
        .read(manifestStoreProvider)
        .audioRoot(widget.book.id);
    final extended = await handler.appendChapterSegments(
      manifest: playable,
      audioRoot: audioRoot.path,
      bookTitle: widget.book.title,
      chapterTitle: widget.initialChapter?.title ?? '',
      paragraphLabel: paragraphLabel,
    );
    if (extended && _streamPlaybackRequested) {
      await handler.play();
    }
  }

  Future<bool> _startPlayback(
    LuminaAudioHandler handler,
    ChapterManifest manifest,
  ) async {
    if (_startingPlayback) return false;
    setState(() => _startingPlayback = true);
    try {
      return await _playCachedAudio(handler, manifest: manifest);
    } finally {
      if (mounted) setState(() => _startingPlayback = false);
    }
  }

  Future<bool> _playCachedAudio(
    LuminaAudioHandler handler, {
    ChapterManifest? manifest,
  }) async {
    final chapter = widget.initialChapter;
    if (chapter == null) {
      await handler.play();
      return true;
    }

    final latestManifest =
        manifest ??
        await ref.read(manifestStoreProvider).load(widget.book.id, chapter.id);
    if (!mounted) return false;
    final paragraphLabel = context.tr('段落', 'Paragraph');
    setState(() => _selectedManifest = latestManifest ?? _selectedManifest);
    if (latestManifest == null) return false;
    final playable = _playablePrefix(latestManifest);
    if (playable.segments.isEmpty) {
      return false;
    }

    final loadedManifest = _isSelectedChapterLoaded(handler)
        ? handler.currentManifest
        : null;
    if (loadedManifest == null) {
      try {
        if (latestManifest.isReady) {
          await loadBookPlaybackQueue(
            handler: handler,
            database: ref.read(appDatabaseProvider),
            manifestStore: ref.read(manifestStoreProvider),
            bookId: widget.book.id,
            bookTitle: widget.book.title,
            initialManifest: playable,
            paragraphLabel: paragraphLabel,
          );
        } else {
          final audioRoot = await ref
              .read(manifestStoreProvider)
              .audioRoot(widget.book.id);
          await handler.loadChapter(
            manifest: playable,
            audioRoot: audioRoot.path,
            bookTitle: widget.book.title,
            chapterTitle: chapter.title,
            paragraphLabel: paragraphLabel,
          );
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'Playback',
          '阅读页播放缓存失败 book=${widget.book.id} chapter=${chapter.id}',
          error: error,
          stackTrace: stackTrace,
        );
        if (mounted) {
          _showSnackBar(
            context.tr(
              '播放缓存失败，请清除音频后重新生成',
              'Unable to play cached audio. Clear it and generate it again.',
            ),
          );
        }
        return false;
      }
    } else if (loadedManifest.readyCount < playable.readyCount) {
      final audioRoot = await ref
          .read(manifestStoreProvider)
          .audioRoot(widget.book.id);
      await handler.appendChapterSegments(
        manifest: playable,
        audioRoot: audioRoot.path,
        bookTitle: widget.book.title,
        chapterTitle: chapter.title,
        paragraphLabel: paragraphLabel,
      );
    }
    if (mounted) setState(() {});
    await handler.play();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    return FutureBuilder<Color?>(
      future: _coverSeed,
      builder: (context, paletteSnapshot) {
        final seed = paletteSnapshot.data;
        final topTint = seed == null
            ? context.appSurface
            : CoverPaletteService.pageTopForSeed(
                seed,
                Theme.of(context).brightness,
              );
        final pageBottom = seed == null
            ? context.appBackground
            : Theme.of(context).brightness == Brightness.dark
            ? CoverPaletteService.darkPageBottomForSeed(seed)
            : context.appBackground;
        final lyricsBackground =
            CoverPaletteService.lyricsBackgroundGradientForSeed(seed);
        final topForeground = CoverPaletteService.foregroundFor(topTint);
        final contentForeground = CoverPaletteService.foregroundFor(pageBottom);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topTint, pageBottom],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            size: 32,
                            color: topForeground,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            widget.book.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                              color: topForeground.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.more_vert, color: topForeground),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: handlerAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (handler) {
                        return StreamBuilder(
                          stream: handler.playbackState,
                          initialData: handler.playbackState.value,
                          builder: (context, snapshot) {
                            final state = snapshot.data;
                            final currentItem = handler.mediaItem.valueOrNull;
                            final selectedLoaded = _isSelectedChapterLoaded(
                              handler,
                            );
                            final manifest = _effectiveManifest(handler);
                            final playing =
                                selectedLoaded && (state?.playing ?? false);
                            final duration = selectedLoaded
                                ? handler.chapterDuration
                                : Duration(
                                    milliseconds:
                                        manifest?.totalDurationMs ?? 0,
                                  );
                            final currentChapterId =
                                widget.initialChapter?.id ??
                                currentItem?.extras?['chapterId'] as String?;
                            final chapterTitle =
                                widget.initialChapter?.title ??
                                currentItem?.title ??
                                context.tr('未知章节', 'Unknown Chapter');

                            return Column(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: context.appSurfaceHighlight,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.4,
                                                ),
                                                blurRadius: 30,
                                                offset: const Offset(0, 15),
                                              ),
                                            ],
                                          ),
                                          child: BookCover(
                                            coverPath: widget.book.coverPath,
                                            iconSize: 120,
                                            borderRadius: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              chapterTitle,
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: contentForeground,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              widget.book.author ??
                                                  context.tr(
                                                    '未知作者',
                                                    'Unknown Author',
                                                  ),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: contentForeground
                                                    .withValues(alpha: 0.72),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.favorite_border),
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: StreamBuilder<Duration>(
                                    stream: handler.chapterPositionStream,
                                    initialData: handler.chapterPosition,
                                    builder: (context, positionSnapshot) {
                                      return _buildControls(
                                        handler,
                                        playing,
                                        selectedLoaded
                                            ? positionSnapshot.data ??
                                                  Duration.zero
                                            : Duration.zero,
                                        duration,
                                        manifest: manifest,
                                        selectedLoaded: selectedLoaded,
                                        foregroundColor: contentForeground,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  flex: 5,
                                  child: _buildLyricsCard(
                                    currentChapterId,
                                    handler,
                                    manifest,
                                    selectedLoaded,
                                    lyricsBackground,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(
    LuminaAudioHandler handler,
    bool playing,
    Duration position,
    Duration duration, {
    required ChapterManifest? manifest,
    required bool selectedLoaded,
    required Color foregroundColor,
  }) {
    final controlColor = Theme.of(context).colorScheme.primary;
    final cacheColor = context.appTextSecondary.withValues(alpha: 0.62);
    final secondaryColor = foregroundColor.withValues(alpha: 0.72);
    final playbackFraction = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    final cacheFraction = _cacheFraction(manifest);
    final hasCachedAudio = (manifest?.readyCount ?? 0) > 0;
    final primaryAction = resolvePlayerPrimaryAudioAction(
      playing: playing,
      playbackRequested: _streamPlaybackRequested || _startingPlayback,
    );
    final primaryTooltip = switch (primaryAction) {
      PlayerPrimaryAudioAction.play => context.tr('播放', 'Play'),
      PlayerPrimaryAudioAction.pause => context.tr('暂停', 'Pause'),
    };

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: cacheFraction),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, animatedCacheFraction, _) {
            final playbackTrackProgress =
                (playbackFraction * animatedCacheFraction)
                    .clamp(0.0, animatedCacheFraction)
                    .toDouble();
            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: controlColor,
                secondaryActiveTrackColor: cacheColor,
                inactiveTrackColor: context.appSurfaceHighlight,
                thumbColor: controlColor,
                disabledActiveTrackColor: controlColor,
                disabledSecondaryActiveTrackColor: cacheColor,
                disabledInactiveTrackColor: context.appSurfaceHighlight,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                disabledThumbColor: hasCachedAudio
                    ? controlColor
                    : Colors.transparent,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                key: const ValueKey('player-cache-playback-progress'),
                value: playbackTrackProgress,
                secondaryTrackValue:
                    animatedCacheFraction < playbackTrackProgress
                    ? playbackTrackProgress
                    : animatedCacheFraction,
                onChanged:
                    !selectedLoaded ||
                        duration.inMilliseconds <= 0 ||
                        cacheFraction <= 0
                    ? null
                    : (value) {
                        final cachedValue = value.clamp(0.0, cacheFraction);
                        final seekFraction = cachedValue / cacheFraction;
                        final seekMs = (seekFraction * duration.inMilliseconds)
                            .round();
                        handler.seek(Duration(milliseconds: seekMs));
                      },
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(position),
              style: TextStyle(fontSize: 12, color: secondaryColor),
            ),
            Text(
              _fmt(duration),
              style: TextStyle(fontSize: 12, color: secondaryColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: context.tr('播放倍速', 'Playback speed'),
              icon: Text(
                '${_speed.toStringAsFixed(1)}x',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              color: secondaryColor,
              onPressed: _showSpeedSheet,
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 36),
              color: foregroundColor,
              onPressed: selectedLoaded ? handler.skipToPrevious : null,
            ),
            Tooltip(
              message: primaryTooltip,
              child: Semantics(
                button: true,
                label: primaryTooltip,
                child: Material(
                  color: controlColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('player-primary-audio-action'),
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        unawaited(_handlePrimaryAudioAction(handler, playing)),
                    child: SizedBox.square(
                      dimension: 64,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _buildPrimaryAudioGlyph(
                            action: primaryAction,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 36),
              color: foregroundColor,
              onPressed: selectedLoaded ? handler.skipToNext : null,
            ),
            IconButton(
              icon: const Icon(Icons.repeat),
              color: secondaryColor,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryAudioGlyph({
    required PlayerPrimaryAudioAction action,
    required Color color,
  }) {
    return switch (action) {
      PlayerPrimaryAudioAction.play => Icon(
        Icons.play_arrow,
        key: const ValueKey(PlayerPrimaryAudioAction.play),
        size: 32,
        color: color,
      ),
      PlayerPrimaryAudioAction.pause => Icon(
        Icons.pause,
        key: const ValueKey(PlayerPrimaryAudioAction.pause),
        size: 32,
        color: color,
      ),
    };
  }

  Widget _buildLyricsCard(
    String? chapterId,
    LuminaAudioHandler handler,
    ChapterManifest? manifest,
    bool playbackEnabled,
    Gradient background,
  ) {
    if (chapterId == null) return const SizedBox.shrink();

    final db = ref.watch(appDatabaseProvider);
    return Container(
      key: const ValueKey('lyrics-card'),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.appDesign.spaceLg,
                context.appDesign.spaceLg,
                context.appDesign.spaceLg,
                context.appDesign.spaceSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('正文', 'Text'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.lyricsTextPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.share_outlined,
                          size: 20,
                          color: AppColors.lyricsTextSecondary,
                        ),
                        tooltip: context.tr('分享正文', 'Share text'),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_full,
                          size: 20,
                          color: AppColors.lyricsTextSecondary,
                        ),
                        tooltip: context.tr('全屏正文', 'Full-screen text'),
                        onPressed: () => _showFullScreenLyrics(
                          chapterId,
                          manifest,
                          playbackEnabled,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<drift_db.Paragraph>>(
                future: db.getParagraphs(chapterId),
                builder: (context, snapshot) {
                  final paragraphs =
                      snapshot.data ?? const <drift_db.Paragraph>[];
                  if (paragraphs.isEmpty) {
                    return Center(
                      child: Text(
                        context.tr('无正文', 'No text'),
                        style: const TextStyle(
                          color: AppColors.lyricsTextSecondary,
                        ),
                      ),
                    );
                  }
                  return SyncedLyricsList(
                    key: ValueKey(
                      '$chapterId:${playbackEnabled ? handler.currentChapterId : 'reading'}',
                    ),
                    paragraphs: paragraphs,
                    manifest: manifest,
                    handler: handler,
                    playbackEnabled: playbackEnabled,
                    bookTitle: widget.book.title,
                    chapterTitle: widget.initialChapter?.title,
                    bookId: widget.book.id,
                    chapterId: chapterId,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showSpeedSheet() {
    var draft = _speed;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.appSurface,
      builder: (context) {
        final accent = Theme.of(context).colorScheme.primary;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('播放倍速', 'Playback speed'),
                            style: TextStyle(
                              color: context.appTextPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${draft.toStringAsFixed(1)}x',
                          style: TextStyle(
                            color: accent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accent,
                        inactiveTrackColor: context.appSurfaceHighlight,
                        thumbColor: accent,
                      ),
                      child: Slider(
                        min: 0.5,
                        max: 3.0,
                        divisions: 25,
                        value: draft,
                        onChanged: (value) {
                          setSheetState(() => draft = value);
                          _applySpeed(value);
                        },
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in const [
                          0.8,
                          1.0,
                          1.2,
                          1.5,
                          2.0,
                          2.5,
                        ])
                          ChoiceChip(
                            label: Text('${value.toStringAsFixed(1)}x'),
                            selected: (draft - value).abs() < 0.01,
                            selectedColor: accent,
                            labelStyle: TextStyle(
                              color: (draft - value).abs() < 0.01
                                  ? Colors.black
                                  : context.appTextPrimary,
                            ),
                            onSelected: (_) {
                              setSheetState(() => draft = value);
                              _applySpeed(value);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _applySpeed(double speed) async {
    final clamped = speed.clamp(0.5, 3.0).toDouble();
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await handler.setSpeed(clamped);
    await ref
        .read(appDatabaseProvider)
        .setSetting('playback_speed', clamped.toStringAsFixed(2));
    if (!mounted) return;
    setState(() => _speed = clamped);
  }

  void _showFullScreenLyrics(
    String chapterId,
    ChapterManifest? manifest,
    bool playbackEnabled,
  ) {
    Navigator.of(context, rootNavigator: true).push(
      // A fullscreenDialog disables iOS's interactive edge-pop gesture.
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenLyricsSheet(
          bookId: widget.book.id,
          bookTitle: widget.book.title,
          chapterTitle: widget.initialChapter?.title ?? '',
          chapterId: chapterId,
          coverPath: widget.book.coverPath,
          manifest: manifest,
          playbackEnabled: playbackEnabled,
        ),
      ),
    );
  }
}

class _FullScreenLyricsSheet extends ConsumerStatefulWidget {
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final String chapterId;
  final String? coverPath;
  final ChapterManifest? manifest;
  final bool playbackEnabled;

  const _FullScreenLyricsSheet({
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterId,
    required this.coverPath,
    required this.manifest,
    required this.playbackEnabled,
  });

  @override
  ConsumerState<_FullScreenLyricsSheet> createState() =>
      _FullScreenLyricsSheetState();
}

class _FullScreenLyricsSheetState
    extends ConsumerState<_FullScreenLyricsSheet> {
  final _controlsKey = GlobalKey<_FullScreenPlaybackControlsState>();
  late Future<Color?> _coverSeed;

  @override
  void initState() {
    super.initState();
    _coverSeed = CoverPaletteService.seedForPath(widget.coverPath);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    return FutureBuilder<Color?>(
      future: _coverSeed,
      builder: (context, paletteSnapshot) {
        final seed = paletteSnapshot.data;
        final lyricsBackground =
            CoverPaletteService.lyricsBackgroundGradientForSeed(seed);
        final bottomTint = lyricsBackground.colors.last;
        return Scaffold(
          backgroundColor: bottomTint,
          body: Container(
            key: const ValueKey('fullscreen-lyrics-background'),
            height: MediaQuery.sizeOf(context).height,
            decoration: BoxDecoration(gradient: lyricsBackground),
            child: SafeArea(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) =>
                    _controlsKey.currentState?.showTemporarily(),
                onPointerMove: (_) =>
                    _controlsKey.currentState?.showTemporarily(),
                onPointerSignal: (_) =>
                    _controlsKey.currentState?.showTemporarily(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.lyricsTextPrimary,
                              size: 32,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              widget.bookTitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.lyricsTextSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<drift_db.Paragraph>>(
                        future: db.getParagraphs(widget.chapterId),
                        builder: (context, snapshot) {
                          final paragraphs =
                              snapshot.data ?? const <drift_db.Paragraph>[];
                          if (paragraphs.isEmpty) {
                            return Center(
                              child: Text(
                                context.tr('无正文', 'No text'),
                                style: const TextStyle(
                                  color: AppColors.lyricsTextSecondary,
                                ),
                              ),
                            );
                          }
                          return handlerAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, _) => Center(
                              child: Text(
                                context.tr(
                                  '播放器不可用：$error',
                                  'Player unavailable: $error',
                                ),
                                style: const TextStyle(
                                  color: AppColors.lyricsTextSecondary,
                                ),
                              ),
                            ),
                            data: (handler) => SyncedLyricsList(
                              key: ValueKey(
                                '${widget.chapterId}:${handler.currentChapterId}',
                              ),
                              paragraphs: paragraphs,
                              manifest: widget.manifest,
                              handler: handler,
                              playbackEnabled: widget.playbackEnabled,
                              expanded: true,
                              bookId: widget.bookId,
                              bookTitle: widget.bookTitle,
                              chapterTitle: widget.chapterTitle,
                            ),
                          );
                        },
                      ),
                    ),
                    if (widget.playbackEnabled)
                      handlerAsync.when(
                        loading: () => const SizedBox(height: 156),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (handler) => _FullScreenPlaybackControls(
                          key: _controlsKey,
                          handler: handler,
                          backgroundColor: bottomTint,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FullScreenPlaybackControls extends StatefulWidget {
  final LuminaAudioHandler handler;
  final Color backgroundColor;

  const _FullScreenPlaybackControls({
    super.key,
    required this.handler,
    required this.backgroundColor,
  });

  @override
  State<_FullScreenPlaybackControls> createState() =>
      _FullScreenPlaybackControlsState();
}

class _FullScreenPlaybackControlsState
    extends State<_FullScreenPlaybackControls>
    with SingleTickerProviderStateMixin {
  static const _autoHideDelay = Duration(seconds: 3);

  double? _dragProgress;
  Timer? _hideTimer;
  bool _dragging = false;
  late final AnimationController _revealController;
  late final Animation<double> _sizeAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 420),
      value: 1,
    );
    _sizeAnimation = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.15, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.25, 1, curve: Curves.easeInCubic),
    );
    _scheduleHide();
  }

  void showTemporarily() {
    _revealController.forward();
    if (!_dragging) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_autoHideDelay, () {
      if (!mounted || _dragging) return;
      _revealController.reverse();
    });
  }

  void _startDragging(double value) {
    _hideTimer?.cancel();
    setState(() {
      _dragging = true;
      _dragProgress = value;
    });
  }

  void _finishDragging(double value, int durationMs) {
    setState(() {
      _dragging = false;
      _dragProgress = null;
    });
    widget.handler.seek(Duration(milliseconds: (value * durationMs).round()));
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _revealController,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizeTransition(
            sizeFactor: _sizeAnimation,
            alignment: Alignment.bottomCenter,
            child: _buildVisibleControls(context),
          ),
        ),
        builder: (context, child) => IgnorePointer(
          ignoring: _revealController.value < 0.9,
          child: ExcludeSemantics(
            excluding: _revealController.value < 0.05,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildVisibleControls(BuildContext context) {
    return StreamBuilder(
      stream: widget.handler.playbackState,
      initialData: widget.handler.playbackState.value,
      builder: (context, playbackSnapshot) {
        final playing = playbackSnapshot.data?.playing ?? false;
        return StreamBuilder<Duration>(
          stream: widget.handler.chapterPositionStream,
          initialData: widget.handler.chapterPosition,
          builder: (context, positionSnapshot) {
            final duration = widget.handler.chapterDuration;
            final position = positionSnapshot.data ?? Duration.zero;
            final durationMs = duration.inMilliseconds;
            final positionMs = position.inMilliseconds.clamp(0, durationMs);
            final liveProgress = durationMs <= 0
                ? 0.0
                : positionMs / durationMs;
            final progress = (_dragProgress ?? liveProgress).clamp(0.0, 1.0);
            final displayedPosition = _dragProgress == null
                ? Duration(milliseconds: positionMs)
                : Duration(milliseconds: (progress * durationMs).round());
            final remaining = duration - displayedPosition;

            return Container(
              key: const ValueKey('fullscreen-lyrics-controls'),
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.backgroundColor.withValues(alpha: 0),
                    widget.backgroundColor.withValues(alpha: 0.96),
                    widget.backgroundColor,
                  ],
                  stops: const [0, 0.2, 1],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.lyricsTextPrimary,
                      inactiveTrackColor: AppColors.lyricsTextSecondary
                          .withValues(alpha: 0.48),
                      disabledActiveTrackColor: AppColors.lyricsTextSecondary,
                      disabledInactiveTrackColor: AppColors.lyricsTextSecondary
                          .withValues(alpha: 0.28),
                      thumbColor: AppColors.lyricsTextPrimary,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      key: const ValueKey('fullscreen-lyrics-progress'),
                      value: progress,
                      onChangeStart: durationMs <= 0 ? null : _startDragging,
                      onChanged: durationMs <= 0
                          ? null
                          : (value) => setState(() => _dragProgress = value),
                      onChangeEnd: durationMs <= 0
                          ? null
                          : (value) => _finishDragging(value, durationMs),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatPlaybackTime(displayedPosition),
                          style: const TextStyle(
                            color: AppColors.lyricsTextSecondary,
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          '-${_formatPlaybackTime(remaining.isNegative ? Duration.zero : remaining)}',
                          style: const TextStyle(
                            color: AppColors.lyricsTextSecondary,
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    button: true,
                    label: playing
                        ? context.tr('暂停', 'Pause')
                        : context.tr('播放', 'Play'),
                    child: Material(
                      color: AppColors.lyricsTextPrimary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const ValueKey('fullscreen-lyrics-play-pause'),
                        customBorder: const CircleBorder(),
                        onTap: playing
                            ? widget.handler.pause
                            : widget.handler.play,
                        child: SizedBox.square(
                          dimension: 72,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              key: ValueKey(playing),
                              size: 38,
                              color: widget.backgroundColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

String _formatPlaybackTime(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final minutes = safeDuration.inMinutes
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  final seconds = safeDuration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  if (safeDuration.inHours > 0) {
    return '${safeDuration.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
