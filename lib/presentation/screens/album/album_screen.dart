import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../domain/models/chapter_manifest.dart';
import '../../../services/generation_orchestrator.dart';
import '../../../services/manifest_store.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/book_cover.dart';
import '../player/player_screen.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  final drift_db.Book book;

  const AlbumScreen({super.key, required this.book});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  final Map<String, GenerationProgress> _generationProgress = {};
  final Set<String> _generatingChapterIds = {};

  Future<void> _playChapter(drift_db.Chapter chapter, int index) async {
    final manifestStore = ref.read(manifestStoreProvider);

    final manifest = await manifestStore.load(widget.book.id, chapter.id);
    if (manifest != null && manifest.readyCount > 0) {
      if (!manifest.isReady) {
        _showSnackBar(
          '播放已缓存的 ${manifest.readyCount}/${manifest.segments.length} 段',
        );
      }
      await _loadAndOpenPlayer(manifest, chapter);
      return;
    }

    if (_generatingChapterIds.contains(chapter.id)) {
      _showSnackBar('正在合成这一章，请稍等');
      return;
    }

    await _generateChapterThenPlay(chapter);
  }

  Future<void> _loadAndOpenPlayer(
    ChapterManifest manifest,
    drift_db.Chapter chapter,
  ) async {
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
    await handler.play();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerScreen(book: widget.book, initialChapter: chapter),
    );
  }

  Future<void> _generateChapterThenPlay(drift_db.Chapter chapter) async {
    final messenger = ScaffoldMessenger.of(context);
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

      messenger.showSnackBar(SnackBar(content: Text('正在合成：${chapter.title}')));

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
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              manifest.isReady
                  ? '已缓存：${chapter.title}'
                  : '已缓存 ${manifest.readyCount}/${manifest.segments.length} 段，开始播放已缓存内容',
            ),
          ),
        );
        await _loadAndOpenPlayer(manifest, chapter);
      } else {
        _showSnackBar('音频合成未完成，请检查 TTS 设置或重试');
      }
    } catch (e) {
      _showSnackBar('音频合成失败：$e');
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

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.background,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Text(
                    widget.book.title,
                    style: const TextStyle(
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
                            colors: [
                              AppColors.surfaceHighlight,
                              AppColors.background,
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
                            color: AppColors.surface,
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
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
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        chapter.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        widget.book.author ?? "Unknown Artist",
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      trailing: _ChapterCacheStatus(
                        bookId: widget.book.id,
                        chapterId: chapter.id,
                        progress: _generationProgress[chapter.id],
                      ),
                      onTap: () => _playChapter(chapter, index),
                    );
                  }, childCount: chapters.length),
                ),

              // 底部留白，防止被 MiniPlayer 遮挡
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlbumPlayButton(List<drift_db.Chapter> chapters) {
    final firstChapterId = chapters.isEmpty ? null : chapters.first.id;
    final progress = firstChapterId == null
        ? null
        : _generationProgress[firstChapterId];

    return IconButton.filled(
      iconSize: 36,
      padding: const EdgeInsets.all(16),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
      ),
      icon: progress == null
          ? const Icon(Icons.play_arrow)
          : SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                value: progress.percent == 0 ? null : progress.percent,
                strokeWidth: 3,
                color: Colors.black,
              ),
            ),
      onPressed: () {
        if (chapters.isNotEmpty) {
          _playChapter(chapters.first, 0);
        }
      },
    );
  }
}

class _ChapterCacheStatus extends StatelessWidget {
  final String bookId;
  final String chapterId;
  final GenerationProgress? progress;

  const _ChapterCacheStatus({
    required this.bookId,
    required this.chapterId,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    if (progress != null) {
      return SizedBox(
        width: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: progress.percent == 0 ? null : progress.percent,
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress.percent * 100).round()}%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<ChapterManifest?>(
      future: ManifestStore().load(bookId, chapterId),
      builder: (context, snapshot) {
        final manifest = snapshot.data;
        if (manifest != null && manifest.isReady) {
          return const Tooltip(
            message: '音频已缓存',
            child: Icon(Icons.download_done, color: AppColors.primary),
          );
        }
        if (manifest != null && manifest.readyCount > 0) {
          return Tooltip(
            message: '部分音频已缓存',
            child: Text(
              '${manifest.readyCount}/${manifest.segments.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        return const Icon(Icons.more_vert, color: AppColors.textSecondary);
      },
    );
  }
}
