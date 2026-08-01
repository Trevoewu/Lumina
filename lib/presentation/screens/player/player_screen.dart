import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../ai/ai_models.dart';
import '../../../ai/transcript_tool.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/app_preferences.dart';
import '../../../core/providers.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../data/settings/provider_selection_repository.dart';
import '../../../domain/models/audio_text_timing.dart';
import '../../../domain/models/chapter_manifest.dart';
import '../../../services/app_log_service.dart';
import '../../../services/book_playback_queue.dart';
import '../../../services/cover_palette_service.dart';
import '../../../services/generation_orchestrator.dart';
import '../../../services/lumina_audio_handler.dart';
import '../../../services/podcast_transcription_service.dart';
import '../../../services/sleep_timer_service.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/ai_summary_panel.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/podcast_artwork.dart';
import '../../widgets/podcast_link_text.dart';
import '../../widgets/synced_lyrics_list.dart';
import '../settings/dictionary_explanation_service_screen.dart';
import '../settings/tts_service_screen.dart';

enum PlayerPrimaryAudioAction { play, pause }

PlayerPrimaryAudioAction resolvePlayerPrimaryAudioAction({
  required bool playing,
  required bool playbackRequested,
}) {
  return playing || playbackRequested
      ? PlayerPrimaryAudioAction.pause
      : PlayerPrimaryAudioAction.play;
}

int resolveAudiobookChapterPositionMs({
  required ChapterManifest? manifest,
  required int? savedPositionMs,
  required int? legacyParagraphIndex,
  required int legacyParagraphOffsetMs,
}) {
  if (savedPositionMs != null) return math.max(0, savedPositionMs);
  if (manifest == null || legacyParagraphIndex == null) return 0;
  if (manifest.segments.isEmpty) return 0;

  final paragraphIndex = legacyParagraphIndex.clamp(
    0,
    manifest.segments.length - 1,
  );
  var positionMs = 0;
  for (var index = 0; index < paragraphIndex; index++) {
    positionMs += manifest.segments[index].durationMs;
  }
  final paragraphDurationMs = manifest.segments[paragraphIndex].durationMs;
  positionMs += legacyParagraphOffsetMs.clamp(0, paragraphDurationMs);
  return positionMs;
}

class PlayerScreen extends ConsumerStatefulWidget {
  final drift_db.Book book;
  final drift_db.Chapter? initialChapter;
  final PodcastPlayerData? podcast;
  final bool autoplayOnOpen;

  const PlayerScreen({
    super.key,
    required this.book,
    this.initialChapter,
    this.podcast,
    this.autoplayOnOpen = false,
  });

  factory PlayerScreen.podcast({
    Key? key,
    required PodcastPlayerData podcast,
    bool autoplayOnOpen = false,
  }) {
    final episode = podcast.episode;
    final show = podcast.show;
    final bookId = 'podcast:${show.id}';
    return PlayerScreen(
      key: key,
      podcast: podcast,
      autoplayOnOpen: autoplayOnOpen,
      book: drift_db.Book(
        id: bookId,
        title: show.title,
        author: show.title,
        format: 'podcast',
        sourcePath: episode.audioUrl,
        chapterCount: podcast.episodes.length,
        paragraphCount: 1,
        currentChapterId: episode.id,
        currentParagraphIndex: 0,
        playbackOffsetMs: episode.playbackPositionMs,
        importedAt: episode.publishedAt,
        lastReadAt: episode.lastPlayedAt,
        isRead: false,
        kind: 'podcast',
        externalSource: 'podcast',
        externalId: show.id,
        rightsStatus: 'streaming',
        language: show.language,
      ),
      initialChapter: drift_db.Chapter(
        id: episode.id,
        bookId: bookId,
        chapterIndex: 0,
        title: episode.title,
        textOffset: 0,
        isHidden: false,
      ),
    );
  }

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class PodcastPlayerData {
  final drift_db.PodcastEpisode episode;
  final drift_db.PodcastShow show;
  final List<drift_db.PodcastEpisode> episodes;

  const PodcastPlayerData({
    required this.episode,
    required this.show,
    required this.episodes,
  });
}

class _PodcastTranscriptContent {
  final ChapterManifest manifest;
  final List<drift_db.Paragraph> paragraphs;
  final int timingCount;

  const _PodcastTranscriptContent({
    required this.manifest,
    required this.paragraphs,
    required this.timingCount,
  });
}

/// `ChapterManifest` and `Paragraph` compare by identity, so a rebuilt
/// transcript always looks new to `SyncedLyricsList` and costs a full line
/// rebuild plus a forced re-scroll. Episode rows change for reasons that leave
/// the transcript untouched — a status flip, a cached audio path — so compare
/// the content and hand back the previous instance when nothing moved.
bool _podcastTranscriptContentMatches(
  _PodcastTranscriptContent? previous,
  _PodcastTranscriptContent next,
) {
  if (previous == null) return false;
  if (previous.timingCount != next.timingCount) return false;
  if (previous.paragraphs.length != next.paragraphs.length) return false;
  for (var index = 0; index < previous.paragraphs.length; index++) {
    final before = previous.paragraphs[index];
    final after = next.paragraphs[index];
    if (before.id != after.id || before.content != after.content) return false;
  }

  final previousSegments = previous.manifest.segments;
  final nextSegments = next.manifest.segments;
  if (previousSegments.length != nextSegments.length) return false;
  for (var index = 0; index < previousSegments.length; index++) {
    final before = previousSegments[index];
    final after = nextSegments[index];
    if (before.paragraphId != after.paragraphId ||
        before.audioFile != after.audioFile ||
        before.durationMs != after.durationMs ||
        before.timings.length != after.timings.length) {
      return false;
    }
    for (var position = 0; position < before.timings.length; position++) {
      final beforeTiming = before.timings[position];
      final afterTiming = after.timings[position];
      if (beforeTiming.startMs != afterTiming.startMs ||
          beforeTiming.endMs != afterTiming.endMs ||
          beforeTiming.text != afterTiming.text) {
        return false;
      }
    }
  }
  return true;
}

/// Playback progress changes once per second and must not invalidate the
/// transcript UI. Only fields that can affect this player return true here.
bool podcastEpisodeRequiresPlayerRefresh(
  drift_db.PodcastEpisode? previous,
  drift_db.PodcastEpisode? next,
) {
  if (identical(previous, next)) return false;
  if (previous == null || next == null) return previous != next;
  return previous.id != next.id ||
      previous.showId != next.showId ||
      previous.guid != next.guid ||
      previous.title != next.title ||
      previous.description != next.description ||
      previous.audioUrl != next.audioUrl ||
      previous.imageUrl != next.imageUrl ||
      previous.publishedAt != next.publishedAt ||
      previous.durationMs != next.durationMs ||
      previous.localAudioPath != next.localAudioPath ||
      previous.transcriptJson != next.transcriptJson ||
      previous.transcriptLanguage != next.transcriptLanguage ||
      previous.transcriptStatus != next.transcriptStatus ||
      previous.transcriptError != next.transcriptError ||
      previous.sourceTranscriptUrl != next.sourceTranscriptUrl;
}

const _transcriptSentenceTerminators = {'.', '?', '!', '。', '？', '！', '…'};
const _transcriptClosingMarks = {
  '"',
  '”',
  '’',
  "'",
  ')',
  ']',
  '}',
  '》',
  '」',
  '』',
};
final _transcriptCjkPattern = RegExp(
  '[\u3000-\u9fff\uff00-\uffef]',
  unicode: true,
);

/// Whisper cuts a segment on every pause, so one sentence routinely spans
/// several of them. Stitching the unterminated halves back together keeps the
/// lyrics widget from rendering "So the thing I meant" as its own line.
///
/// [maxMergedChars] only bounds speech Whisper transcribed without any final
/// punctuation at all; ordinary sentences merge in full and the lyrics widget
/// still wraps the long ones on its own clause boundaries.
String joinPodcastTranscriptLines(
  List<AudioTextTiming> timings, {
  int maxMergedChars = 200,
}) {
  final buffer = StringBuffer();
  var pending = '';
  int? pendingChunkStartMs;

  void flush() {
    if (pending.isEmpty) return;
    if (buffer.isNotEmpty) buffer.write('\n');
    buffer.write(pending);
    pending = '';
    pendingChunkStartMs = null;
  }

  for (final timing in timings) {
    final text = timing.text.trim();
    if (text.isEmpty) continue;
    if (pending.isEmpty) {
      pending = text;
      pendingChunkStartMs = timing.chunkStartMs;
      continue;
    }
    final crossedChunkBoundary =
        pendingChunkStartMs != null &&
        timing.chunkStartMs != null &&
        pendingChunkStartMs != timing.chunkStartMs;
    if (crossedChunkBoundary ||
        _endsPodcastSentence(pending) ||
        pending.length + text.length > maxMergedChars) {
      flush();
      pending = text;
      pendingChunkStartMs = timing.chunkStartMs;
      continue;
    }
    pending = '$pending${_transcriptJoinSeparator(pending, text)}$text';
  }
  flush();
  return buffer.toString();
}

bool _endsPodcastSentence(String text) {
  var index = text.length - 1;
  while (index >= 0 &&
      (_transcriptClosingMarks.contains(text[index]) ||
          text[index].trim().isEmpty)) {
    index--;
  }
  if (index < 0) return false;
  return _transcriptSentenceTerminators.contains(text[index]);
}

/// CJK segments read as one sentence without a separator; a space there shows
/// up as a visible gap mid-word.
String _transcriptJoinSeparator(String previous, String next) {
  final left = previous[previous.length - 1];
  final right = next[0];
  if (_transcriptCjkPattern.hasMatch(left) &&
      _transcriptCjkPattern.hasMatch(right)) {
    return '';
  }
  return ' ';
}

_PodcastTranscriptContent _buildPodcastTranscriptContent(
  PodcastPlayerData data,
  drift_db.PodcastEpisode episode,
) {
  final timings = PodcastTranscriptionService.decodeTranscript(
    episode.transcriptJson,
  );
  final transcriptEndMs = timings.fold<int>(
    0,
    (maximum, timing) => math.max(maximum, timing.endMs),
  );
  final manifest = ChapterManifest(
    chapterId: episode.id,
    bookId: 'podcast:${data.show.id}',
    providerId: 'whisper-local',
    voiceId: '',
    speed: 1,
    segments: [
      SegmentEntry(
        paragraphId: episode.id,
        audioFile: episode.audioUrl,
        durationMs: math.max(episode.durationMs, transcriptEndMs),
        state: ParagraphAudioState.ready,
        format: 'podcast',
        timings: timings,
      ),
    ],
    updatedAt: episode.lastPlayedAt,
  );
  final paragraphs = timings.isEmpty
      ? const <drift_db.Paragraph>[]
      : [
          drift_db.Paragraph(
            id: episode.id,
            chapterId: episode.id,
            bookId: 'podcast:${data.show.id}',
            paragraphIndex: 0,
            // Newlines are hard line breaks for the lyrics widget, so only the
            // Whisper boundaries that end a sentence keep one. The episode
            // still stays a single seekable paragraph.
            content: joinPodcastTranscriptLines(timings),
          ),
        ];
  return _PodcastTranscriptContent(
    manifest: manifest,
    paragraphs: paragraphs,
    timingCount: timings.length,
  );
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const _playerTransitionDuration = Duration(milliseconds: 480);

  final ScrollController _playerScrollController = ScrollController();
  double _speed = 1.0;
  double _stickyMiniPlayerTriggerOffset = 360;
  bool _showStickyMiniPlayer = false;
  ChapterManifest? _selectedManifest;
  GenerationProgress? _generationProgress;
  StreamSubscription<GenerationProgress>? _generationSubscription;
  Future<void> _generationUpdate = Future.value();
  bool _preparingStream = false;
  bool _streamPlaybackRequested = false;
  bool _startingPlayback = false;
  final ValueNotifier<int> _controlStateRevision = ValueNotifier<int>(0);
  int _paragraphCount = 0;
  drift_db.ChapterPlaybackProgress? _chapterPlaybackProgress;
  drift_db.PodcastEpisode? _podcastEpisode;
  _PodcastTranscriptContent? _podcastTranscript;
  StreamSubscription<drift_db.PodcastEpisode?>? _podcastEpisodeSubscription;
  StreamSubscription<PodcastTranscriptionProgress>? _transcriptionSubscription;
  bool _transcribingPodcast = false;
  bool _pausingPodcastTranscription = false;
  PodcastTranscriptionProgress? _transcriptionProgress;
  bool _autoplayHandled = false;
  bool _showFullPodcastNotes = false;
  double _readingScrollSpeed = 1.0;
  bool _lyricSweepEnabled = true;

  bool get _isPodcast => widget.podcast != null;

  @override
  void initState() {
    super.initState();
    _playerScrollController.addListener(_handlePlayerScroll);
    _podcastEpisode = widget.podcast?.episode;
    if (_isPodcast) {
      final transcript = _buildPodcastTranscriptContent(
        widget.podcast!,
        _podcastEpisode!,
      );
      _podcastTranscript = transcript;
      _selectedManifest = transcript.manifest;
      _paragraphCount = transcript.paragraphs.length;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPlaybackSpeed());
      if (_isPodcast) {
        _watchPodcastEpisode();
        _watchTranscriptionProgress();
        unawaited(_autoplayIfRequested());
      } else {
        unawaited(_loadSelectedChapterState());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_generationSubscription?.cancel());
    unawaited(_podcastEpisodeSubscription?.cancel());
    unawaited(_transcriptionSubscription?.cancel());
    _playerScrollController
      ..removeListener(_handlePlayerScroll)
      ..dispose();
    _controlStateRevision.dispose();
    super.dispose();
  }

  void _handlePlayerScroll() {
    if (!_playerScrollController.hasClients) return;
    final offset = _playerScrollController.offset;
    final shouldShow = _showStickyMiniPlayer
        ? offset >= _stickyMiniPlayerTriggerOffset - 24
        : offset >= _stickyMiniPlayerTriggerOffset;
    if (shouldShow == _showStickyMiniPlayer || !mounted) return;
    setState(() => _showStickyMiniPlayer = shouldShow);
  }

  void _setStreamPlaybackRequested(bool value) {
    if (_streamPlaybackRequested == value) return;
    _streamPlaybackRequested = value;
    _controlStateRevision.value++;
  }

  void _setStartingPlayback(bool value) {
    if (_startingPlayback == value) return;
    _startingPlayback = value;
    _controlStateRevision.value++;
  }

  void _watchPodcastEpisode() {
    final data = widget.podcast;
    if (data == null) return;
    unawaited(_podcastEpisodeSubscription?.cancel());
    _podcastEpisodeSubscription = ref
        .read(appDatabaseProvider)
        .watchPodcastEpisode(data.episode.id)
        .listen((episode) {
          if (!mounted || episode == null) return;
          if (!podcastEpisodeRequiresPlayerRefresh(_podcastEpisode, episode)) {
            return;
          }
          final rebuilt = _buildPodcastTranscriptContent(data, episode);
          final previous = _podcastTranscript;
          final transcript = _podcastTranscriptContentMatches(previous, rebuilt)
              ? previous!
              : rebuilt;
          setState(() {
            _podcastEpisode = episode;
            _podcastTranscript = transcript;
            _selectedManifest = transcript.manifest;
            _paragraphCount = transcript.paragraphs.length;
          });
        });
  }

  Future<void> _loadSelectedChapterState() async {
    final chapter = widget.initialChapter;
    if (chapter == null) return;

    final database = ref.read(appDatabaseProvider);
    final manifestStore = ref.read(manifestStoreProvider);
    final results = await Future.wait<Object?>([
      manifestStore.load(widget.book.id, chapter.id),
      database.getParagraphs(chapter.id),
      database.getChapterPlaybackProgress(chapter.id),
    ]);
    if (!mounted) return;
    final manifest = results[0] as ChapterManifest?;
    final paragraphs = results[1] as List<drift_db.Paragraph>;
    final playbackProgress = results[2] as drift_db.ChapterPlaybackProgress?;
    setState(() {
      _selectedManifest = manifest;
      _paragraphCount = paragraphs.length;
      _chapterPlaybackProgress = playbackProgress;
    });

    final activeGeneration = ref
        .read(generationOrchestratorProvider)
        .watchChapterGeneration(bookId: widget.book.id, chapterId: chapter.id);
    if (activeGeneration != null) {
      _listenToGeneration(activeGeneration);
    }
    await _autoplayIfRequested();
  }

  Future<void> _autoplayIfRequested() async {
    if (!widget.autoplayOnOpen || _autoplayHandled || !mounted) return;
    _autoplayHandled = true;
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    if (!mounted) return;
    final alreadyPlaying =
        _isSelectedChapterLoaded(handler) &&
        handler.playbackState.value.playing;
    if (alreadyPlaying) return;
    await _handlePrimaryAudioAction(handler, false);
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
        setState(() => _generationSubscription = null);
        _setStreamPlaybackRequested(false);
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
    });
    _setStreamPlaybackRequested(false);
  }

  Future<bool> _ensureChapterCachingStarted() async {
    final chapter = widget.initialChapter;
    if (chapter == null) return false;
    if (_generationSubscription != null) return true;
    if (_preparingStream) return false;

    setState(() => _preparingStream = true);
    try {
      var provider = ref.read(activeTtsProviderProvider);
      var selections = ref.read(providerSelectionRepositoryProvider);
      var providerConnected = await provider.validate();
      var selectedModel = await selections.selectedTtsModel(provider.id);
      var selectedVoice = await selections.selectedVoice(provider.id);
      if (!providerConnected ||
          selectedModel == null ||
          selectedVoice == null) {
        if (!mounted ||
            !await _openTtsSetupPrompt(
              provider.displayName,
              setupIncomplete: providerConnected,
            )) {
          return false;
        }
        ref.invalidate(ttsSettingsControllerProvider);
        await ref.read(ttsSettingsControllerProvider.future);
        provider = ref.read(activeTtsProviderProvider);
        selections = ref.read(providerSelectionRepositoryProvider);
        providerConnected = await provider.validate();
        selectedModel = await selections.selectedTtsModel(provider.id);
        selectedVoice = await selections.selectedVoice(provider.id);
        if (!providerConnected ||
            selectedModel == null ||
            selectedVoice == null) {
          return false;
        }
      }
      final database = ref.read(appDatabaseProvider);
      final voice = await _resolveVoice(
        provider,
        database,
        selections,
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

  Future<bool> _openTtsSetupPrompt(
    String providerName, {
    bool setupIncomplete = false,
  }) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cloud_outlined),
        title: Text(
          setupIncomplete
              ? context.tr('完成语音设置', 'Complete voice setup')
              : context.tr('连接语音服务', 'Connect a voice provider'),
        ),
        content: Text(
          setupIncomplete
              ? context.tr(
                  '$providerName 已连接，但还需要选择语音模型和朗读音色。'
                      '完成后，Lumina 会自动继续生成当前章节。',
                  '$providerName is connected, but a voice model and reading voice still need to be selected. '
                      'Lumina will continue generating the current chapter after setup.',
                )
              : context.tr(
                  '当前的 $providerName 尚未连接。完成云端语音服务设置后，Lumina 会自动继续生成当前章节。',
                  '$providerName is not connected. Lumina will continue generating the current chapter after cloud voice setup.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('暂不', 'Not now')),
          ),
          FilledButton(
            key: const ValueKey('open-tts-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('去设置', 'Open settings')),
          ),
        ],
      ),
    );
    if (openSettings != true || !mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TtsServiceScreen(returnWhenReady: true),
      ),
    );
    return mounted;
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
    if (_isPodcast) {
      if (handler.currentPodcastEpisodeId != _podcastEpisode?.id) {
        return false;
      }
      final localPath = _podcastEpisode?.localAudioPath;
      if (localPath == null || !File(localPath).existsSync()) return true;
      // Transcription timestamps are generated from the cached file. A queue
      // that still points to the feed URL is not equivalent, especially for
      // feeds with redirects or dynamic ad insertion.
      return handler.mediaItem.valueOrNull?.extras?['audioUrl'] ==
          File(localPath).uri.toString();
    }
    final chapter = widget.initialChapter;
    if (chapter == null) return handler.currentBookId == widget.book.id;
    return handler.currentBookId == widget.book.id &&
        handler.currentChapterId == chapter.id;
  }

  ChapterManifest? _effectiveManifest(LuminaAudioHandler handler) {
    if (_isPodcast) return _selectedManifest;
    return widget.initialChapter == null
        ? handler.currentManifest
        : _selectedManifest;
  }

  double _cacheFraction(ChapterManifest? manifest) {
    if (_isPodcast) return 1;
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
      _setStreamPlaybackRequested(false);
      await handler.pause();
      return;
    }

    if (_isPodcast) {
      _setStartingPlayback(true);
      try {
        if (!_isSelectedChapterLoaded(handler)) {
          await _loadPodcastPlayback(handler);
        }
        await handler.play();
      } catch (error, stackTrace) {
        AppLogger.error(
          'Playback',
          'Podcast 播放失败 episode=${_podcastEpisode?.id}',
          error: error,
          stackTrace: stackTrace,
        );
        if (mounted) {
          _showSnackBar(
            context.tr('Podcast 播放失败：$error', 'Unable to play podcast: $error'),
          );
        }
      } finally {
        if (mounted) _setStartingPlayback(false);
      }
      return;
    }

    final chapter = widget.initialChapter;
    if (chapter == null) {
      await handler.play();
      return;
    }

    _setStreamPlaybackRequested(true);
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
      _setStreamPlaybackRequested(false);
    }
  }

  Future<void> _loadPodcastPlayback(LuminaAudioHandler handler) async {
    final data = widget.podcast;
    final selected = _podcastEpisode;
    if (data == null || selected == null) return;

    final database = ref.read(appDatabaseProvider);
    final freshEpisodes = await database.getPodcastEpisodes(data.show.id);
    final episodes = freshEpisodes.isEmpty ? data.episodes : freshEpisodes;

    String playbackUrl(drift_db.PodcastEpisode episode) {
      final localPath = episode.localAudioPath;
      if (localPath != null && File(localPath).existsSync()) {
        return File(localPath).uri.toString();
      }
      return episode.audioUrl;
    }

    await handler.loadPodcastQueue(
      episodes: [
        for (final episode in episodes)
          PodcastPlaybackSource(
            episodeId: episode.id,
            showId: data.show.id,
            showTitle: data.show.title,
            title: episode.title,
            audioUrl: playbackUrl(episode),
            imageUrl: episode.imageUrl ?? data.show.imageUrl,
            durationMs: episode.durationMs,
          ),
      ],
      initialEpisodeId: selected.id,
      initialPosition: Duration(milliseconds: selected.playbackPositionMs),
    );
  }

  /// A run outlives the screen that started it, so the transcript card reads
  /// its state from the service instead of a flag set on tap. Reopening the
  /// episode — or opening a different one — then shows the truth.
  void _watchTranscriptionProgress() {
    final episode = _podcastEpisode;
    if (episode == null) return;
    final service = ref.read(podcastTranscriptionServiceProvider);
    setState(() {
      _transcribingPodcast = service.activeEpisodeId == episode.id;
    });
    unawaited(_transcriptionSubscription?.cancel());
    _transcriptionSubscription = service.progressStream.listen((progress) {
      if (!mounted || progress.episodeId != _podcastEpisode?.id) return;
      setState(() {
        _transcribingPodcast = progress.running;
        _transcriptionProgress = progress.running ? progress : null;
      });
    });
  }

  bool _transcriptPaused(drift_db.PodcastEpisode episode) =>
      episode.transcriptStatus == podcastTranscriptPausedStatus &&
      episode.transcriptProgressMs > 0;

  Future<void> _pausePodcastTranscription() async {
    if (_pausingPodcastTranscription) return;
    final service = ref.read(podcastTranscriptionServiceProvider);
    // Whisper finishes the chunk it is holding before it lets go, which can
    // take a while on a long chunk size. Say so instead of looking stuck.
    setState(() => _pausingPodcastTranscription = true);
    try {
      await service.pause();
    } finally {
      if (mounted) {
        setState(() {
          _pausingPodcastTranscription = false;
          _transcribingPodcast = false;
          _transcriptionProgress = null;
        });
      }
    }
  }

  Future<void> _startPodcastTranscription() async {
    final data = widget.podcast;
    final episode = _podcastEpisode;
    if (data == null || episode == null || _transcribingPodcast) return;

    if (!await _ensureWhisperModelReady()) return;
    if (!mounted) return;
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    if (handler.playbackState.value.playing) await handler.pause();
    if (!mounted) return;
    setState(() {
      _transcribingPodcast = true;
      _transcriptionProgress = PodcastTranscriptionProgress(
        episodeId: episode.id,
        stage: PodcastTranscriptionStage.preparing,
        message: '正在准备本地转写',
      );
    });

    try {
      final languagePreference = await ref
          .read(appDatabaseProvider)
          .getSetting(PodcastTranscriptionService.languagePreferenceSettingKey);
      await ref
          .read(podcastTranscriptionServiceProvider)
          .transcribe(
            episode,
            languageHint:
                languagePreference ==
                    PodcastTranscriptionService.automaticLanguagePreference
                ? null
                : data.show.language,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _transcriptionProgress = progress);
              }
            },
          );
    } catch (error) {
      if (mounted) {
        _showSnackBar(
          context.tr('本地转写失败：$error', 'Local transcription failed: $error'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _transcribingPodcast = false;
          _transcriptionProgress = null;
        });
      }
    }
  }

  Future<void> _restartPodcastTranscription() async {
    final episode = _podcastEpisode;
    if (episode == null || _transcribingPodcast) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('重新生成字幕？', 'Regenerate transcript?')),
        content: Text(
          context.tr(
            '当前字幕会被删除，然后从头重新转写。',
            'The current transcript will be deleted and transcribed again from the beginning.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('重新生成', 'Regenerate')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(cacheManagerProvider)
        .clearPodcastEpisodeTranscript(episode.id);
    if (!mounted) return;
    await _startPodcastTranscription();
  }

  Future<void> _deletePodcastTranscript() async {
    final episode = _podcastEpisode;
    if (episode == null || _transcribingPodcast) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('删除字幕？', 'Delete transcript?')),
        content: Text(
          context.tr(
            '只删除本地字幕，Podcast 音频会保留。之后可以重新生成。',
            'Only the local transcript will be deleted. Podcast audio will be kept and you can generate it again later.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(cacheManagerProvider)
          .clearPodcastEpisodeTranscript(episode.id);
      if (mounted) {
        _showSnackBar(context.tr('字幕已删除', 'Transcript deleted'));
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Podcast',
        '删除 Podcast 字幕失败 episode=${episode.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar(
          context.tr('字幕删除失败：$error', 'Unable to delete transcript: $error'),
        );
      }
    }
  }

  Future<bool> _ensureWhisperModelReady() async {
    final service = ref.read(podcastTranscriptionServiceProvider);
    try {
      final info = await service.getModelInfo();
      if (info.installed) return true;
      if (!mounted) return false;
      final installed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: true,
        builder: (_) => _WhisperModelSetupSheet(
          service: service,
          expectedBytes: info.expectedBytes,
        ),
      );
      if (installed == true) {
        ref.invalidate(asrSettingsControllerProvider);
        return true;
      }
      return false;
    } catch (error) {
      if (mounted) {
        _showSnackBar(
          context.tr(
            '无法检查字幕模型：$error',
            'Unable to check the transcript model: $error',
          ),
        );
      }
      return false;
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
    _setStartingPlayback(true);
    try {
      return await _playCachedAudio(handler, manifest: manifest);
    } finally {
      if (mounted) _setStartingPlayback(false);
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
    if (latestManifest != null &&
        !identical(latestManifest, _selectedManifest)) {
      setState(() => _selectedManifest = latestManifest);
    }
    if (latestManifest == null) return false;
    final playable = _playablePrefix(latestManifest);
    if (playable.segments.isEmpty) {
      return false;
    }

    final loadedManifest = _isSelectedChapterLoaded(handler)
        ? handler.currentManifest
        : null;
    if (loadedManifest == null) {
      final initialPosition = Duration(
        milliseconds: resolveAudiobookChapterPositionMs(
          manifest: latestManifest,
          savedPositionMs: _chapterPlaybackProgress?.positionMs,
          legacyParagraphIndex:
              _chapterPlaybackProgress == null &&
                  widget.book.currentChapterId == chapter.id
              ? widget.book.currentParagraphIndex
              : null,
          legacyParagraphOffsetMs: widget.book.playbackOffsetMs,
        ),
      );
      try {
        if (latestManifest.isReady) {
          await loadBookPlaybackQueue(
            handler: handler,
            database: ref.read(appDatabaseProvider),
            manifestStore: ref.read(manifestStoreProvider),
            bookId: widget.book.id,
            bookTitle: widget.book.title,
            coverPath: widget.book.coverPath,
            initialManifest: playable,
            paragraphLabel: paragraphLabel,
            initialPosition: initialPosition,
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
            coverPath: widget.book.coverPath,
            paragraphLabel: paragraphLabel,
            initialPosition: initialPosition,
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
    await handler.play();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider);
    _readingScrollSpeed = preferences.readingScrollSpeed;
    _lyricSweepEnabled = preferences.lyricSweepEnabled;
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    final theme = Theme.of(context);
    final topTint = theme.colorScheme.surfaceContainer;
    final pageBottom = theme.colorScheme.surface;
    final middleTint = Color.lerp(topTint, pageBottom, 0.62)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: pageBottom,
        body: Container(
          key: const ValueKey('player-immersive-background'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topTint, middleTint, pageBottom],
              stops: const [0, 0.46, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildPlayerHeader(handlerAsync),
                Expanded(
                  child: handlerAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: context.appTextPrimary,
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Text(
                        context.tr(
                          '播放器不可用：$error',
                          'Player unavailable: $error',
                        ),
                        style: TextStyle(color: context.appTextSecondary),
                      ),
                    ),
                    data: (handler) => StreamBuilder<String?>(
                      stream: handler.mediaItem.map((item) {
                        final extras = item?.extras;
                        final podcastEpisodeId =
                            extras?['podcastEpisodeId'] as String?;
                        if (podcastEpisodeId != null) {
                          return 'podcast:$podcastEpisodeId';
                        }
                        final bookId = extras?['bookId'] as String?;
                        final chapterId = extras?['chapterId'] as String?;
                        return bookId == null || chapterId == null
                            ? null
                            : 'book:$bookId:$chapterId';
                      }).distinct(),
                      initialData: () {
                        final extras = handler.mediaItem.valueOrNull?.extras;
                        final podcastEpisodeId =
                            extras?['podcastEpisodeId'] as String?;
                        if (podcastEpisodeId != null) {
                          return 'podcast:$podcastEpisodeId';
                        }
                        final bookId = extras?['bookId'] as String?;
                        final chapterId = extras?['chapterId'] as String?;
                        return bookId == null || chapterId == null
                            ? null
                            : 'book:$bookId:$chapterId';
                      }(),
                      builder: (context, snapshot) {
                        final currentItem = handler.mediaItem.valueOrNull;
                        final selectedLoaded = _isSelectedChapterLoaded(
                          handler,
                        );
                        final manifest = _effectiveManifest(handler);
                        final duration = selectedLoaded
                            ? handler.chapterDuration
                            : Duration(
                                milliseconds: manifest?.totalDurationMs ?? 0,
                              );
                        final currentChapterId =
                            widget.initialChapter?.id ??
                            currentItem?.extras?['chapterId'] as String?;
                        final chapterTitle =
                            widget.initialChapter?.title ??
                            currentItem?.title ??
                            context.tr('未知章节', 'Unknown Chapter');

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            if (_isPodcast) {
                              return _buildPodcastPlayerBody(
                                constraints: constraints,
                                handler: handler,
                                selectedLoaded: selectedLoaded,
                                duration: duration,
                                manifest: manifest,
                                chapterId: currentChapterId,
                                chapterTitle: chapterTitle,
                              );
                            }
                            return _buildBookPlayerBody(
                              constraints: constraints,
                              handler: handler,
                              selectedLoaded: selectedLoaded,
                              duration: duration,
                              manifest: manifest,
                              chapterId: currentChapterId,
                              chapterTitle: chapterTitle,
                            );
                          },
                        );
                      },
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

  Widget _buildBookPlayerBody({
    required BoxConstraints constraints,
    required LuminaAudioHandler handler,
    required bool selectedLoaded,
    required Duration duration,
    required ChapterManifest? manifest,
    required String? chapterId,
    required String chapterTitle,
  }) {
    final design = context.appDesign;
    final pageInset = design.pageInsetFor(constraints.maxWidth);
    final compact = constraints.maxHeight < 720;
    final availableArtworkWidth = math.max(
      0.0,
      constraints.maxWidth - pageInset * 2,
    );
    final artworkSize = math.min(
      availableArtworkWidth,
      compact ? 260.0 : 320.0,
    );
    final viewportContentHeight = math.max(
      0.0,
      constraints.maxHeight - design.spaceLg,
    );
    _stickyMiniPlayerTriggerOffset =
        artworkSize + (compact ? design.spaceSm : design.spaceLg);

    return SingleChildScrollView(
      key: const ValueKey('book-player-scroll-view'),
      controller: _playerScrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: design.spaceXxl),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewportContentHeight),
        child: Column(
          children: [
            SizedBox(height: compact ? design.spaceSm : design.spaceLg),
            _buildArtwork(artworkSize, borderRadius: design.radiusLarge),
            SizedBox(height: compact ? design.spaceLg : design.spaceXl),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pageInset),
              child: _buildChapterMetadata(chapterTitle),
            ),
            SizedBox(height: design.spaceLg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pageInset),
              child: _buildReactiveControls(
                handler: handler,
                fallbackDuration: duration,
                manifest: manifest,
                foregroundColor: context.appTextPrimary,
              ),
            ),
            SizedBox(height: design.spaceXxl),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pageInset),
              child: Column(
                children: [
                  _buildAiSummaryCard(handler: handler, manifest: manifest),
                  SizedBox(height: design.spaceMd),
                  _buildBookTextCard(
                    handler: handler,
                    manifest: manifest,
                    chapterId: chapterId,
                    playbackEnabled: selectedLoaded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookTextCard({
    required LuminaAudioHandler handler,
    required ChapterManifest? manifest,
    required String? chapterId,
    required bool playbackEnabled,
  }) {
    return _buildPlayerSectionCard(
      key: const ValueKey('book-text-card'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.appDesign.spaceLg,
              context.appDesign.spaceMd,
              context.appDesign.spaceSm,
              context.appDesign.spaceXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPlayerCardTitle(
                    icon: Icons.auto_stories_rounded,
                    title: context.tr('同步正文', 'Synchronized text'),
                  ),
                ),
                if (chapterId != null)
                  IconButton(
                    tooltip: context.tr('全屏正文', 'Full-screen text'),
                    icon: const Icon(Icons.open_in_full_rounded, size: 20),
                    onPressed: () => _showFullScreenLyrics(
                      chapterId,
                      manifest,
                      playbackEnabled,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: chapterId == null
                ? Center(child: Text(context.tr('无正文', 'No text')))
                : _buildSyncedLyrics(
                    chapterId: chapterId,
                    handler: handler,
                    manifest: manifest,
                    playbackEnabled: playbackEnabled,
                    expanded: false,
                    focusMode: false,
                    listKey: ValueKey(
                      'book-text-list:$chapterId:${handler.currentChapterId}',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodcastPlayerBody({
    required BoxConstraints constraints,
    required LuminaAudioHandler handler,
    required bool selectedLoaded,
    required Duration duration,
    required ChapterManifest? manifest,
    required String? chapterId,
    required String chapterTitle,
  }) {
    final data = widget.podcast!;
    final episode = _podcastEpisode ?? data.episode;
    final design = context.appDesign;
    final pageInset = design.pageInsetFor(constraints.maxWidth);
    final compact = constraints.maxHeight < 720;
    final availableArtworkWidth = math.max(
      0.0,
      constraints.maxWidth - pageInset * 2,
    );
    final artworkSize = math.min(
      availableArtworkWidth,
      compact ? 260.0 : 320.0,
    );
    final viewportContentHeight = math.max(
      0.0,
      constraints.maxHeight - design.spaceLg,
    );
    _stickyMiniPlayerTriggerOffset =
        artworkSize + (compact ? design.spaceSm : design.spaceLg);

    return SingleChildScrollView(
      key: const ValueKey('podcast-player-scroll-view'),
      controller: _playerScrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: design.spaceXxl),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewportContentHeight),
        child: Column(
          children: [
            SizedBox(height: compact ? design.spaceSm : design.spaceLg),
            _buildArtwork(artworkSize, borderRadius: design.radiusLarge),
            SizedBox(height: compact ? design.spaceLg : design.spaceXl),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pageInset),
              child: _buildChapterMetadata(chapterTitle),
            ),
            SizedBox(height: design.spaceLg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pageInset),
              child: _buildReactiveControls(
                handler: handler,
                fallbackDuration: duration,
                manifest: manifest,
                foregroundColor: context.appTextPrimary,
              ),
            ),
            SizedBox(height: design.spaceXxl),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pageInset),
              child: Column(
                children: [
                  _buildPodcastShownotesCard(
                    episode: episode,
                    handler: handler,
                  ),
                  SizedBox(height: design.spaceMd),
                  _buildAiSummaryCard(handler: handler, manifest: manifest),
                  SizedBox(height: design.spaceMd),
                  _buildPodcastTranscriptCard(
                    episode: episode,
                    handler: handler,
                    manifest: manifest,
                    chapterId: chapterId,
                    playbackEnabled: selectedLoaded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSummaryCard({
    required LuminaAudioHandler handler,
    required ChapterManifest? manifest,
  }) {
    final llmState = ref.watch(llmSettingsControllerProvider);
    final aiServiceReady =
        llmState.asData?.value.readiness == ServiceReadiness.ready;
    final podcast = widget.podcast;
    final episode = _podcastEpisode ?? podcast?.episode;
    final chapter = widget.initialChapter;
    final activeChapterId =
        chapter?.id ??
        handler.currentChapterId ??
        widget.book.currentChapterId ??
        widget.book.id;
    final scope = podcast != null && episode != null
        ? AiContentScope(
            type: AiScopeType.episode,
            id: episode.id,
            parentId: podcast.show.id,
            title: episode.title,
            parentTitle: podcast.show.title,
            language: episode.transcriptLanguage ?? podcast.show.language,
            contentRevision: episode.transcriptJson,
          )
        : AiContentScope(
            type: AiScopeType.chapter,
            id: activeChapterId,
            parentId: widget.book.id,
            title: chapter?.title ?? widget.book.title,
            parentTitle: widget.book.title,
            language: widget.book.language,
            contentRevision: chapter?.textOffset,
          );
    return _buildPlayerSectionCard(
      key: const ValueKey('ai-summary-card'),
      child: AiSummaryPanel(
        scope: scope,
        transcriptAvailable: podcast == null
            ? null
            : (_podcastTranscript?.timingCount ?? 0) > 0,
        onCitationTap: (citation) =>
            _handleAiCitation(citation, scope, handler, manifest),
        onTranscriptRequired: _isPodcast ? _startPodcastTranscription : null,
        aiServiceReady: aiServiceReady,
        onAiServiceRequired: _openAiServiceSettings,
      ),
    );
  }

  Future<void> _openAiServiceSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const DictionaryExplanationServiceScreen(returnWhenReady: true),
      ),
    );
    ref.invalidate(llmSettingsControllerProvider);
  }

  Future<void> _handleAiCitation(
    AiCitation citation,
    AiContentScope scope,
    LuminaAudioHandler handler,
    ChapterManifest? manifest,
  ) async {
    final snapshot = await ref.read(aiTranscriptToolsProvider).load(scope);
    AiTranscriptLine? citedLine;
    for (final line in snapshot.lines) {
      if (line.reference == citation.label) {
        citedLine = line;
        break;
      }
    }
    if (!mounted) return;
    if (citedLine == null) {
      _showSnackBar(
        context.tr('找不到这条 Transcript 引用。', 'Transcript reference not found.'),
      );
      return;
    }

    final canPlay =
        _isPodcast || (manifest != null && _isSelectedChapterLoaded(handler));
    final playFromCitation = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.appSurface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          sheetContext.appDesign.spaceLg,
          sheetContext.appDesign.spaceSm,
          sheetContext.appDesign.spaceLg,
          sheetContext.appDesign.spaceXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                SizedBox(width: sheetContext.appDesign.spaceSm),
                Expanded(
                  child: Text(
                    context.tr(
                      'Transcript 引用 ${citation.label}',
                      'Transcript reference ${citation.label}',
                    ),
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(
                          color: sheetContext.appTextPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: sheetContext.appDesign.spaceLg),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(
                  citedLine!.text,
                  style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                    color: sheetContext.appTextPrimary,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            SizedBox(height: sheetContext.appDesign.spaceXl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: Text(context.tr('关闭', 'Close')),
                  ),
                ),
                if (canPlay) ...[
                  SizedBox(width: sheetContext.appDesign.spaceSm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(context.tr('从这里播放', 'Play from here')),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    if (playFromCitation != true || !mounted) return;

    final positionMs = citation.positionMs;
    if (positionMs != null && _isPodcast) {
      if (!_isSelectedChapterLoaded(handler)) {
        await _loadPodcastPlayback(handler);
      }
      await handler.seek(Duration(milliseconds: positionMs));
      return;
    }

    final paragraphIndex = citation.paragraphIndex;
    final chapter = widget.initialChapter;
    if (paragraphIndex == null || chapter == null || manifest == null) return;
    final paragraphs = await ref
        .read(appDatabaseProvider)
        .getParagraphs(chapter.id);
    final zeroBasedIndex = paragraphIndex - 1;
    if (zeroBasedIndex < 0 || zeroBasedIndex >= paragraphs.length) return;
    final offsetMs = manifest.offsetOf(paragraphs[zeroBasedIndex].id);
    await handler.seek(Duration(milliseconds: offsetMs));
  }

  Widget _buildPodcastTranscriptCard({
    required drift_db.PodcastEpisode episode,
    required LuminaAudioHandler handler,
    required ChapterManifest? manifest,
    required String? chapterId,
    required bool playbackEnabled,
  }) {
    final hasTranscript = (_podcastTranscript?.timingCount ?? 0) > 0;
    final safeChapterId = chapterId ?? episode.id;
    return _buildPlayerSectionCard(
      key: const ValueKey('podcast-transcript-card'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.appDesign.spaceLg,
              context.appDesign.spaceMd,
              context.appDesign.spaceSm,
              context.appDesign.spaceXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPlayerCardTitle(
                    icon: Icons.subtitles_rounded,
                    title: context.tr('字幕', 'Transcript'),
                  ),
                ),
                if (_transcribingPodcast)
                  IconButton(
                    key: const ValueKey('podcast-transcript-pause'),
                    tooltip: _pausingPodcastTranscription
                        ? context.tr('正在暂停…', 'Pausing…')
                        : context.tr('暂停转写', 'Pause transcription'),
                    icon: _pausingPodcastTranscription
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.pause_circle_outline, size: 22),
                    onPressed: _pausingPodcastTranscription
                        ? null
                        : _pausePodcastTranscription,
                  )
                else if (hasTranscript)
                  IconButton(
                    key: const ValueKey('podcast-transcript-restart'),
                    tooltip: _transcriptPaused(episode)
                        ? context.tr('继续转写', 'Resume transcription')
                        : context.tr('重新转写', 'Transcribe again'),
                    icon: Icon(
                      _transcriptPaused(episode)
                          ? Icons.play_circle_outline
                          : Icons.auto_awesome_rounded,
                      size: 20,
                    ),
                    onPressed: _transcriptPaused(episode)
                        ? _startPodcastTranscription
                        : _restartPodcastTranscription,
                  ),
                if (hasTranscript)
                  IconButton(
                    key: const ValueKey('podcast-transcript-delete'),
                    tooltip: context.tr('删除字幕', 'Delete transcript'),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: _deletePodcastTranscript,
                  ),
                if (hasTranscript)
                  IconButton(
                    tooltip: context.tr('全屏字幕', 'Full-screen transcript'),
                    icon: const Icon(Icons.open_in_full_rounded, size: 20),
                    onPressed: () => _showFullScreenLyrics(
                      safeChapterId,
                      manifest,
                      playbackEnabled,
                    ),
                  ),
              ],
            ),
          ),
          // The card grows once, when the first cached chunk replaces the
          // placeholder. Animating that step keeps the cards below it from
          // jumping down the screen.
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: hasTranscript ? 280 : 176,
              child: _buildSyncedLyrics(
                chapterId: safeChapterId,
                handler: handler,
                manifest: manifest,
                playbackEnabled: playbackEnabled,
                expanded: false,
                focusMode: false,
                // The segment count must stay out of this key: every cached
                // chunk would otherwise discard the list state and snap the
                // transcript back to the top.
                listKey: ValueKey('podcast-transcript-list:${episode.id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seekToPodcastShownoteTimestamp(
    LuminaAudioHandler handler,
    Duration position,
  ) async {
    if (!_isSelectedChapterLoaded(handler)) {
      await _loadPodcastPlayback(handler);
    }
    if (!mounted) return;
    await handler.seek(position);
  }

  Widget _buildPodcastShownotesCard({
    required drift_db.PodcastEpisode episode,
    required LuminaAudioHandler handler,
  }) {
    final notes = episode.description.trim();
    final canExpand = notes.length > 180;
    return _buildPlayerSectionCard(
      key: const ValueKey('podcast-shownotes-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlayerCardTitle(
            icon: Icons.notes_rounded,
            title: context.tr('节目笔记', 'Shownotes'),
          ),
          SizedBox(height: context.appDesign.spaceMd),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: PodcastLinkText(
              notes.isEmpty
                  ? context.tr('该单集没有附带节目笔记。', 'No shownotes provided.')
                  : notes,
              key: const ValueKey('podcast-episode-description'),
              onSeekTimestamp: (position) =>
                  _seekToPodcastShownoteTimestamp(handler, position),
              maxLines: _showFullPodcastNotes ? null : 5,
              overflow: _showFullPodcastNotes
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
          ),
          if (canExpand) ...[
            SizedBox(height: context.appDesign.spaceSm),
            TextButton.icon(
              key: const ValueKey('podcast-shownotes-toggle'),
              onPressed: () => setState(
                () => _showFullPodcastNotes = !_showFullPodcastNotes,
              ),
              iconAlignment: IconAlignment.end,
              icon: Icon(
                _showFullPodcastNotes
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                _showFullPodcastNotes
                    ? context.tr('收起', 'Show less')
                    : context.tr('查看完整笔记', 'Show full notes'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerSectionCard({
    required Key key,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    final design = context.appDesign;
    return Container(
      key: key,
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(design.spaceLg),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appSurface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.9 : 0.94,
        ),
        borderRadius: BorderRadius.circular(design.radiusLarge),
        border: Border.all(
          color: context.appTextPrimary.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.16
                  : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPlayerCardTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: context.appTextSecondary),
        SizedBox(width: context.appDesign.spaceSm),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerHeader(AsyncValue<LuminaAudioHandler> handlerAsync) {
    final design = context.appDesign;
    return SizedBox(
      height: design.toolbarHeight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _showStickyMiniPlayer
            ? handlerAsync.maybeWhen(
                data: (handler) => _buildStickyMiniPlayerHeader(handler),
                orElse: _buildDefaultPlayerHeader,
              )
            : _buildDefaultPlayerHeader(),
      ),
    );
  }

  Widget _buildDefaultPlayerHeader() {
    final design = context.appDesign;
    return Padding(
      key: const ValueKey('player-default-header'),
      padding: EdgeInsets.symmetric(horizontal: design.spaceSm),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr('收起播放器', 'Close player'),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: context.appTextPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.book.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.appTextPrimary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          IconButton(
            tooltip: context.tr('更多选项', 'More options'),
            icon: Icon(Icons.more_horiz_rounded, color: context.appTextPrimary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStickyMiniPlayerHeader(LuminaAudioHandler handler) {
    final design = context.appDesign;
    final chapterTitle =
        _podcastEpisode?.title ??
        widget.initialChapter?.title ??
        handler.mediaItem.valueOrNull?.title ??
        widget.book.title;
    final sourceTitle = _isPodcast
        ? widget.podcast!.show.title
        : widget.book.title;
    return StreamBuilder(
      key: const ValueKey('player-sticky-mini-player'),
      stream: handler.playbackState,
      initialData: handler.playbackState.value,
      builder: (context, playbackSnapshot) {
        final selectedLoaded = _isSelectedChapterLoaded(handler);
        final playing =
            selectedLoaded && (playbackSnapshot.data?.playing ?? false);
        final duration = selectedLoaded
            ? handler.chapterDuration
            : Duration(
                milliseconds: _effectiveManifest(handler)?.totalDurationMs ?? 0,
              );
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.tr('收起播放器', 'Close player'),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      color: context.appTextPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox.square(
                    dimension: 40,
                    child: _isPodcast
                        ? PodcastArtwork(
                            imageUrl:
                                _podcastEpisode?.imageUrl ??
                                widget.podcast?.show.imageUrl,
                            size: 40,
                            borderRadius: design.radiusSmall,
                          )
                        : BookCover(
                            coverPath: widget.book.coverPath,
                            iconSize: 18,
                            borderRadius: design.radiusSmall,
                          ),
                  ),
                  SizedBox(width: design.spaceSm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.appTextPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          sourceTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.appTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _controlStateRevision,
                    builder: (context, _, _) {
                      final action = resolvePlayerPrimaryAudioAction(
                        playing: playing,
                        playbackRequested:
                            _streamPlaybackRequested || _startingPlayback,
                      );
                      final tooltip = switch (action) {
                        PlayerPrimaryAudioAction.play => context.tr(
                          '播放',
                          'Play',
                        ),
                        PlayerPrimaryAudioAction.pause => context.tr(
                          '暂停',
                          'Pause',
                        ),
                      };
                      return IconButton(
                        key: const ValueKey('player-sticky-mini-player-action'),
                        tooltip: tooltip,
                        icon: _buildPrimaryAudioGlyph(
                          action: action,
                          color: context.appTextPrimary,
                        ),
                        onPressed: () => unawaited(
                          _handlePrimaryAudioAction(handler, playing),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: design.spaceXs),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: StreamBuilder<Duration>(
                stream: handler.chapterPositionStream,
                initialData: handler.chapterPosition,
                builder: (context, positionSnapshot) {
                  final position = selectedLoaded
                      ? positionSnapshot.data ?? Duration.zero
                      : Duration.zero;
                  final progress = duration.inMilliseconds <= 0
                      ? 0.0
                      : (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                            .toDouble();
                  return LinearProgressIndicator(
                    key: const ValueKey('player-sticky-mini-player-progress'),
                    value: progress,
                    minHeight: 2,
                    backgroundColor: context.appTextPrimary.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArtwork(double size, {required double borderRadius}) {
    final compactArtwork = size <= 96;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('player-artwork'),
      tween: Tween<double>(end: size),
      duration: _playerTransitionDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, animatedSize, child) {
        final scale = size <= 0 ? 1.0 : animatedSize / size;
        return SizedBox.square(
          dimension: size,
          child: Transform.scale(
            alignment: Alignment.topCenter,
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.46),
                    blurRadius: compactArtwork ? 16 : 32,
                    spreadRadius: compactArtwork ? 0 : 2,
                    offset: Offset(0, compactArtwork ? 6 : 16),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: _isPodcast
          ? PodcastArtwork(
              imageUrl:
                  _podcastEpisode?.imageUrl ?? widget.podcast?.show.imageUrl,
              size: size,
              borderRadius: borderRadius,
            )
          : BookCover(
              coverPath: widget.book.coverPath,
              iconSize: size * 0.32,
              borderRadius: borderRadius,
            ),
    );
  }

  Widget _buildChapterMetadata(String chapterTitle) {
    final design = context.appDesign;
    return Row(
      key: const ValueKey('player-chapter-metadata'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapterTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
              SizedBox(height: design.spaceXs),
              Text(
                widget.book.author ?? context.tr('未知作者', 'Unknown Author'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: design.spaceMd),
        IconButton(
          tooltip: context.tr('收藏', 'Save'),
          icon: const Icon(Icons.favorite_border_rounded),
          color: context.appTextPrimary,
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSyncedLyrics({
    required String chapterId,
    required LuminaAudioHandler handler,
    required ChapterManifest? manifest,
    required bool playbackEnabled,
    required bool expanded,
    required bool focusMode,
    required Key listKey,
  }) {
    if (_isPodcast) {
      final data = widget.podcast!;
      final episode = _podcastEpisode ?? data.episode;
      final transcript = _podcastTranscript;
      final paragraphs = transcript?.paragraphs ?? const <drift_db.Paragraph>[];
      final currentProgress = _transcriptionProgress;
      if (paragraphs.isEmpty) {
        final failed = episode.transcriptStatus == 'failed';
        final paused = _transcriptPaused(episode);
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _transcribingPodcast
                      ? Icons.graphic_eq_rounded
                      : Icons.subtitles_outlined,
                  color: context.appTextSecondary,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  _transcribingPodcast
                      ? currentProgress?.message ??
                            context.tr('正在本地转写', 'Transcribing locally')
                      : paused
                      ? context.tr('转写已暂停', 'Transcription paused')
                      : failed
                      ? context.tr('上次转写未完成', 'Last transcription stopped')
                      : context.tr('这个单集还没有字幕', 'No transcript yet'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_transcribingPodcast) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: currentProgress?.progress),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('podcast-transcript-pause-inline'),
                    onPressed: _pausingPodcastTranscription
                        ? null
                        : _pausePodcastTranscription,
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: Text(
                      _pausingPodcastTranscription
                          ? context.tr('正在暂停…', 'Pausing…')
                          : context.tr('暂停', 'Pause'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _startPodcastTranscription,
                    icon: Icon(
                      paused
                          ? Icons.play_arrow_rounded
                          : Icons.auto_awesome_rounded,
                      size: 18,
                    ),
                    label: Text(
                      paused
                          ? context.tr('继续转写', 'Resume transcription')
                          : context.tr(
                              '使用本地 Whisper 转写',
                              'Transcribe on device',
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      final lyrics = SyncedLyricsList(
        key: listKey,
        paragraphs: paragraphs,
        manifest: manifest,
        handler: handler,
        playbackEnabled: playbackEnabled,
        expanded: expanded,
        focusMode: focusMode,
        bookTitle: data.show.title,
        chapterTitle: episode.title,
        bookId: widget.book.id,
        chapterId: episode.id,
        virtualized: true,
        scrollSpeed: _readingScrollSpeed,
        sweepEnabled: _lyricSweepEnabled,
      );
      // The progress row appears and disappears around the same list, so the
      // list has to keep its place in the tree. Swapping between a bare list
      // and a wrapped one would drop its state twice per transcription.
      return Column(
        children: [
          if (!_transcribingPodcast)
            const SizedBox.shrink()
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: currentProgress?.progress,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr(
                      '已缓存 ${transcript?.timingCount ?? 0} 段',
                      '${transcript?.timingCount ?? 0} cached',
                    ),
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: lyrics),
        ],
      );
    }

    final db = ref.watch(appDatabaseProvider);
    return FutureBuilder<List<drift_db.Paragraph>>(
      future: db.getParagraphs(chapterId),
      builder: (context, snapshot) {
        final paragraphs = snapshot.data ?? const <drift_db.Paragraph>[];
        if (paragraphs.isEmpty) {
          return Center(
            child: Text(
              context.tr('无正文', 'No text'),
              style: TextStyle(color: context.appTextSecondary),
            ),
          );
        }
        return SyncedLyricsList(
          key: listKey,
          paragraphs: paragraphs,
          manifest: manifest,
          handler: handler,
          playbackEnabled: playbackEnabled,
          expanded: expanded,
          focusMode: focusMode,
          bookTitle: widget.book.title,
          chapterTitle: widget.initialChapter?.title,
          bookId: widget.book.id,
          chapterId: chapterId,
          virtualized: true,
          scrollSpeed: _readingScrollSpeed,
          sweepEnabled: _lyricSweepEnabled,
        );
      },
    );
  }

  Widget _buildReactiveControls({
    required LuminaAudioHandler handler,
    required Duration fallbackDuration,
    required ChapterManifest? manifest,
    required Color foregroundColor,
  }) {
    return StreamBuilder(
      stream: handler.playbackState,
      initialData: handler.playbackState.value,
      builder: (context, playbackSnapshot) {
        final selectedLoaded = _isSelectedChapterLoaded(handler);
        final playing =
            selectedLoaded && (playbackSnapshot.data?.playing ?? false);
        final duration = selectedLoaded
            ? handler.chapterDuration
            : fallbackDuration;
        return StreamBuilder<Duration>(
          stream: handler.chapterPositionStream,
          initialData: handler.chapterPosition,
          builder: (context, positionSnapshot) {
            return ValueListenableBuilder<int>(
              valueListenable: _controlStateRevision,
              builder: (context, _, _) => _buildControls(
                handler,
                playing,
                selectedLoaded
                    ? positionSnapshot.data ?? Duration.zero
                    : Duration.zero,
                duration,
                manifest: manifest,
                selectedLoaded: selectedLoaded,
                foregroundColor: foregroundColor,
              ),
            );
          },
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
    final design = context.appDesign;
    final accent = Theme.of(context).colorScheme.primary;
    final controlColor = foregroundColor;
    final cacheColor = context.appTextSecondary.withValues(alpha: 0.46);
    final secondaryColor = context.appTextSecondary;
    final inactiveTrackColor = foregroundColor.withValues(alpha: 0.18);
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
    final remaining = duration - position;
    final remainingLabel = duration.inMilliseconds <= 0
        ? _fmt(duration)
        : '-${_fmt(remaining.isNegative ? Duration.zero : remaining)}';
    final speedIsCustomized = (_speed - 1).abs() > 0.01;

    return Column(
      key: const ValueKey('player-playback-controls'),
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
                inactiveTrackColor: inactiveTrackColor,
                thumbColor: controlColor,
                disabledActiveTrackColor: controlColor,
                disabledSecondaryActiveTrackColor: cacheColor,
                disabledInactiveTrackColor: inactiveTrackColor,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: secondaryColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              remainingLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: secondaryColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SizedBox(height: design.spaceSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: context.tr('播放倍速', 'Playback speed'),
              icon: Text(
                '${_speed.toStringAsFixed(1)}x',
                style: TextStyle(
                  color: speedIsCustomized ? accent : secondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              color: speedIsCustomized ? accent : secondaryColor,
              onPressed: _showSpeedSheet,
            ),
            IconButton(
              tooltip: _isPodcast
                  ? context.tr('后退 15 秒', 'Back 15 seconds')
                  : context.tr('上一段', 'Previous'),
              icon: Icon(
                _isPodcast
                    ? Icons.replay_10_rounded
                    : Icons.skip_previous_rounded,
                size: 36,
              ),
              color: foregroundColor,
              disabledColor: secondaryColor.withValues(alpha: 0.42),
              onPressed: !selectedLoaded
                  ? null
                  : _isPodcast
                  ? () => handler.seek(
                      handler.position - const Duration(seconds: 15),
                    )
                  : handler.skipToPrevious,
            ),
            Tooltip(
              message: primaryTooltip,
              child: Semantics(
                button: true,
                label: primaryTooltip,
                child: Material(
                  color: context.appTextPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('player-primary-audio-action'),
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        unawaited(_handlePrimaryAudioAction(handler, playing)),
                    child: SizedBox.square(
                      dimension: design.spaceXxl * 2,
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
                            color: context.appBackground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: _isPodcast
                  ? context.tr('前进 30 秒', 'Forward 30 seconds')
                  : context.tr('下一段', 'Next'),
              icon: Icon(
                _isPodcast ? Icons.forward_30_rounded : Icons.skip_next_rounded,
                size: 36,
              ),
              color: foregroundColor,
              disabledColor: secondaryColor.withValues(alpha: 0.42),
              onPressed: !selectedLoaded
                  ? null
                  : _isPodcast
                  ? () => handler.seek(
                      handler.position + const Duration(seconds: 30),
                    )
                  : handler.skipToNext,
            ),
            StreamBuilder<SleepTimerState>(
              stream: ref.watch(sleepTimerServiceProvider).stream,
              initialData: ref.watch(sleepTimerServiceProvider).state,
              builder: (context, timerSnapshot) {
                final timerState =
                    timerSnapshot.data ?? const SleepTimerState.off();
                return IconButton(
                  tooltip: timerState.active
                      ? context.tr(
                          '定时关闭：${_sleepTimerLabel(timerState)}',
                          'Sleep timer: ${_sleepTimerLabel(timerState)}',
                        )
                      : context.tr('定时关闭', 'Sleep timer'),
                  icon: Icon(
                    timerState.active
                        ? Icons.timer_rounded
                        : Icons.timer_outlined,
                  ),
                  color: timerState.active ? accent : secondaryColor,
                  onPressed: () => _showSleepTimerSheet(handler),
                );
              },
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
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          final accent = Theme.of(context).colorScheme.primary;
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
                      for (final value in const [0.8, 1.0, 1.2, 1.5, 2.0, 2.5])
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
      ),
    );
  }

  String _sleepTimerLabel(SleepTimerState state) {
    return switch (state.mode) {
      SleepTimerMode.off => context.tr('关闭', 'Off'),
      SleepTimerMode.duration => context.tr(
        '${state.duration!.inMinutes} 分钟后',
        'In ${state.duration!.inMinutes} minutes',
      ),
      SleepTimerMode.chapterEnd => context.tr('本章结束', 'End of chapter'),
    };
  }

  void _showSleepTimerSheet(LuminaAudioHandler handler) {
    final timerService = ref.read(sleepTimerServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.appSurface,
      builder: (sheetContext) => Builder(
        builder: (context) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.appDesign.spaceXl,
              context.appDesign.spaceSm,
              context.appDesign.spaceXl,
              context.appDesign.spaceXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('定时关闭', 'Sleep timer'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
                SizedBox(height: context.appDesign.spaceXs),
                Text(
                  context.tr(
                    '当前：${_sleepTimerLabel(timerService.state)}',
                    'Current: ${_sleepTimerLabel(timerService.state)}',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                SizedBox(height: context.appDesign.spaceLg),
                Wrap(
                  spacing: context.appDesign.spaceSm,
                  runSpacing: context.appDesign.spaceSm,
                  children: [
                    for (final minutes in const [15, 30, 45, 60])
                      ActionChip(
                        label: Text(
                          context.tr('$minutes 分钟', '$minutes minutes'),
                        ),
                        onPressed: () async {
                          await timerService.scheduleDuration(
                            Duration(minutes: minutes),
                            handler,
                          );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                    ActionChip(
                      label: Text(context.tr('本章结束', 'End of chapter')),
                      onPressed: () async {
                        await timerService.scheduleChapterEnd(handler);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                    if (timerService.state.active)
                      ActionChip(
                        label: Text(context.tr('关闭定时', 'Turn off')),
                        onPressed: () async {
                          await timerService.cancel();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
          podcast: widget.podcast,
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
  final PodcastPlayerData? podcast;

  const _FullScreenLyricsSheet({
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterId,
    required this.coverPath,
    required this.manifest,
    required this.playbackEnabled,
    required this.podcast,
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
    final readingScrollSpeed = ref
        .watch(appPreferencesProvider)
        .readingScrollSpeed;
    final lyricSweepEnabled = ref
        .watch(appPreferencesProvider)
        .lyricSweepEnabled;
    Widget buildLyrics(
      List<drift_db.Paragraph> paragraphs,
      ChapterManifest? manifest,
    ) {
      if (paragraphs.isEmpty) {
        return Center(
          child: Text(
            widget.podcast == null
                ? context.tr('无正文', 'No text')
                : context.tr('字幕尚未缓存', 'No cached transcript yet'),
            style: const TextStyle(color: AppColors.lyricsTextSecondary),
          ),
        );
      }
      return handlerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            context.tr('播放器不可用：$error', 'Player unavailable: $error'),
            style: const TextStyle(color: AppColors.lyricsTextSecondary),
          ),
        ),
        data: (handler) => SyncedLyricsList(
          key: ValueKey(
            '${widget.chapterId}:${handler.currentChapterId ?? handler.currentPodcastEpisodeId}',
          ),
          paragraphs: paragraphs,
          manifest: manifest,
          handler: handler,
          playbackEnabled: widget.playbackEnabled,
          expanded: true,
          bookId: widget.bookId,
          bookTitle: widget.bookTitle,
          chapterTitle: widget.chapterTitle,
          virtualized: true,
          scrollSpeed: readingScrollSpeed,
          sweepEnabled: lyricSweepEnabled,
        ),
      );
    }

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
                      child: widget.podcast == null
                          ? FutureBuilder<List<drift_db.Paragraph>>(
                              future: db.getParagraphs(widget.chapterId),
                              builder: (context, snapshot) => buildLyrics(
                                snapshot.data ?? const <drift_db.Paragraph>[],
                                widget.manifest,
                              ),
                            )
                          : StreamBuilder<drift_db.PodcastEpisode?>(
                              stream: db
                                  .watchPodcastEpisode(
                                    widget.podcast!.episode.id,
                                  )
                                  .distinct(
                                    (previous, next) =>
                                        !podcastEpisodeRequiresPlayerRefresh(
                                          previous,
                                          next,
                                        ),
                                  ),
                              initialData: widget.podcast!.episode,
                              builder: (context, snapshot) {
                                final episode =
                                    snapshot.data ?? widget.podcast!.episode;
                                final transcript =
                                    _buildPodcastTranscriptContent(
                                      widget.podcast!,
                                      episode,
                                    );
                                return buildLyrics(
                                  transcript.paragraphs,
                                  transcript.manifest,
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

class _WhisperModelSetupSheet extends StatefulWidget {
  final PodcastTranscriptionService service;
  final int expectedBytes;

  const _WhisperModelSetupSheet({
    required this.service,
    required this.expectedBytes,
  });

  @override
  State<_WhisperModelSetupSheet> createState() =>
      _WhisperModelSetupSheetState();
}

class _WhisperModelSetupSheetState extends State<_WhisperModelSetupSheet> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await widget.service.installModel(
        onProgress: (progress, _) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    final sizeMb = (widget.expectedBytes / (1024 * 1024)).round();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          design.spaceXl,
          design.spaceSm,
          design.spaceXl,
          design.spaceXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.subtitles_rounded),
                ),
                SizedBox(width: design.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('下载本地字幕模型', 'Download transcript model'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: design.spaceXs),
                      Text(
                        context.tr(
                          'Whisper Base · 约 $sizeMb MB',
                          'Whisper Base · about $sizeMb MB',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: design.spaceLg),
            Text(
              context.tr(
                '下载后，Podcast 音频和字幕将在这台设备上处理，不会发送到第三方转写服务。',
                'After download, podcast audio and transcripts are processed on this device and are not sent to a third-party transcription service.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
            if (_downloading) ...[
              SizedBox(height: design.spaceLg),
              Text(
                context.tr('正在下载 Whisper Base', 'Downloading Whisper Base'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: design.spaceSm),
              LinearProgressIndicator(value: _progress),
              if (_progress != null) ...[
                SizedBox(height: design.spaceXs),
                Text(
                  '${(_progress! * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            if (_error != null) ...[
              SizedBox(height: design.spaceLg),
              Text(
                context.tr(
                  '下载失败，请检查网络后重试。\n$_error',
                  'Download failed. Check your connection and try again.\n$_error',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            SizedBox(height: design.spaceXl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('download-whisper-and-transcribe'),
                onPressed: _downloading ? null : _download,
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  context.tr('下载并生成字幕', 'Download and create transcript'),
                ),
              ),
            ),
            SizedBox(height: design.spaceSm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _downloading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(context.tr('暂不', 'Not now')),
              ),
            ),
          ],
        ),
      ),
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
