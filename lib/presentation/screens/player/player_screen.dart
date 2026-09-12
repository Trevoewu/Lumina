import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:async';
import '../../../core/appearance.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart' show showCupertinoSheet;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../widgets/app_sheet.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/design_system/macos_window_toolbar.dart';
import '../../widgets/design_system/macos_toolbar_providers.dart';
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
import '../../../domain/models/book_rights.dart';
import '../../../domain/models/chapter_manifest.dart';
import '../../../services/app_log_service.dart';
import '../../../services/audiobook_manifest_validator.dart';
import '../../../services/audiobook_transcription_storage.dart';
import '../../../services/book_playback_queue.dart';
import '../../../services/generation_orchestrator.dart';
import '../../../services/generation_task_store.dart';
import '../../../services/lumina_audio_handler.dart';
import '../../../services/podcast_transcription_service.dart';
import '../../../services/sleep_timer_service.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/ai_summary_panel.dart';
import '../../widgets/app_glass_controls.dart';
import '../../widgets/app_control_buttons.dart';
import '../../widgets/airplay_route_picker_button.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/podcast_artwork.dart';
import '../../widgets/podcast_link_text.dart';
import '../../widgets/synced_lyrics_list.dart';
import '../../widgets/transcript_slider_track.dart';
import '../reader/book_reader_screen.dart';
import '../settings/dictionary_explanation_service_screen.dart';
import '../settings/tts_service_screen.dart';

enum PlayerPrimaryAudioAction { play, pause, loading }

/// [buffering] covers the gap the player used to hide: a stream that has been
/// asked to play but has no audio yet. just_audio reports `playing` the moment
/// play() is called, so without it a tap on an uncached episode flipped the
/// button to "pause" and then sat silent with nothing on screen to explain it.
PlayerPrimaryAudioAction resolvePlayerPrimaryAudioAction({
  required bool playing,
  required bool playbackRequested,
  bool buffering = false,
}) {
  if (playing) {
    return buffering
        ? PlayerPrimaryAudioAction.loading
        : PlayerPrimaryAudioAction.pause;
  }
  if (playbackRequested) return PlayerPrimaryAudioAction.loading;
  return PlayerPrimaryAudioAction.play;
}

({bool playing, bool buffering}) _transportState(PlaybackState state) => (
  playing: state.playing,
  buffering:
      state.processingState == AudioProcessingState.loading ||
      state.processingState == AudioProcessingState.buffering,
);

/// The slice of the feed handed to the player around [selectedId], or an empty
/// list when the episode is not in it.
///
/// A subscribed show holds hundreds of episodes and every one of them costs a
/// platform audio source, so queueing the whole feed is most of the delay
/// between the play button and the first sound. Auto-advance only ever reaches
/// the next few, and picking anything further away rebuilds the queue anyway.
List<drift_db.PodcastEpisode> podcastPlaybackQueueWindow(
  List<drift_db.PodcastEpisode> episodes,
  String selectedId, {
  int behind = 2,
  int ahead = 20,
}) {
  final index = episodes.indexWhere((episode) => episode.id == selectedId);
  if (index < 0) return const [];
  return episodes.sublist(
    math.max(0, index - behind),
    math.min(episodes.length, index + ahead + 1),
  );
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

/// One row of the "up next" sheet, so the same sheet serves a podcast's
/// episodes and a book's chapters.
class _PlaylistEntry {
  final String title;
  final String subtitle;
  final Widget leading;
  final Future<void> Function() onTap;

  const _PlaylistEntry({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
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
          beforeTiming.pauseBefore != afterTiming.pauseBefore ||
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

final _transcriptCjkPattern = RegExp(
  '[\u3000-\u9fff\uff00-\uffef]',
  unicode: true,
);

/// Text determines display blocks; timing markers only drive playback sync.
/// Sentence and clause parsing is shared with the existing reading renderer.
/// Deliberately ignore pauses, chunk boundaries and elapsed audio duration.
String joinPodcastTranscriptLines(
  List<AudioTextTiming> timings, {
  int? maxMergedChars,
}) {
  assert(maxMergedChars == null || maxMergedChars > 0);
  final buffer = StringBuffer();
  var previous = '';
  for (final timing in timings) {
    final part = timing.text.trim();
    if (part.isEmpty) continue;
    if (previous.isNotEmpty) {
      buffer.write(_transcriptJoinSeparator(previous, part));
    }
    buffer.write(part);
    previous = part;
  }
  final text = buffer.toString();
  return splitLyricsText(
    text.replaceAll(RegExp(r'\s+'), ' '),
    maxChars:
        maxMergedChars ?? (_transcriptCjkPattern.hasMatch(text) ? 36 : 100),
  ).join('\n');
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
            // audible pauses and sentence endings keep one. The episode
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
  late final ScrollController _playerScrollController;

  /// The transcript page owns a separate controller because it is pushed over
  /// the cover route, and one controller cannot be attached to both scroll
  /// views while the Hero transition is in flight.
  final ValueNotifier<bool> _pageScrollActive = ValueNotifier(false);
  bool? _pendingPageScrollActive;
  bool _pageScrollUpdateScheduled = false;
  double _speed = 1.0;
  ChapterManifest? _selectedManifest;
  GenerationProgress? _generationProgress;
  StreamSubscription<GenerationProgress>? _generationSubscription;
  Future<void> _generationUpdate = Future.value();
  bool _preparingStream = false;
  bool _streamPlaybackRequested = false;
  bool _startingPlayback = false;
  double? _progressDragValue;
  int _progressDragSequence = 0;
  final ValueNotifier<int> _controlStateRevision = ValueNotifier<int>(0);
  int _paragraphCount = 0;
  List<drift_db.Paragraph> _audiobookParagraphs = const [];
  Future<List<drift_db.Paragraph>>? _audiobookParagraphsFuture;
  drift_db.ChapterPlaybackProgress? _chapterPlaybackProgress;
  drift_db.PodcastEpisode? _podcastEpisode;
  bool _selectedPodcastLocalAudioAvailable = false;
  _PodcastTranscriptContent? _podcastTranscript;
  StreamSubscription<drift_db.PodcastEpisode?>? _podcastEpisodeSubscription;
  StreamSubscription<PodcastTranscriptionProgress>? _transcriptionSubscription;
  StreamSubscription<String?>? _playbackParagraphSubscription;

  /// Last episode the handler reported, used to tell an auto-advance apart
  /// from a queue load that is still catching up with the current selection.
  String? _followedPodcastEpisodeId;
  StreamSubscription? _audiobookMediaItemSubscription;
  bool _transcribingPodcast = false;
  bool _pausingPodcastTranscription = false;
  PodcastTranscriptionProgress? _transcriptionProgress;
  bool _autoplayHandled = false;
  double _readingScrollSpeed = 1.0;
  bool _lyricSweepEnabled = true;
  bool _transcriptPageActive = false;
  bool _landscapeTranscriptActive = true;
  drift_db.Chapter? _activeAudiobookChapter;
  int _audiobookSelectionRevision = 0;

  bool get _isPodcast => widget.podcast != null;
  bool get _isRecordedBook => widget.book.externalSource == librivoxSourceId;
  AudiobookTranscriptionStorage? _bookAsrStorage;
  drift_db.PodcastEpisode? _bookAsrState;
  StreamSubscription? _bookAsrSubscription;
  StreamSubscription? _bookAsrProgressSubscription;
  bool _bookAsrStarting = false;
  bool _bookAsrPausing = false;
  int _bookAsrRefreshRevision = 0;

  bool get _bookAsrRunning =>
      _bookAsrStarting ||
      (_selectedAudiobookChapter != null &&
          ref.read(podcastTranscriptionServiceProvider).activeEpisodeId ==
              _selectedAudiobookChapter?.id);
  drift_db.Chapter? get _selectedAudiobookChapter =>
      _activeAudiobookChapter ?? widget.initialChapter;

  AppToolbarStateNotifier<String?>? _macosTitleNotifier;
  AppToolbarStateNotifier<Widget?>? _macosTrailingNotifier;
  AppToolbarStateNotifier<Widget?>? _macosMiddleNotifier;
  AppToolbarStateNotifier<bool>? _miniPlayerSuppressedNotifier;

  @override
  void initState() {
    super.initState();
    _macosTitleNotifier = ref.read(macosToolbarTitleProvider.notifier);
    _macosTrailingNotifier = ref.read(macosToolbarTrailingProvider.notifier);
    _macosMiddleNotifier = ref.read(macosToolbarMiddleProvider.notifier);
    _miniPlayerSuppressedNotifier = ref.read(
      miniPlayerSuppressedProvider.notifier,
    );
    _playerScrollController = ScrollController(
      onAttach: _handlePageScrollPositionAttached,
      onDetach: _handlePageScrollPositionDetached,
    );
    _podcastEpisode = widget.podcast?.episode;
    _activeAudiobookChapter = widget.initialChapter;
    if (_isPodcast) {
      final transcript = _buildPodcastTranscriptContent(
        widget.podcast!,
        _podcastEpisode!,
      );
      _podcastTranscript = transcript;
      _selectedManifest = transcript.manifest;
      _paragraphCount = transcript.paragraphs.length;
      unawaited(_refreshPodcastLocalAudioAvailability());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _macosMiddleNotifier?.updateValue(null);
      _miniPlayerSuppressedNotifier?.updateValue(true);
      unawaited(_loadPlaybackSpeed());
      if (_isPodcast) {
        ref.read(generationOrchestratorProvider).pausePlaybackGenerations();
        _watchPodcastEpisode();
        _watchTranscriptionProgress();
        unawaited(_watchPodcastPlaybackSelection());
        unawaited(_resumeInterruptedPodcastTranscription());
        unawaited(_autoplayIfRequested());
      } else {
        unawaited(_loadSelectedChapterState());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_bookAsrSubscription?.cancel());
    unawaited(_bookAsrProgressSubscription?.cancel());
    unawaited(_generationSubscription?.cancel());
    unawaited(_podcastEpisodeSubscription?.cancel());
    unawaited(_transcriptionSubscription?.cancel());
    unawaited(_playbackParagraphSubscription?.cancel());
    unawaited(_audiobookMediaItemSubscription?.cancel());
    _playerScrollController.dispose();
    _pageScrollActive.dispose();
    _controlStateRevision.dispose();
    Future.microtask(() {
      _macosMiddleNotifier?.updateValue(null);
      _macosTitleNotifier?.updateValue(null);
      _macosTrailingNotifier?.updateValue(null);
      _miniPlayerSuppressedNotifier?.updateValue(false);
    });
    super.dispose();
  }

  void _handlePageScrollPositionAttached(ScrollPosition position) {
    position.isScrollingNotifier.addListener(_handlePageScrollingChanged);
  }

  void _handlePageScrollPositionDetached(ScrollPosition position) {
    position.isScrollingNotifier.removeListener(_handlePageScrollingChanged);
    _handlePageScrollingChanged();
  }

  void _handlePageScrollingChanged() {
    final scrolling = [
      ..._playerScrollController.positions,
    ].any((position) => position.isScrollingNotifier.value);
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      if (_pageScrollActive.value != scrolling) {
        _pageScrollActive.value = scrolling;
      }
      return;
    }
    _pendingPageScrollActive = scrolling;
    if (_pageScrollUpdateScheduled) return;
    _pageScrollUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageScrollUpdateScheduled = false;
      if (!mounted) return;
      final pending = _pendingPageScrollActive;
      _pendingPageScrollActive = null;
      if (pending != null && _pageScrollActive.value != pending) {
        _pageScrollActive.value = pending;
      }
    });
  }

  Future<void> _openTranscriptPage({
    required LuminaAudioHandler handler,
    required String? chapterId,
    required String chapterTitle,
  }) async {
    if (!mounted || (!_isPodcast && chapterId == null)) return;
    setState(() => _transcriptPageActive = !_transcriptPageActive);
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
    final episodeId = (_podcastEpisode ?? data.episode).id;
    unawaited(_podcastEpisodeSubscription?.cancel());
    _podcastEpisodeSubscription = ref
        .read(appDatabaseProvider)
        .watchPodcastEpisode(episodeId)
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
          unawaited(_refreshPodcastLocalAudioAvailability());
          _refreshTranscriptPage();
        });
  }

  Future<void> _loadSelectedChapterState() async {
    final chapter = _selectedAudiobookChapter;
    if (chapter == null) return;
    final selectionRevision = _audiobookSelectionRevision;

    final database = ref.read(appDatabaseProvider);
    ref
        .read(generationOrchestratorProvider)
        .activatePlaybackChapter(bookId: widget.book.id, chapterId: chapter.id);
    final manifestStore = ref.read(manifestStoreProvider);
    final paragraphsFuture = _audiobookParagraphsFuture ??= database
        .getParagraphs(chapter.id);
    final results = await Future.wait<Object?>([
      manifestStore.load(widget.book.id, chapter.id),
      paragraphsFuture,
      database.getChapterPlaybackProgress(chapter.id),
    ]);
    if (!mounted ||
        selectionRevision != _audiobookSelectionRevision ||
        _selectedAudiobookChapter?.id != chapter.id) {
      return;
    }
    final storedManifest = results[0] as ChapterManifest?;
    final paragraphs = results[1] as List<drift_db.Paragraph>;
    final manifest = storedManifest == null
        ? null
        : validateAudiobookManifest(storedManifest, paragraphs);
    final playbackProgress = results[2] as drift_db.ChapterPlaybackProgress?;
    setState(() {
      _selectedManifest = manifest;
      _paragraphCount = paragraphs.length;
      _audiobookParagraphs = paragraphs;
      _chapterPlaybackProgress = playbackProgress;
    });
    _refreshTranscriptPage();

    if (_isRecordedBook) {
      _watchBookTranscription(chapter);
      await _autoplayIfRequested();
      return;
    }
    final activeGeneration = ref
        .read(generationOrchestratorProvider)
        .watchChapterGeneration(bookId: widget.book.id, chapterId: chapter.id);
    if (activeGeneration != null) {
      _listenToGeneration(activeGeneration);
    }
    unawaited(_resumeInterruptedAudiobookGeneration());
    unawaited(_watchPlaybackGenerationPriority());
    await _autoplayIfRequested();
  }

  Future<void> _selectAudiobookChapter(
    LuminaAudioHandler handler,
    drift_db.Chapter chapter,
  ) async {
    if (_isPodcast) return;
    final alreadySelected = _selectedAudiobookChapter?.id == chapter.id;
    final queueIndex = handler.queue.value.indexWhere(
      (item) => item.extras?['chapterId'] == chapter.id,
    );
    if (alreadySelected && queueIndex >= 0) {
      await handler.skipToQueueItem(queueIndex);
      await handler.play();
      return;
    }

    _audiobookSelectionRevision++;
    await _generationSubscription?.cancel();
    _generationSubscription = null;
    _audiobookParagraphsFuture = null;
    _setStreamPlaybackRequested(false);
    _setStartingPlayback(false);
    if (!mounted) return;
    setState(() {
      _activeAudiobookChapter = chapter;
      _selectedManifest = null;
      _generationProgress = null;
      _paragraphCount = 0;
      _audiobookParagraphs = const [];
      _chapterPlaybackProgress = null;
    });
    _refreshTranscriptPage();

    try {
      await _loadSelectedChapterState();
      if (!mounted || _selectedAudiobookChapter?.id != chapter.id) return;
      final refreshedQueueIndex = handler.queue.value.indexWhere(
        (item) => item.extras?['chapterId'] == chapter.id,
      );
      if (refreshedQueueIndex >= 0) {
        await handler.skipToQueueItem(refreshedQueueIndex);
        await handler.play();
      } else {
        await _handlePrimaryAudioAction(handler, false);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Playback',
        '播放列表切换章节失败 chapter=${chapter.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar(
          context.tr(
            '无法切换到该章节：$error',
            'Unable to play chapter: $error',
            '章を再生できません：$error',
          ),
        );
      }
    }
  }

  Future<void> _resumeInterruptedAudiobookGeneration() async {
    final chapter = _selectedAudiobookChapter;
    if (chapter == null) return;
    final task = await ref
        .read(appDatabaseProvider)
        .getLatestGenerationTask(
          kind: GenerationTaskKind.tts.name,
          parentId: widget.book.id,
          scopeId: chapter.id,
        );
    if (!mounted ||
        task == null ||
        task.status == GenerationChunkStatus.complete.name ||
        _generationSubscription != null) {
      return;
    }
    final manifest = _selectedManifest;
    final savedParagraphIndex =
        _chapterPlaybackProgress?.paragraphIndex ??
        (widget.book.currentChapterId == chapter.id
            ? widget.book.currentParagraphIndex
            : null);
    await _ensureChapterCachingStarted(
      priorityParagraphIndex: manifest == null || manifest.segments.isEmpty
          ? savedParagraphIndex
          : savedParagraphIndex?.clamp(0, manifest.segments.length - 1).toInt(),
      recoveryTask: task,
      silent: true,
    );
  }

  Future<void> _watchPlaybackGenerationPriority() async {
    if (_isPodcast) return;
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    if (!mounted || _isPodcast) return;
    await _audiobookMediaItemSubscription?.cancel();
    _audiobookMediaItemSubscription = handler.mediaItem.listen((item) {
      final extras = item?.extras;
      if (extras?['bookId'] != widget.book.id) return;
      final chapterId = extras?['chapterId'] as String?;
      if (chapterId == null || chapterId == _selectedAudiobookChapter?.id) {
        return;
      }
      unawaited(_bindAudiobookChapterFromPlayback(chapterId));
    });
    await _playbackParagraphSubscription?.cancel();
    _playbackParagraphSubscription = handler.currentParagraphIdStream.listen((
      paragraphId,
    ) {
      if (paragraphId == null) return;
      final chapter = _selectedAudiobookChapter;
      final currentBookId = handler.currentBookId;
      final currentChapterId = handler.currentChapterId;
      if (chapter != null &&
          currentBookId != null &&
          currentChapterId != null &&
          currentChapterId != chapter.id) {
        ref
            .read(generationOrchestratorProvider)
            .activatePlaybackChapter(
              bookId: currentBookId,
              chapterId: currentChapterId,
            );
        return;
      }
      final index = _selectedManifest?.segments.indexWhere(
        (segment) => segment.paragraphId == paragraphId,
      );
      if (chapter == null || index == null || index < 0) return;
      ref
          .read(generationOrchestratorProvider)
          .prioritizeChapter(
            bookId: widget.book.id,
            chapterId: chapter.id,
            paragraphIndex: index,
            lookahead: 3,
          );
    });
  }

  Future<void> _bindAudiobookChapterFromPlayback(String chapterId) async {
    final chapter = await ref.read(appDatabaseProvider).getChapter(chapterId);
    if (!mounted ||
        chapter == null ||
        chapter.bookId != widget.book.id ||
        chapter.id == _selectedAudiobookChapter?.id) {
      return;
    }
    _audiobookSelectionRevision++;
    await _generationSubscription?.cancel();
    _generationSubscription = null;
    _audiobookParagraphsFuture = null;
    if (!mounted) return;
    setState(() {
      _activeAudiobookChapter = chapter;
      _selectedManifest = null;
      _generationProgress = null;
      _paragraphCount = 0;
      _audiobookParagraphs = const [];
      _chapterPlaybackProgress = null;
    });
    _refreshTranscriptPage();
    await _loadSelectedChapterState();
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
              'chapter=${_selectedAudiobookChapter?.id}',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted || !identical(_generationSubscription, subscription)) {
          return;
        }
        setState(() => _generationSubscription = null);
        _setStreamPlaybackRequested(false);
        _showSnackBar(
          context.tr(
            '音频缓存失败：$error',
            'Unable to cache audio: $error',
            '音声をキャッシュできません：$error',
          ),
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
    // Cancelling the stream subscription does not discard progress updates that
    // are already queued in `_generationUpdate`. They may run after this screen
    // has been disposed, when reading from `ref` is no longer safe.
    if (!mounted) return;
    final chapter = _selectedAudiobookChapter;
    if (chapter == null || progress.chapterId != chapter.id) return;
    final storedManifest = await ref
        .read(manifestStoreProvider)
        .load(widget.book.id, chapter.id);
    if (!mounted || _selectedAudiobookChapter?.id != chapter.id) return;
    final manifest = storedManifest == null
        ? null
        : validateAudiobookManifest(storedManifest, _audiobookParagraphs);
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
    // `onDone` is chained behind any pending progress update and can therefore
    // also start after the widget has been removed.
    if (!mounted) return;
    final chapter = _selectedAudiobookChapter;
    final storedManifest = chapter == null
        ? null
        : await ref
              .read(manifestStoreProvider)
              .load(widget.book.id, chapter.id);
    final manifest = storedManifest == null
        ? null
        : validateAudiobookManifest(storedManifest, _audiobookParagraphs);
    if (!mounted || !identical(_generationSubscription, subscription)) return;
    setState(() {
      _selectedManifest = manifest ?? _selectedManifest;
      _generationSubscription = null;
    });
    _setStreamPlaybackRequested(false);
  }

  Future<bool> _ensureChapterCachingStarted({
    int? priorityParagraphIndex,
    drift_db.GenerationTask? recoveryTask,
    bool silent = false,
  }) async {
    if (_isRecordedBook) return false;
    final chapter = _selectedAudiobookChapter;
    if (chapter == null) return false;
    if (_generationSubscription != null) {
      if (priorityParagraphIndex != null) {
        ref
            .read(generationOrchestratorProvider)
            .prioritizeChapter(
              bookId: widget.book.id,
              chapterId: chapter.id,
              paragraphIndex: priorityParagraphIndex,
              lookahead: 3,
            );
      }
      return true;
    }
    if (_preparingStream) return false;

    setState(() => _preparingStream = true);
    try {
      final recoveryConfig = recoveryTask == null
          ? const <String, dynamic>{}
          : ((jsonDecode(recoveryTask.configJson) as Map?)
                    ?.cast<String, dynamic>() ??
                const <String, dynamic>{});
      final recoveryProviderId = recoveryConfig['providerId'] as String?;
      TtsProvider provider =
          (recoveryProviderId == null
              ? null
              : ref.read(providerRegistryProvider).get(recoveryProviderId)) ??
          ref.read(activeTtsProviderProvider);
      var selections = ref.read(providerSelectionRepositoryProvider);
      var providerConnected = await provider.validate();
      var selectedModel = await selections.selectedTtsModel(provider.id);
      var selectedVoice = await selections.selectedVoice(provider.id);
      if (!providerConnected ||
          selectedModel == null ||
          selectedVoice == null) {
        if (silent) return false;
        final resumePlaybackRequest = _streamPlaybackRequested;
        _setStreamPlaybackRequested(false);
        if (!mounted ||
            !await _openTtsSetupPrompt(
              provider.displayName,
              setupIncomplete: providerConnected,
            )) {
          return false;
        }
        if (resumePlaybackRequest) _setStreamPlaybackRequested(true);
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
        chapterVoiceId: recoveryConfig['voiceId'] as String? ?? chapter.voiceId,
      );
      if (!mounted) return false;
      if (voice == null) {
        if (!silent) {
          _showSnackBar(
            context.tr(
              '${provider.displayName} 没有可用音色',
              '${provider.displayName} has no available voice',
              '${provider.displayName}に利用できる音声がありません',
            ),
          );
        }
        return false;
      }

      final stream = ref
          .read(generationOrchestratorProvider)
          .generateChapter(
            bookId: widget.book.id,
            chapterId: chapter.id,
            provider: provider,
            voice: voice,
            speed: (recoveryConfig['speed'] as num?)?.toDouble() ?? 1.0,
            priorityParagraphIndex: priorityParagraphIndex,
            prefetchCount: 3,
            intent: GenerationTaskIntent.playback,
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
      if (mounted && !silent) {
        _showSnackBar(
          context.tr(
            '无法开始缓存：$error',
            'Unable to start caching: $error',
            'キャッシュを開始できません：$error',
          ),
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
        icon: const AppIcon(AppIcons.cloud),
        title: Text(
          setupIncomplete
              ? context.tr('完成语音设置', 'Complete voice setup', '音声設定を完了')
              : context.tr('连接语音服务', 'Connect a voice provider', '音声サービスに接続'),
        ),
        content: Text(
          setupIncomplete
              ? context.tr(
                  '$providerName 已连接，但还需要选择语音模型和朗读音色。'
                      '完成后，Lumina 会自动继续生成当前章节。',
                  '$providerName is connected, but a voice model and reading voice still need to be selected. '
                      'Lumina will continue generating the current chapter after setup.',
                  '$providerNameは接続済みですが、音声モデルと読み上げ音声を選択してください。設定後、Luminaが現在の章の生成を続けます。',
                )
              : context.tr(
                  '当前的 $providerName 尚未连接。完成云端语音服务设置后，Lumina 会自动继续生成当前章节。',
                  '$providerName is not connected. Lumina will continue generating the current chapter after cloud voice setup.',
                  '$providerNameは接続されていません。クラウド音声サービスの設定後、Luminaが現在の章の生成を続けます。',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('暂不', 'Not now', '今はしない')),
          ),
          FilledButton(
            key: const ValueKey('open-tts-settings'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('去设置', 'Open settings', '設定を開く')),
          ),
        ],
      ),
    );
    if (openSettings != true || !mounted) return false;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TtsServiceScreen()));
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

  /// Identifies what the handler currently holds loaded.
  ///
  /// [_isSelectedChapterLoaded] reads the handler directly, and the handler
  /// exposes no stream for it, so every surface that branches on it has to
  /// rebuild when the loaded item changes. The Podcast key carries the audio
  /// URL because an episode whose download finished mid-playback keeps its id
  /// while its source swaps from the feed to the cached file.
  static String? _loadedMediaKey(MediaItem? item) {
    final extras = item?.extras;
    final podcastEpisodeId = extras?['podcastEpisodeId'] as String?;
    if (podcastEpisodeId != null) {
      return 'podcast:$podcastEpisodeId:${extras?['audioUrl']}';
    }
    final bookId = extras?['bookId'] as String?;
    final chapterId = extras?['chapterId'] as String?;
    return bookId == null || chapterId == null
        ? null
        : 'book:$bookId:$chapterId';
  }

  /// Rebuilds [builder] with a fresh `selectedLoaded` whenever the handler
  /// loads a different chapter or episode.
  Widget _buildOnLoadedMediaChange(
    LuminaAudioHandler handler,
    Widget Function(BuildContext context, bool selectedLoaded) builder,
  ) {
    return StreamBuilder<String?>(
      stream: handler.mediaItem.map(_loadedMediaKey).distinct(),
      initialData: _loadedMediaKey(handler.mediaItem.valueOrNull),
      builder: (context, _) =>
          builder(context, _isSelectedChapterLoaded(handler)),
    );
  }

  Duration _selectedDuration(
    LuminaAudioHandler handler, {
    required bool selectedLoaded,
    required ChapterManifest? manifest,
  }) {
    if (selectedLoaded) return handler.chapterDuration;
    return Duration(milliseconds: manifest?.totalDurationMs ?? 0);
  }

  bool _isSelectedChapterLoaded(LuminaAudioHandler handler) {
    if (_isPodcast) {
      if (handler.currentPodcastEpisodeId != _podcastEpisode?.id) {
        return false;
      }
      final localPath = _podcastEpisode?.localAudioPath;
      if (localPath == null ||
          localPath.isEmpty ||
          !_selectedPodcastLocalAudioAvailable) {
        return true;
      }
      // Transcription timestamps are generated from the cached file. A queue
      // that still points to the feed URL is not equivalent, especially for
      // feeds with redirects or dynamic ad insertion.
      return handler.mediaItem.valueOrNull?.extras?['audioUrl'] ==
          File(localPath).uri.toString();
    }
    final chapter = _selectedAudiobookChapter;
    if (chapter == null) return handler.currentBookId == widget.book.id;
    return handler.currentBookId == widget.book.id &&
        handler.currentChapterId == chapter.id;
  }

  Future<void> _refreshPodcastLocalAudioAvailability() async {
    final path = _podcastEpisode?.localAudioPath;
    final available =
        path != null && path.isNotEmpty && await File(path).exists();
    if (!mounted || path != _podcastEpisode?.localAudioPath) return;
    if (_selectedPodcastLocalAudioAvailable == available) return;
    setState(() => _selectedPodcastLocalAudioAvailable = available);
    _refreshTranscriptPage();
  }

  ChapterManifest? _effectiveManifest(LuminaAudioHandler handler) {
    if (_isPodcast) return _selectedManifest;
    return _selectedAudiobookChapter == null
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
    final playable = contiguousPlayableSegments(manifest);
    return ChapterManifest(
      chapterId: manifest.chapterId,
      bookId: manifest.bookId,
      providerId: manifest.providerId,
      voiceId: manifest.voiceId,
      speed: manifest.speed,
      configurationFingerprint: manifest.configurationFingerprint,
      segments: playable,
      updatedAt: manifest.updatedAt,
    );
  }

  Future<void> _handlePrimaryAudioAction(
    LuminaAudioHandler handler,
    bool playing,
  ) async {
    if (playing) {
      _setStreamPlaybackRequested(false);
      await handler.pause();
      return;
    }
    // A request is already preparing its first playable segment. Ignore
    // additional taps so they cannot start a second generation/cache flow.
    if (_streamPlaybackRequested || _startingPlayback || _preparingStream) {
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
            context.tr(
              'Podcast 播放失败：$error',
              'Unable to play podcast: $error',
              'ポッドキャストを再生できません：$error',
            ),
          );
        }
      } finally {
        if (mounted) _setStartingPlayback(false);
      }
      return;
    }

    final chapter = _selectedAudiobookChapter;
    if (chapter == null) {
      await handler.play();
      return;
    }

    _setStreamPlaybackRequested(true);
    final manifest = _selectedManifest;
    final savedParagraphIndex =
        _chapterPlaybackProgress?.paragraphIndex ??
        (widget.book.currentChapterId == chapter.id
            ? widget.book.currentParagraphIndex
            : null);
    final priorityParagraphIndex = manifest == null || manifest.segments.isEmpty
        ? savedParagraphIndex
        : savedParagraphIndex?.clamp(0, manifest.segments.length - 1).toInt();
    final hasPlayablePrefix =
        manifest != null && _playablePrefix(manifest).segments.isNotEmpty;
    var startedPlayback = false;
    if (hasPlayablePrefix) {
      startedPlayback = await _startPlayback(handler, manifest);
    }
    if (!mounted) return;

    final needsCaching = manifest == null || !manifest.isReady;
    var caching = _generationSubscription != null;
    if (needsCaching && !caching) {
      caching = await _ensureChapterCachingStarted(
        priorityParagraphIndex: priorityParagraphIndex,
      );
      if (!mounted) return;
    } else if (caching && priorityParagraphIndex != null) {
      ref
          .read(generationOrchestratorProvider)
          .prioritizeChapter(
            bookId: widget.book.id,
            chapterId: chapter.id,
            paragraphIndex: priorityParagraphIndex,
            lookahead: 3,
          );
    }
    if (!mounted) return;

    if (!needsCaching || (!caching && !startedPlayback)) {
      _setStreamPlaybackRequested(false);
    }
  }

  Future<void> _loadPodcastPlayback(
    LuminaAudioHandler handler, {
    drift_db.PodcastEpisode? episode,
  }) async {
    final data = widget.podcast;
    final selected = episode ?? _podcastEpisode;
    if (data == null || selected == null) return;

    final window = podcastPlaybackQueueWindow(data.episodes, selected.id);
    final episodes = window.isEmpty ? [selected] : window;
    // Only the window is re-read: an episode row carries its whole transcript,
    // and the queue needs nothing from it but a download path that may have
    // appeared since this screen opened.
    final database = ref.read(appDatabaseProvider);
    final fresh = await database.getPodcastEpisodesByIds([
      for (final episode in episodes) episode.id,
    ]);
    final queued = fresh.isEmpty ? episodes : fresh;
    final localAudioUris = await _resolveLocalAudioUris(queued);
    _selectedPodcastLocalAudioAvailable = localAudioUris.containsKey(
      selected.id,
    );

    await handler.loadPodcastQueue(
      episodes: [
        for (final episode in queued)
          PodcastPlaybackSource(
            episodeId: episode.id,
            showId: data.show.id,
            showTitle: data.show.title,
            title: episode.title,
            audioUrl: localAudioUris[episode.id] ?? episode.audioUrl,
            imageUrl: episode.imageUrl ?? data.show.imageUrl,
            durationMs: episode.durationMs,
          ),
      ],
      initialEpisodeId: selected.id,
      initialPosition: Duration(milliseconds: selected.playbackPositionMs),
    );
  }

  /// Maps episode ids to a file URI for the ones whose download is really on
  /// disk. Episodes that were never downloaded are not touched at all, so a
  /// feed nobody has downloaded costs no filesystem work.
  static Future<Map<String, String>> _resolveLocalAudioUris(
    List<drift_db.PodcastEpisode> episodes,
  ) async {
    final candidates = [
      for (final episode in episodes)
        if (episode.localAudioPath case final path?)
          if (path.isNotEmpty) (episode.id, File(path)),
    ];
    if (candidates.isEmpty) return const {};
    final present = await Future.wait([
      for (final (_, file) in candidates) file.exists(),
    ]);
    return {
      for (var index = 0; index < candidates.length; index++)
        if (present[index])
          candidates[index].$1: candidates[index].$2.uri.toString(),
    };
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

  Future<void> _watchPodcastPlaybackSelection() async {
    final data = widget.podcast;
    if (data == null) return;
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    if (!mounted || widget.podcast == null) return;
    await _playbackParagraphSubscription?.cancel();
    _followedPodcastEpisodeId ??= handler.currentPodcastEpisodeId;
    _playbackParagraphSubscription = handler.currentParagraphIdStream.listen((
      episodeId,
    ) async {
      final previousEpisodeId = _followedPodcastEpisodeId;
      _followedPodcastEpisodeId = episodeId;
      if (!mounted || episodeId == null || episodeId == _podcastEpisode?.id) {
        return;
      }
      // Broadcast events arrive a microtask late, so loading a queue for one
      // episode while the user is already looking at another one used to drag
      // the screen back to the episode that was playing before. Follow the
      // handler only when it is leaving the episode this screen is showing, or
      // when it had not reported an episode at all — anything else belongs to
      // playback this screen never claimed.
      if (previousEpisodeId != null &&
          previousEpisodeId != _podcastEpisode?.id) {
        return;
      }
      final episode = await ref
          .read(appDatabaseProvider)
          .getPodcastEpisode(episodeId);
      if (!mounted || episode == null || episode.showId != data.show.id) return;
      _bindPodcastEpisode(episode);
    });
  }

  void _bindPodcastEpisode(drift_db.PodcastEpisode episode) {
    final data = widget.podcast;
    if (data == null) return;
    final transcript = _buildPodcastTranscriptContent(data, episode);
    final service = ref.read(podcastTranscriptionServiceProvider);
    setState(() {
      _podcastEpisode = episode;
      _podcastTranscript = transcript;
      _selectedManifest = transcript.manifest;
      _paragraphCount = transcript.paragraphs.length;
      _selectedPodcastLocalAudioAvailable = false;
      _transcribingPodcast = service.activeEpisodeId == episode.id;
      _transcriptionProgress = null;
    });
    _watchPodcastEpisode();
    _watchTranscriptionProgress();
    unawaited(_refreshPodcastLocalAudioAvailability());
    unawaited(_resumeInterruptedPodcastTranscription());
    _refreshTranscriptPage();
  }

  Future<void> _resumeInterruptedPodcastTranscription() async {
    final selected = _podcastEpisode;
    final data = widget.podcast;
    if (selected == null || data == null) return;
    final database = ref.read(appDatabaseProvider);
    // The navigation argument can predate the final persisted ASR chunk.
    final episode = await database.getPodcastEpisode(selected.id) ?? selected;
    if (!mounted ||
        _podcastEpisode?.id != episode.id ||
        episode.transcriptStatus == 'complete') {
      return;
    }
    final task = await database.getLatestGenerationTask(
      kind: GenerationTaskKind.whisper.name,
      parentId: episode.showId,
      scopeId: episode.id,
    );
    final hasLegacyResume =
        episode.transcriptProgressMs > 0 &&
        (episode.transcriptStatus == podcastTranscriptPausedStatus ||
            episode.transcriptStatus == 'failed' ||
            episode.transcriptStatus == 'running');
    if (!mounted || (task == null && !hasLegacyResume)) return;
    final service = ref.read(podcastTranscriptionServiceProvider);
    if (service.activeEpisodeId == episode.id ||
        !(await service.isModelInstalled())) {
      return;
    }
    unawaited(
      _startPodcastTranscription(allowSetup: false, pausePlayback: false),
    );
  }

  bool _transcriptPaused(drift_db.PodcastEpisode episode) =>
      episode.transcriptStatus == podcastTranscriptPausedStatus &&
      episode.transcriptProgressMs > 0;

  void _refreshTranscriptPage() {
    if (mounted) setState(() {});
  }

  Future<void> _pausePodcastTranscription() async {
    if (_pausingPodcastTranscription) return;
    final episodeId = _podcastEpisode?.id;
    final service = ref.read(podcastTranscriptionServiceProvider);
    // Whisper finishes the chunk it is holding before it lets go, which can
    // take a while on a long chunk size. Say so instead of looking stuck.
    setState(() => _pausingPodcastTranscription = true);
    _refreshTranscriptPage();
    try {
      await service.pause();
    } finally {
      if (mounted) {
        setState(() {
          _pausingPodcastTranscription = false;
          if (_podcastEpisode?.id == episodeId) {
            _transcribingPodcast = false;
            _transcriptionProgress = null;
          }
        });
        _refreshTranscriptPage();
      }
    }
  }

  void _watchBookTranscription(drift_db.Chapter chapter) {
    if (_bookAsrStorage?.chapter.id == chapter.id) return;
    unawaited(_bookAsrSubscription?.cancel());
    unawaited(_bookAsrProgressSubscription?.cancel());
    final storage = AudiobookTranscriptionStorage(
      ref.read(appDatabaseProvider),
      manifests: ref.read(manifestStoreProvider),
      book: widget.book,
      chapter: chapter,
    );
    _bookAsrStorage = storage;
    _bookAsrState = null;
    _bookAsrStarting = false;
    _bookAsrSubscription = storage.watch().listen((_) {
      unawaited(_refreshBookTranscription(storage));
    });
    _bookAsrProgressSubscription = ref
        .read(podcastTranscriptionServiceProvider)
        .progressStream
        .listen((progress) {
          if (!mounted || progress.episodeId != _selectedAudiobookChapter?.id) {
            return;
          }
          // Refresh menu availability as the transcription service changes state.
          setState(() {});
          _refreshTranscriptPage();
        });
  }

  Future<void> _refreshBookTranscription(
    AudiobookTranscriptionStorage storage,
  ) async {
    final revision = ++_bookAsrRefreshRevision;
    try {
      final state = await storage.read(storage.chapter.id);
      final manifest = await storage.manifests.load(
        widget.book.id,
        storage.chapter.id,
      );
      final paragraphs = await storage.database.getParagraphs(
        storage.chapter.id,
      );
      if (!mounted ||
          revision != _bookAsrRefreshRevision ||
          _selectedAudiobookChapter?.id != storage.chapter.id) {
        return;
      }
      setState(() {
        _bookAsrState = state;
        _selectedManifest = manifest;
        _audiobookParagraphs = paragraphs;
        _audiobookParagraphsFuture = Future.value(paragraphs);
      });
      _refreshTranscriptPage();
    } catch (error, stackTrace) {
      AppLogger.error('ASR', '读取章节字幕失败', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _startBookTranscription() async {
    final storage = _bookAsrStorage;
    if (storage == null || _bookAsrRunning) return;
    setState(() => _bookAsrStarting = true);
    _refreshTranscriptPage();
    try {
      if (!await _ensureWhisperModelReady()) return;
      if (!mounted || !identical(storage, _bookAsrStorage)) return;
      final episode = await storage.read(storage.chapter.id);
      if (episode == null || !mounted || !identical(storage, _bookAsrStorage)) {
        return;
      }
      await ref
          .read(podcastTranscriptionServiceProvider)
          .transcribe(
            episode,
            storage: storage,
            languageHint: widget.book.language,
          );
    } catch (error) {
      if (mounted && identical(storage, _bookAsrStorage)) {
        _showSnackBar(
          context.tr(
            '本地转写失败：$error',
            'Local transcription failed: $error',
            '文字起こしに失敗しました：$error',
          ),
        );
      }
    } finally {
      if (mounted && identical(storage, _bookAsrStorage)) {
        setState(() => _bookAsrStarting = false);
        await _refreshBookTranscription(storage);
      }
    }
  }

  Future<void> _pauseBookTranscription() async {
    if (_bookAsrPausing) return;
    setState(() => _bookAsrPausing = true);
    _refreshTranscriptPage();
    try {
      final service = ref.read(podcastTranscriptionServiceProvider);
      if (service.activeEpisodeId == _selectedAudiobookChapter?.id) {
        await service.pause();
      }
    } finally {
      if (mounted) {
        setState(() => _bookAsrPausing = false);
        _refreshTranscriptPage();
      }
    }
  }

  List<PopupMenuEntry<String>> _bookTranscriptionEntries() => [
    if (_bookAsrRunning || _bookAsrState?.transcriptStatus != 'complete')
      PopupMenuItem(
        key: ValueKey(
          _bookAsrRunning ? 'book-transcript-pause' : 'book-transcript-resume',
        ),
        value: _bookAsrRunning ? 'book_pause' : 'book_resume',
        enabled:
            !_bookAsrPausing &&
            (!_bookAsrRunning ||
                ref.read(podcastTranscriptionServiceProvider).activeEpisodeId ==
                    _selectedAudiobookChapter?.id),
        child: Text(
          _bookAsrRunning
              ? context.tr('暂停字幕生成', 'Pause subtitle generation', '字幕生成を一時停止')
              : context.tr(
                  '生成或继续字幕',
                  'Generate or resume subtitles',
                  '字幕生成を開始・再開',
                ),
        ),
      ),
  ];

  Future<void> _startPodcastTranscription({
    bool allowSetup = true,
    bool pausePlayback = true,
  }) async {
    final data = widget.podcast;
    final episode = _podcastEpisode;
    if (data == null || episode == null || _transcribingPodcast) return;

    if (allowSetup) {
      if (!await _ensureWhisperModelReady()) return;
    } else if (!await ref
        .read(podcastTranscriptionServiceProvider)
        .isModelInstalled()) {
      return;
    }
    if (!mounted || _podcastEpisode?.id != episode.id) return;
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    if (pausePlayback && handler.playbackState.value.playing) {
      await handler.pause();
    }
    if (!mounted || _podcastEpisode?.id != episode.id) return;
    setState(() {
      _transcribingPodcast = true;
      _transcriptionProgress = PodcastTranscriptionProgress(
        episodeId: episode.id,
        stage: PodcastTranscriptionStage.preparing,
        message: '正在准备本地转写',
      );
    });
    _refreshTranscriptPage();

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
              if (mounted && progress.episodeId == _podcastEpisode?.id) {
                setState(() => _transcriptionProgress = progress);
                _refreshTranscriptPage();
              }
            },
          );
    } catch (error) {
      if (mounted && _podcastEpisode?.id == episode.id) {
        _showSnackBar(
          context.tr(
            '本地转写失败：$error',
            'Local transcription failed: $error',
            'ローカル文字起こしに失敗しました：$error',
          ),
        );
      }
    } finally {
      if (mounted && _podcastEpisode?.id == episode.id) {
        setState(() {
          _transcribingPodcast = false;
          _transcriptionProgress = null;
        });
        _refreshTranscriptPage();
      }
    }
  }

  Future<void> _restartPodcastTranscription() async {
    final episode = _podcastEpisode;
    if (episode == null || _transcribingPodcast) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr('重新生成字幕？', 'Regenerate transcript?', '文字起こしを再生成しますか？'),
        ),
        content: Text(
          context.tr(
            '当前字幕会被删除，然后从头重新转写。',
            'The current transcript will be deleted and transcribed again from the beginning.',
            '現在の文字起こしを削除し、最初からやり直します。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('重新生成', 'Regenerate', '再生成')),
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

  Future<bool> _ensureWhisperModelReady() async {
    final service = ref.read(podcastTranscriptionServiceProvider);
    try {
      final info = await service.getModelInfo();
      if (info.installed) return true;
      if (!mounted) return false;
      final installed = await showAppSheet<bool>(
        context: context,
        enableDrag: false,
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
            '文字起こしモデルを確認できません：$error',
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
    final paragraphLabel = context.tr('段落', 'Paragraph', '段落');
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
      chapterTitle: _selectedAudiobookChapter?.title ?? '',
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
    final chapter = _selectedAudiobookChapter;
    if (chapter == null) {
      await handler.play();
      return true;
    }

    var latestManifest =
        manifest ??
        await ref.read(manifestStoreProvider).load(widget.book.id, chapter.id);
    if (!mounted) return false;
    if (latestManifest != null) {
      final paragraphs = _audiobookParagraphs.isNotEmpty
          ? _audiobookParagraphs
          : await ref.read(appDatabaseProvider).getParagraphs(chapter.id);
      if (!mounted) return false;
      latestManifest = validateAudiobookManifest(latestManifest, paragraphs);
    }
    final paragraphLabel = context.tr('段落', 'Paragraph', '段落');
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
              'キャッシュ済み音声を再生できません。消去して、もう一度生成してください。',
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
    final isPhoneLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).shortestSide < 600;
    final isSpaciousLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width >= 900;
    final isWideLayout = isPhoneLandscape || isSpaciousLandscape;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final preferences = ref.watch(appPreferencesProvider);
    _readingScrollSpeed = preferences.readingScrollSpeed;
    _lyricSweepEnabled = preferences.lyricSweepEnabled;
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    final theme = Theme.of(context);
    final topTint = theme.colorScheme.surfaceContainer;
    final pageBottom = theme.colorScheme.surface;
    final middleTint = Color.lerp(topTint, pageBottom, 0.62)!;
    final isDark = theme.brightness == Brightness.dark;
    final hasPersistentToolbar = MacosPersistentToolbarScope.hasToolbar(
      context,
    );
    if (hasPersistentToolbar) {
      final currentTitle = _isPodcast
          ? (_podcastEpisode?.title ??
                widget.podcast?.episode.title ??
                widget.book.title)
          : (_activeAudiobookChapter?.title ?? widget.book.title);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _macosMiddleNotifier?.updateValue(null);
        _macosTitleNotifier?.updateValue(currentTitle);
        _macosTrailingNotifier?.updateValue(
          _buildPersistentToolbarTrailing(context),
        );
      });
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Container(
        key: const ValueKey('player-immersive-background'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topTint, middleTint, pageBottom],
            stops: const [0, 0.46, 1],
          ),
        ),
        // The cover wash sits between the page gradient and the content so it
        // reaches under the system bars too, rather than stopping at whichever
        // panel happens to be on screen. The background Container stays the
        // Scaffold's ancestor so it keeps painting behind both bars.
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              key: const ValueKey('player-page-ambience'),
              child: _buildPageAmbience(),
            ),
            Scaffold(
              resizeToAvoidBottomInset: false,
              // Keep the page-level background visible behind both system bars.
              backgroundColor: Colors.transparent,
              body: SafeArea(
                top: !hasPersistentToolbar,
                child: Column(
                  children: [
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
                              'プレーヤーを利用できません：$error',
                            ),
                            style: TextStyle(color: context.appTextSecondary),
                          ),
                        ),
                        data: (handler) => _buildOnLoadedMediaChange(handler, (
                          context,
                          selectedLoaded,
                        ) {
                          final currentItem = handler.mediaItem.valueOrNull;
                          final manifest = _effectiveManifest(handler);
                          final duration = _selectedDuration(
                            handler,
                            selectedLoaded: selectedLoaded,
                            manifest: manifest,
                          );
                          final currentChapterId =
                              _selectedAudiobookChapter?.id ??
                              currentItem?.extras?['chapterId'] as String?;
                          final chapterTitle =
                              _selectedAudiobookChapter?.title ??
                              currentItem?.title ??
                              context.tr('未知章节', 'Unknown Chapter', '不明な章');

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              if (isWideLayout) {
                                final episode = _isPodcast
                                    ? _podcastEpisode ?? widget.podcast!.episode
                                    : null;
                                return _buildLandscapePlayerBody(
                                  handler: handler,
                                  duration: duration,
                                  selectedLoaded: selectedLoaded,
                                  manifest: manifest,
                                  chapterId:
                                      episode?.id ??
                                      currentChapterId ??
                                      widget.book.id,
                                  chapterTitle: episode?.title ?? chapterTitle,
                                  isSpacious: !isPhoneLandscape,
                                );
                              }
                              if (_isPodcast) {
                                return _buildPodcastPlayerBody(
                                  constraints: constraints,
                                  handler: handler,
                                  selectedLoaded: selectedLoaded,
                                  duration: duration,
                                  manifest: manifest,
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
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isPhoneLandscape && !hasPersistentToolbar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: isMac
                    ? MacosWindowToolbar(
                        isSidebarVisible: true,
                        canGoBack: true,
                        onBack: () => Navigator.of(context).maybePop(),
                        canGoForward: false,
                        trailing: Padding(
                          padding: EdgeInsets.only(
                            right: context.appDesign.spaceSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_isPodcast)
                                IconButton(
                                  key: const ValueKey(
                                    'player-reader-mode-button',
                                  ),
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedBookOpen01,
                                    size: 20,
                                    color: context.appTextPrimary,
                                  ),
                                  tooltip: context.tr(
                                    '阅读模式',
                                    'Reader Mode',
                                    '読書モード',
                                  ),
                                  style: IconButton.styleFrom(
                                    foregroundColor: context.appTextPrimary,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => BookReaderScreen(
                                          book: widget.book,
                                          initialChapter:
                                              _activeAudiobookChapter,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              Material(
                                type: MaterialType.transparency,
                                child: _buildPlaybackMoreMenu(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.appDesign.spaceSm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (isWideLayout)
                                IconButton(
                                  key: const ValueKey('player-close-button'),
                                  icon: const AppIcon(
                                    AppIcons.cancel01,
                                    size: 22,
                                  ),
                                  tooltip: context.tr('关闭', 'Close', '閉じる'),
                                  style: IconButton.styleFrom(
                                    foregroundColor: context.appTextPrimary,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                )
                              else
                                const AppBackButton(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_isPodcast)
                                    IconButton(
                                      key: const ValueKey(
                                        'player-reader-mode-button',
                                      ),
                                      icon: HugeIcon(
                                        icon: HugeIcons.strokeRoundedBookOpen01,
                                        size: 20,
                                        color: context.appTextPrimary,
                                      ),
                                      tooltip: context.tr(
                                        '阅读模式',
                                        'Reader Mode',
                                        '読書モード',
                                      ),
                                      style: IconButton.styleFrom(
                                        foregroundColor: context.appTextPrimary,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => BookReaderScreen(
                                              book: widget.book,
                                              initialChapter:
                                                  _activeAudiobookChapter,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  Material(
                                    type: MaterialType.transparency,
                                    child: _buildPlaybackMoreMenu(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapePlayerBody({
    required LuminaAudioHandler handler,
    required Duration duration,
    required bool selectedLoaded,
    required ChapterManifest? manifest,
    required String chapterId,
    required String chapterTitle,
    required bool isSpacious,
  }) {
    final design = context.appDesign;
    return Row(
      key: const ValueKey('player-landscape-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left column: artwork + metadata + controls (in spacious) ───
        Expanded(
          flex: 2,
          child: Padding(
            key: const ValueKey('player-landscape-cover'),
            padding: EdgeInsets.symmetric(horizontal: design.spaceLg),
            child: Column(
              children: [
                // Artwork – takes available space above the controls
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Center(
                      key: const ValueKey('player-landscape-artwork-viewport'),
                      child: _buildArtwork(
                        _pixelAlignedArtworkSize(
                          constraints,
                          math.min(
                            320,
                            constraints.biggest.shortestSide * 0.82,
                          ),
                        ),
                        borderRadius: design.radiusLarge,
                        showShadow: false,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: design.spaceSm),
                // Title / artist
                _buildChapterMetadata(chapterTitle),
                if (isSpacious) ...[
                  SizedBox(height: design.spaceSm),
                  // Progress bar + playback buttons (always visible on iPad / macOS)
                  _buildReactiveControls(
                    handler: handler,
                    fallbackDuration: duration,
                    manifest: manifest,
                    foregroundColor: context.appTextPrimary,
                    transcriptModeActive: false,
                    onTranscriptToggle: null,
                  ),
                ],
                // Secondary actions (output picker, chapter list, etc.)
                Padding(
                  key: const ValueKey('player-landscape-actions'),
                  padding: EdgeInsets.symmetric(vertical: design.spaceSm),
                  child: _buildSecondaryActions(
                    context,
                    handler: handler,
                    transcriptModeActive: _landscapeTranscriptActive,
                    onTranscriptToggle: () => setState(() {
                      _landscapeTranscriptActive = !_landscapeTranscriptActive;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Right column: lyrics / transcript (or controls on phone) ───
        Expanded(
          flex: 3,
          child: (!isSpacious && !_landscapeTranscriptActive)
              ? Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: design.spaceLg),
                    child: _buildReactiveControls(
                      handler: handler,
                      fallbackDuration: duration,
                      manifest: manifest,
                      foregroundColor: context.appTextPrimary,
                      transcriptModeActive: false,
                      onTranscriptToggle: null,
                    ),
                  ),
                )
              : SizedBox.expand(
                  key: const ValueKey('player-landscape-transcript'),
                  child: _buildTranscriptEdgeFade(
                    child: _buildSyncedLyrics(
                      chapterId: chapterId,
                      handler: handler,
                      manifest: manifest,
                      playbackEnabled: selectedLoaded,
                      expanded: true,
                      focusMode: true,
                      listKey: ValueKey('transcript-focus:$chapterId'),
                    ),
                  ),
                ),
        ),
      ],
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
    final viewportContentHeight = math.max(360.0, constraints.maxHeight);

    return _buildBookCoverBody(
      handler: handler,
      selectedLoaded: selectedLoaded,
      duration: duration,
      manifest: manifest,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      pageInset: pageInset,
      compact: compact,
      artworkSize: artworkSize,
      viewportContentHeight: viewportContentHeight,
      onTranscriptTap: chapterId == null
          ? null
          : () => unawaited(
              _openTranscriptPage(
                handler: handler,
                chapterId: chapterId,
                chapterTitle: chapterTitle,
              ),
            ),
    );
  }

  Widget _buildBookCoverBody({
    required LuminaAudioHandler handler,
    required bool selectedLoaded,
    required Duration duration,
    required ChapterManifest? manifest,
    required String? chapterId,
    required String chapterTitle,
    required double pageInset,
    required bool compact,
    required double artworkSize,
    required double viewportContentHeight,
    required VoidCallback? onTranscriptTap,
  }) {
    final design = context.appDesign;
    return CustomScrollView(
      key: const ValueKey('book-player-scroll-view'),
      controller: _playerScrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: viewportContentHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildCoverContentSwitch(
                    handler: handler,
                    manifest: manifest,
                    chapterId: chapterId ?? widget.book.id,
                    selectedLoaded: selectedLoaded,
                    cover: Padding(
                      key: const ValueKey('book-cover-focus-viewport'),
                      padding: EdgeInsets.symmetric(horizontal: pageInset),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: LayoutBuilder(
                              builder: (context, artworkConstraints) {
                                return Center(
                                  child: _buildArtwork(
                                    _pixelAlignedArtworkSize(
                                      artworkConstraints,
                                      artworkSize,
                                    ),
                                    borderRadius: design.radiusLarge,
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            height: compact ? design.spaceLg : design.spaceXl,
                          ),
                          _buildChapterMetadata(chapterTitle),
                        ],
                      ),
                    ),
                  ),
                ),

                _buildTranscriptChromeBand(
                  fromTop: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      pageInset,
                      design.spaceXl,
                      pageInset,
                      design.spaceXl,
                    ),
                    child: _buildReactiveControls(
                      handler: handler,
                      fallbackDuration: duration,
                      manifest: manifest,
                      foregroundColor: context.appTextPrimary,
                      showSecondaryActions: true,
                      transcriptModeActive: _transcriptPageActive,
                      onTranscriptToggle: onTranscriptTap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DecoratedSliver(
          decoration: BoxDecoration(color: context.appBackground),
          sliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(
              pageInset,
              design.spaceLg,
              pageInset,
              design.spaceXxl,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  RepaintBoundary(
                    child: _buildAiCard(handler: handler, manifest: manifest),
                  ),
                  SizedBox(height: design.spaceMd),
                  RepaintBoundary(
                    child: _buildAiCard(
                      handler: handler,
                      manifest: manifest,
                      chatbot: true,
                    ),
                  ),
                  SizedBox(height: design.spaceMd),
                  RepaintBoundary(
                    child: _buildTranscriptPointerCard(onTap: onTranscriptTap),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodcastPlayerBody({
    required BoxConstraints constraints,
    required LuminaAudioHandler handler,
    required bool selectedLoaded,
    required Duration duration,
    required ChapterManifest? manifest,
  }) {
    final data = widget.podcast!;
    final episode = _podcastEpisode ?? data.episode;
    // An episode is not a chapter: the caller's title comes from the synthetic
    // chapter this screen was opened with, which stays on the episode that was
    // playing then. Switching episodes has to retitle the player.
    final episodeTitle = episode.title;
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
    final viewportContentHeight = math.max(360.0, constraints.maxHeight);

    return _buildPodcastCoverBody(
      constraints: constraints,
      handler: handler,
      episode: episode,
      duration: duration,
      manifest: manifest,
      chapterTitle: episodeTitle,
      pageInset: pageInset,
      compact: compact,
      artworkSize: artworkSize,
      viewportContentHeight: viewportContentHeight,
      onTranscriptTap: () => unawaited(
        _openTranscriptPage(
          handler: handler,
          chapterId: episode.id,
          chapterTitle: episodeTitle,
        ),
      ),
    );
  }

  Widget _buildPodcastCoverBody({
    required BoxConstraints constraints,
    required LuminaAudioHandler handler,
    required drift_db.PodcastEpisode episode,
    required Duration duration,
    required ChapterManifest? manifest,
    required String chapterTitle,
    required double pageInset,
    required bool compact,
    required double artworkSize,
    required double viewportContentHeight,
    required VoidCallback onTranscriptTap,
  }) {
    final design = context.appDesign;

    return CustomScrollView(
      key: const ValueKey('podcast-player-scroll-view'),
      controller: _playerScrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: viewportContentHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildCoverContentSwitch(
                    handler: handler,
                    manifest: manifest,
                    chapterId: episode.id,
                    selectedLoaded: _isSelectedChapterLoaded(handler),
                    cover: Padding(
                      key: const ValueKey('podcast-cover-focus-viewport'),
                      padding: EdgeInsets.symmetric(horizontal: pageInset),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: LayoutBuilder(
                              builder: (context, artworkConstraints) {
                                return Center(
                                  child: _buildArtwork(
                                    _pixelAlignedArtworkSize(
                                      artworkConstraints,
                                      artworkSize,
                                    ),
                                    borderRadius: design.radiusLarge,
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            height: compact ? design.spaceLg : design.spaceXl,
                          ),
                          _buildChapterMetadata(chapterTitle),
                        ],
                      ),
                    ),
                  ),
                ),

                _buildTranscriptChromeBand(
                  fromTop: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      pageInset,
                      design.spaceXl,
                      pageInset,
                      design.spaceXl,
                    ),
                    child: _buildReactiveControls(
                      handler: handler,
                      fallbackDuration: duration,
                      manifest: manifest,
                      foregroundColor: context.appTextPrimary,
                      showSecondaryActions: true,
                      transcriptModeActive: _transcriptPageActive,
                      onTranscriptToggle: onTranscriptTap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DecoratedSliver(
          decoration: BoxDecoration(color: context.appBackground),
          sliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(
              pageInset,
              design.spaceLg,
              pageInset,
              design.spaceXxl,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  RepaintBoundary(
                    child: _buildPodcastShownotesCard(
                      episode: episode,
                      handler: handler,
                    ),
                  ),
                  SizedBox(height: design.spaceMd),
                  RepaintBoundary(
                    child: _buildAiCard(handler: handler, manifest: manifest),
                  ),
                  SizedBox(height: design.spaceMd),
                  RepaintBoundary(
                    child: _buildAiCard(
                      handler: handler,
                      manifest: manifest,
                      chatbot: true,
                    ),
                  ),
                  SizedBox(height: design.spaceMd),
                  RepaintBoundary(
                    child: _buildTranscriptPointerCard(onTap: onTranscriptTap),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The transcript no longer has a card of its own. This dashed row tells a
  /// reader who scrolls looking for it where it went, and doubles as a second
  /// way into transcript mode.
  Widget _buildTranscriptPointerCard({required VoidCallback? onTap}) {
    final design = context.appDesign;
    final cachedCount = _podcastTranscript?.timingCount ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('transcript-pointer-card'),
        borderRadius: BorderRadius.circular(design.radiusLarge),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: context.appTextPrimary.withValues(alpha: 0.16),
            radius: design.radiusLarge,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: design.spaceLg,
              vertical: design.spaceLg,
            ),
            child: Row(
              children: [
                AppIcon(
                  AppIcons.bubbleChat,
                  size: 20,
                  color: context.appTextSecondary,
                ),
                SizedBox(width: design.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPodcast
                            ? context.tr(
                                '转录已移至播放器',
                                'Transcript moved to the player',
                                '文字起こしをプレーヤーに移動しました',
                              )
                            : context.tr(
                                '正文已移至播放器',
                                'Chapter text moved to the player',
                                '章の本文をプレーヤーに移動しました',
                              ),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                          color: context.appTextPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                      SizedBox(height: design.spaceXs),
                      Text(
                        cachedCount > 0
                            ? context.tr(
                                '点此以歌词方式跟读 · 已缓存 $cachedCount 段',
                                'Read along lyric-style · $cachedCount segments cached',
                                '歌詞のように読み進める · $cachedCount件をキャッシュ済み',
                              )
                            : context.tr(
                                '点此以歌词方式跟读',
                                'Read along lyric-style',
                                '歌詞のように読み進める',
                              ),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AppIcon(
                  AppIcons.arrowRight01,
                  size: 20,
                  color: context.appTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The lyric-style reading panel, shared by podcasts and books. Only the
  /// header, the identity of the text being read, and the cards below the fold
  /// differ between the two.
  Widget _buildCoverContentSwitch({
    required Widget cover,
    required LuminaAudioHandler handler,
    required ChapterManifest? manifest,
    required String chapterId,
    required bool selectedLoaded,
  }) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeOut,
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    child: _transcriptPageActive
        ? SizedBox.expand(
            key: const ValueKey('player-inline-transcript'),
            child: _buildTranscriptEdgeFade(
              child: _buildSyncedLyrics(
                chapterId: chapterId,
                handler: handler,
                manifest: manifest,
                playbackEnabled: selectedLoaded,
                expanded: true,
                focusMode: true,
                listKey: ValueKey('transcript-focus:$chapterId'),
              ),
            ),
          )
        : KeyedSubtree(
            key: const ValueKey('player-inline-cover'),
            child: cover,
          ),
  );

  Widget _buildTranscriptEdgeFade({required Widget child}) {
    final theme = Theme.of(context);
    final top = theme.colorScheme.surfaceContainer;
    final bottom = theme.colorScheme.surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: child),
        IgnorePointer(
          child: Column(
            children: [
              Expanded(
                flex: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [top, top.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 56),
              Expanded(
                flex: 23,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bottom.withValues(alpha: 0), bottom],
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 7),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptChromeBand({
    required bool fromTop,
    required Widget child,
  }) {
    return _buildTranscriptChrome(fromTop: fromTop, child: child);
  }

  Widget _buildPageAmbience() => const SizedBox.shrink();

  /// Draws one of the fixed chrome bands and its scrim. Keeping the band in
  /// the layout at all times prevents the transcript from changing height or
  /// colliding with the transport controls.
  Widget _buildTranscriptChrome({
    required bool fromTop,
    required Widget child,
  }) {
    // The page ambience already paints the cover-derived accent behind the
    // entire transcript route. An opaque surfaceContainer here masked that
    // tint only beneath the mini player and produced a hard white seam. Keep
    // the top chrome transparent so it shares the exact same accent field as
    // the reading viewport; only the lower transport chrome needs a scrim.
    if (fromTop) {
      return KeyedSubtree(
        key: const ValueKey('player-transcript-top-chrome'),
        child: child,
      );
    }
    final scrim = Theme.of(context).colorScheme.surface;
    return DecoratedBox(
      key: const ValueKey('player-transcript-bottom-chrome'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            scrim,
            scrim.withValues(alpha: 0.96),
            scrim.withValues(alpha: 0),
          ],
          stops: const [0, 0.62, 1],
        ),
      ),
      child: child,
    );
  }

  /// Start/pause/redo controls for local Whisper transcription. These belong to
  /// podcasts only — a book's text ships with it and is never transcribed.
  List<PopupMenuEntry<String>> _podcastTranscriptionEntries(
    drift_db.PodcastEpisode episode,
  ) {
    final running = _transcribingPodcast;
    final paused = _transcriptPaused(episode);
    final hasTranscript = (_podcastTranscript?.timingCount ?? 0) > 0;
    return [
      PopupMenuItem<String>(
        key: ValueKey(
          running ? 'podcast-transcript-pause' : 'podcast-transcript-restart',
        ),
        value: running
            ? 'pause'
            : paused || !hasTranscript
            ? 'start'
            : 'restart',
        enabled: !_pausingPodcastTranscription,
        child: Text(
          _pausingPodcastTranscription
              ? context.tr(
                  '正在暂停字幕生成…',
                  'Pausing subtitle generation…',
                  '字幕生成を一時停止中…',
                )
              : running
              ? context.tr('暂停字幕生成', 'Pause subtitle generation', '字幕生成を一時停止')
              : paused
              ? context.tr('继续字幕生成', 'Resume subtitle generation', '字幕生成を再開')
              : hasTranscript
              ? context.tr('重新生成字幕', 'Regenerate subtitles', '字幕を再生成')
              : context.tr('生成字幕', 'Generate subtitles', '字幕を生成'),
        ),
      ),
    ];
  }

  /// Summary and chat share the currently selected content and prerequisites.
  Widget _buildAiCard({
    required LuminaAudioHandler handler,
    required ChapterManifest? manifest,
    bool chatbot = false,
  }) {
    final llmState = ref.watch(llmSettingsControllerProvider);
    final aiServiceReady =
        llmState.asData?.value.readiness == ServiceReadiness.ready;
    final podcast = widget.podcast;
    final episode = _podcastEpisode ?? podcast?.episode;
    final chapter = _selectedAudiobookChapter;
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
    final transcriptAvailable = _isRecordedBook
        ? (_selectedManifest?.segments.firstOrNull?.timings.isNotEmpty ?? false)
        : podcast == null
        ? true
        : (_podcastTranscript?.timingCount ?? 0) > 0;
    final VoidCallback? onTranscriptRequired = _isRecordedBook
        ? _startBookTranscription
        : _isPodcast
        ? _startPodcastTranscription
        : null;
    if (chatbot) {
      return _buildPlayerSectionCard(
        key: const ValueKey('ai-chatbot-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlayerCardTitle(
              icon: AppIcons.bubbleChat,
              title: 'AI Chatbot',
            ),
            SizedBox(height: context.appDesign.spaceMd),
            Text(
              !transcriptAvailable
                  ? context.tr(
                      '生成文字稿后，即可围绕当前内容提问。',
                      'Generate a transcript to ask about this content.',
                      '文字起こしを生成すると、この内容について質問できます。',
                    )
                  : !aiServiceReady
                  ? context.tr(
                      '配置 AI 服务后，即可开始对话。',
                      'Set up an AI service to start chatting.',
                      'AI サービスを設定すると会話を開始できます。',
                    )
                  : context.tr(
                      '围绕当前内容提问、解释难点，并通过引用回到原文。',
                      'Ask about this content, explore ideas, and follow references back to the transcript.',
                      'この内容について質問し、理解を深め、参照から原文を確認できます。',
                    ),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: context.appDesign.spaceLg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('ai-chatbot-open'),
                onPressed: !transcriptAvailable
                    ? onTranscriptRequired
                    : !aiServiceReady
                    ? _openAiServiceSettings
                    : () => showCupertinoSheet<void>(
                        context: context,
                        scrollableBuilder: (sheetContext, scrollController) =>
                            AiConversationSheet(
                              scope: scope,
                              scrollController: scrollController,
                              onCitationTap: (citation) => _handleAiCitation(
                                citation,
                                scope,
                                handler,
                                manifest,
                              ),
                            ),
                      ),
                icon: const AppIcon(AppIcons.bubbleChat),
                label: Text(
                  !transcriptAvailable
                      ? context.tr('生成文字稿', 'Generate transcript', '文字起こしを生成')
                      : !aiServiceReady
                      ? context.tr(
                          '配置 AI 服务',
                          'Set up AI service',
                          'AI サービスを設定',
                        )
                      : context.tr('开始对话', 'Start chatting', '会話を開始'),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _buildPlayerSectionCard(
      key: const ValueKey('ai-summary-card'),
      child: AiSummaryPanel(
        scope: scope,
        transcriptAvailable: transcriptAvailable,
        onCitationTap: (citation) =>
            _handleAiCitation(citation, scope, handler, manifest),
        onTranscriptRequired: onTranscriptRequired,
        aiServiceReady: aiServiceReady,
        onAiServiceRequired: _openAiServiceSettings,
      ),
    );
  }

  Future<void> _openAiServiceSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DictionaryExplanationServiceScreen(),
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
        context.tr(
          '找不到这条 Transcript 引用。',
          'Transcript reference not found.',
          '文字起こしの参照が見つかりません。',
        ),
      );
      return;
    }

    final canPlay =
        _isPodcast || (manifest != null && _isSelectedChapterLoaded(handler));
    final playFromCitation = await showAppSheet<bool>(
      context: context,
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
                AppIcon(
                  AppIcons.quoteDown,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                SizedBox(width: sheetContext.appDesign.spaceSm),
                Expanded(
                  child: Text(
                    context.tr(
                      'Transcript 引用 ${citation.label}',
                      'Transcript reference ${citation.label}',
                      '文字起こしの参照 ${citation.label}',
                    ),
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(
                          color: sheetContext.appTextPrimary,
                          fontWeight: FontWeight.normal,
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
                    child: Text(context.tr('关闭', 'Close', '閉じる')),
                  ),
                ),
                if (canPlay) ...[
                  SizedBox(width: sheetContext.appDesign.spaceSm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const AppIcon(AppIcons.play),
                      label: Text(
                        context.tr('从这里播放', 'Play from here', 'ここから再生'),
                      ),
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
    final chapter = _selectedAudiobookChapter;
    if (paragraphIndex == null || chapter == null || manifest == null) return;
    final paragraphs = await ref
        .read(appDatabaseProvider)
        .getParagraphs(chapter.id);
    final zeroBasedIndex = paragraphIndex - 1;
    if (zeroBasedIndex < 0 || zeroBasedIndex >= paragraphs.length) return;
    final offsetMs = manifest.offsetOf(paragraphs[zeroBasedIndex].id);
    await handler.seek(Duration(milliseconds: offsetMs));
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
            icon: AppIcons.note01,
            title: context.tr('节目笔记', 'Shownotes', '番組ノート'),
          ),
          SizedBox(height: context.appDesign.spaceMd),
          PodcastLinkText(
            notes.isEmpty
                ? context.tr(
                    '该单集没有附带节目笔记。',
                    'No shownotes provided.',
                    '番組ノートはありません。',
                  )
                : notes,
            key: const ValueKey('podcast-episode-description'),
            onSeekTimestamp: (position) =>
                _seekToPodcastShownoteTimestamp(handler, position),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.appTextSecondary,
              height: 1.5,
            ),
          ),
          if (canExpand) ...[
            SizedBox(height: context.appDesign.spaceSm),
            TextButton.icon(
              key: const ValueKey('podcast-shownotes-toggle'),
              onPressed: () => showAppContentSheet(
                context: context,
                title: context.tr('节目笔记', 'Shownotes', '番組ノート'),
                builder: (sheetContext) => PodcastLinkText(
                  notes,
                  onSeekTimestamp: (position) {
                    Navigator.of(sheetContext).pop();
                    return _seekToPodcastShownoteTimestamp(handler, position);
                  },
                  style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                    color: sheetContext.appTextSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              iconAlignment: IconAlignment.end,
              icon: const AppIcon(AppIcons.arrowDown01),
              label: Text(
                context.tr('查看完整笔记', 'Show full notes', '番組ノートをすべて表示'),
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
    required AppIconData icon,
    required String title,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 20, color: context.appTextSecondary),
        SizedBox(width: context.appDesign.spaceSm),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersistentToolbarTrailing(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isPodcast)
          IconButton(
            key: const ValueKey('player-reader-mode-button'),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedBookOpen01,
              size: 20,
              color: context.appTextPrimary,
            ),
            tooltip: context.tr('阅读模式', 'Reader Mode', '読書モード'),
            style: IconButton.styleFrom(
              foregroundColor: context.appTextPrimary,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BookReaderScreen(
                    book: widget.book,
                    initialChapter: _activeAudiobookChapter,
                  ),
                ),
              );
            },
          ),
        Material(
          type: MaterialType.transparency,
          child: _buildPlaybackMoreMenu(),
        ),
      ],
    );
  }

  Widget _buildPlaybackMoreMenu() => Builder(
    builder: (anchorContext) => AppGlassMenuButton<String>(
      key: const ValueKey('player-more-menu'),
      tooltip: context.tr('更多选项', 'More options', 'その他のオプション'),
      itemBuilder: (context) => [
        if (_transcriptPageActive && _isPodcast)
          ..._podcastTranscriptionEntries(
            _podcastEpisode ?? widget.podcast!.episode,
          ),
        if (_transcriptPageActive && _isRecordedBook)
          ..._bookTranscriptionEntries(),
        PopupMenuItem(
          value: 'speed',
          child: Text(context.tr('播放倍速', 'Playback speed', '再生速度')),
        ),
        PopupMenuItem(
          value: 'chapters',
          child: Text(context.tr('章节列表', 'Playlist', '再生リスト')),
        ),
        PopupMenuItem(
          value: 'timer',
          child: Text(context.tr('定时关闭', 'Sleep timer', 'スリープタイマー')),
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'pause':
            unawaited(_pausePodcastTranscription());
            return;
          case 'start':
            unawaited(_startPodcastTranscription(pausePlayback: false));
            return;
          case 'restart':
            unawaited(_restartPodcastTranscription());
            return;
          case 'book_pause':
            unawaited(_pauseBookTranscription());
            return;
          case 'book_resume':
            unawaited(_startBookTranscription());
            return;
        }
        final handler = ref.read(luminaAudioHandlerProvider).asData?.value;
        if (action == 'speed') _showSpeedMenu(anchorContext);
        if (handler == null) return;
        if (action == 'chapters') unawaited(_showPlaylist(handler));
        if (action == 'timer') _showSleepTimerMenu(handler, anchorContext);
      },
    ),
  );

  Widget _buildArtwork(
    double size, {
    required double borderRadius,
    bool showShadow = true,
  }) {
    final compactArtwork = size <= 96;
    return RepaintBoundary(
      key: const ValueKey('player-artwork-repaint-boundary'),
      child: SizedBox.square(
        key: const ValueKey('player-artwork'),
        dimension: size,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.46),
                      blurRadius: compactArtwork ? 16 : 32,
                      spreadRadius: compactArtwork ? 0 : 2,
                      offset: Offset(0, compactArtwork ? 6 : 16),
                    ),
                  ]
                : null,
          ),
          child: _isPodcast
              ? PodcastArtwork(
                  imageUrl:
                      _podcastEpisode?.imageUrl ??
                      widget.podcast?.show.imageUrl,
                  size: size,
                  borderRadius: borderRadius,
                )
              : BookCover(
                  coverPath: widget.book.coverPath,
                  iconSize: size * 0.32,
                  borderRadius: borderRadius,
                ),
        ),
      ),
    );
  }

  double _pixelAlignedArtworkSize(
    BoxConstraints constraints,
    double targetSize,
  ) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final availableSize = math.min(constraints.maxWidth, constraints.maxHeight);
    return (math.min(targetSize, availableSize) * pixelRatio).floorToDouble() /
        pixelRatio;
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
                  fontWeight: FontWeight.normal,
                ),
              ),
              SizedBox(height: design.spaceXs),
              Text(
                widget.book.author ??
                    context.tr('未知作者', 'Unknown Author', '著者不明'),
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
          tooltip: context.tr('收藏', 'Save', '保存'),
          icon: const AppIcon(AppIcons.favourite),
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
                AppIcon(
                  _transcribingPodcast
                      ? AppIcons.audioWave01
                      : AppIcons.subtitle,
                  color: context.appTextSecondary,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  _transcribingPodcast
                      ? currentProgress?.message ??
                            context.tr(
                              '正在本地转写',
                              'Transcribing locally',
                              'ローカルで文字起こし中',
                            )
                      : paused
                      ? context.tr(
                          '转写已暂停',
                          'Transcription paused',
                          '文字起こしを一時停止中',
                        )
                      : failed
                      ? context.tr(
                          '上次转写未完成',
                          'Last transcription stopped',
                          '前回の文字起こしは未完了',
                        )
                      : context.tr(
                          '这个单集还没有字幕',
                          'No transcript yet',
                          '文字起こしはまだありません',
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                if (!_transcribingPodcast) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _startPodcastTranscription,
                    icon: AppIcon(
                      paused ? AppIcons.play : AppIcons.aiMagic,
                      size: 18,
                    ),
                    label: Text(
                      paused
                          ? context.tr(
                              '继续转写',
                              'Resume transcription',
                              '文字起こしを再開',
                            )
                          : context.tr(
                              '使用本地 Whisper 转写',
                              'Transcribe on device',
                              'この端末で文字起こし',
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
        fontScale: ref.watch(
          appearanceControllerProvider.select((s) => s.fontScale),
        ),
        subtitleGap: ref.watch(
          appearanceControllerProvider.select((s) => s.subtitleGap),
        ),
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
      return lyrics;
    }

    if (_isRecordedBook) {
      final timings =
          manifest?.segments.firstOrNull?.timings ?? const <AudioTextTiming>[];
      final running = _bookAsrRunning;
      return Column(
        children: [
          Expanded(
            child: timings.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(AppIcons.subtitle, size: 34),
                          const SizedBox(height: 12),
                          Text(
                            running
                                ? context.tr(
                                    '正在本地生成字幕',
                                    'Transcribing on device',
                                    '端末で文字起こし中',
                                  )
                                : _bookAsrState?.transcriptStatus == 'failed'
                                ? context.tr(
                                    '上次转写未完成，可以重试',
                                    'Transcription stopped. Try again.',
                                    '文字起こしが中断されました。再試行できます。',
                                  )
                                : context.tr(
                                    '这一章还没有字幕',
                                    'No transcript for this chapter yet',
                                    'この章の字幕はまだありません',
                                  ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (!running)
                            FilledButton.icon(
                              key: const ValueKey('book-transcript-start'),
                              onPressed: _startBookTranscription,
                              icon: const AppIcon(AppIcons.subtitle),
                              label: Text(
                                context.tr(
                                  '在本地生成字幕',
                                  'Transcribe on device',
                                  'この端末で文字起こし',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                : SyncedLyricsList(
                    fontScale: ref.watch(
                      appearanceControllerProvider.select((s) => s.fontScale),
                    ),
                    subtitleGap: ref.watch(
                      appearanceControllerProvider.select((s) => s.subtitleGap),
                    ),
                    key: listKey,
                    paragraphs: [
                      for (final paragraph in _audiobookParagraphs)
                        paragraph.copyWith(
                          content: joinPodcastTranscriptLines(timings),
                        ),
                    ],
                    manifest: manifest,
                    handler: handler,
                    playbackEnabled: playbackEnabled,
                    expanded: expanded,
                    focusMode: focusMode,
                    bookTitle: widget.book.title,
                    chapterTitle: _selectedAudiobookChapter?.title,
                    bookId: widget.book.id,
                    chapterId: chapterId,
                    virtualized: true,
                    scrollSpeed: _readingScrollSpeed,
                    sweepEnabled: _lyricSweepEnabled,
                  ),
          ),
        ],
      );
    }
    final paragraphsFuture = _audiobookParagraphsFuture ??= ref
        .read(appDatabaseProvider)
        .getParagraphs(chapterId);
    return FutureBuilder<List<drift_db.Paragraph>>(
      future: paragraphsFuture,
      builder: (context, snapshot) {
        final paragraphs = snapshot.data ?? _audiobookParagraphs;
        if (paragraphs.isEmpty) {
          return Center(
            child: Text(
              context.tr('无正文', 'No text', '本文なし'),
              style: TextStyle(color: context.appTextSecondary),
            ),
          );
        }
        return SyncedLyricsList(
          fontScale: ref.watch(
            appearanceControllerProvider.select((s) => s.fontScale),
          ),
          subtitleGap: ref.watch(
            appearanceControllerProvider.select((s) => s.subtitleGap),
          ),
          key: listKey,
          paragraphs: paragraphs,
          manifest: manifest,
          handler: handler,
          playbackEnabled: playbackEnabled,
          expanded: expanded,
          focusMode: focusMode,
          bookTitle: widget.book.title,
          chapterTitle: _selectedAudiobookChapter?.title,
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
    bool showSecondaryActions = false,
    required bool transcriptModeActive,
    required VoidCallback? onTranscriptToggle,
  }) {
    return RepaintBoundary(
      key: const ValueKey('player-controls-repaint-boundary'),
      // `selectedLoaded` is read straight off the handler, so the transport has
      // to rebuild when the loaded item changes too. Watching only `playing`
      // left the controls stuck on "preparing" whenever playback was already
      // running when the newly loaded chapter or episode took over.
      child: _buildOnLoadedMediaChange(handler, (context, selectedLoaded) {
        return StreamBuilder<({bool playing, bool buffering})>(
          stream: handler.playbackState.map(_transportState).distinct(),
          initialData: _transportState(handler.playbackState.value),
          builder: (context, playbackSnapshot) {
            final transport =
                playbackSnapshot.data ?? (playing: false, buffering: false);
            final playing = selectedLoaded && transport.playing;
            final buffering = selectedLoaded && transport.buffering;
            final duration = selectedLoaded
                ? handler.chapterDuration
                : fallbackDuration;
            Widget buildPositionControls(bool pausePositionUpdates) {
              return StreamBuilder<Duration>(
                stream: pausePositionUpdates
                    ? null
                    : handler.chapterPositionStream,
                initialData: handler.chapterPosition,
                builder: (context, positionSnapshot) {
                  return ValueListenableBuilder<int>(
                    valueListenable: _controlStateRevision,
                    builder: (context, _, _) => _buildControls(
                      context,
                      handler,
                      playing,
                      selectedLoaded
                          ? positionSnapshot.data ?? Duration.zero
                          : Duration.zero,
                      duration,
                      manifest: manifest,
                      selectedLoaded: selectedLoaded,
                      buffering: buffering,
                      foregroundColor: foregroundColor,
                      showSecondaryActions: showSecondaryActions,
                      transcriptModeActive: transcriptModeActive,
                      onTranscriptToggle: onTranscriptToggle,
                    ),
                  );
                },
              );
            }

            return ValueListenableBuilder<bool>(
              valueListenable: _pageScrollActive,
              builder: (context, scrolling, _) =>
                  buildPositionControls(scrolling),
            );
          },
        );
      }),
    );
  }

  /// [context] is the builder's, deliberately shadowing this state's own.
  ///
  /// The transcript page is a separate route that renders its transport chrome
  /// through these methods. Reading inherited widgets from the player's context
  /// there means reading them from another route's element, which is gone the
  /// moment that route is popped — and a lookup on a deactivated element
  /// returns nothing rather than failing loudly.
  Widget _buildControls(
    BuildContext context,
    LuminaAudioHandler handler,
    bool playing,
    Duration position,
    Duration duration, {
    required ChapterManifest? manifest,
    required bool selectedLoaded,
    required bool buffering,
    required Color foregroundColor,
    bool showSecondaryActions = false,
    required bool transcriptModeActive,
    required VoidCallback? onTranscriptToggle,
  }) {
    final design = context.appDesign;
    final accent = Theme.of(context).colorScheme.primary;
    final controlColor = foregroundColor;
    final cacheColor = context.appTextSecondary.withValues(alpha: 0.46);
    final secondaryColor = context.appTextSecondary;
    final inactiveTrackColor = foregroundColor.withValues(alpha: 0.18);
    final cacheFraction = _cacheFraction(manifest);
    final subtitleRanges = _isPodcast || _isRecordedBook
        ? transcriptCoverage(
            _isPodcast ? _podcastTranscript?.manifest : manifest,
            duration.inMilliseconds,
          )
        : const <({double start, double end})>[];
    final subtitlePercent =
        (subtitleRanges.fold<double>(
                  0,
                  (total, range) => total + range.end - range.start,
                ) *
                100)
            .round();
    final dragValue = _progressDragValue;
    final displayPosition = dragValue != null && cacheFraction > 0
        ? Duration(
            microseconds:
                (duration.inMicroseconds *
                        (dragValue.clamp(0.0, cacheFraction) / cacheFraction))
                    .round(),
          )
        : position;
    final playbackFraction = duration.inMilliseconds <= 0
        ? 0.0
        : (displayPosition.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();
    final hasCachedAudio = (manifest?.readyCount ?? 0) > 0;
    final primaryAction = resolvePlayerPrimaryAudioAction(
      playing: playing,
      playbackRequested: _streamPlaybackRequested || _startingPlayback,
      buffering: buffering,
    );
    // A stalled stream still has something to stop, so only a preparing button
    // with nothing behind it is inert.
    final primaryActionEnabled =
        primaryAction != PlayerPrimaryAudioAction.loading || playing;
    final primaryTooltip = switch (primaryAction) {
      PlayerPrimaryAudioAction.play => context.tr('播放', 'Play', '再生'),
      PlayerPrimaryAudioAction.pause => context.tr('暂停', 'Pause', '一時停止'),
      PlayerPrimaryAudioAction.loading =>
        buffering
            ? context.tr('正在缓冲…', 'Buffering…', 'バッファリング中…')
            : _audioPreparationLabel(),
    };
    final remaining = duration - displayPosition;
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
                trackShape: _isPodcast || _isRecordedBook
                    ? TranscriptSliderTrack(
                        ranges: subtitleRanges,
                        color: accent,
                      )
                    : const RoundedRectSliderTrackShape(),
                trackHeight: 4,
                thumbShape: SliderComponentShape.noThumb,
                disabledThumbColor: hasCachedAudio
                    ? controlColor
                    : Colors.transparent,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                key: const ValueKey('player-cache-playback-progress'),
                semanticFormatterCallback: _isPodcast || _isRecordedBook
                    ? (value) {
                        final percent = cacheFraction <= 0
                            ? 0
                            : (value / cacheFraction * 100).round();
                        return context.tr(
                          '播放进度 $percent%，字幕覆盖 $subtitlePercent%',
                          'Playback $percent%, subtitles cover $subtitlePercent%',
                          '再生位置 $percent%、字幕の範囲 $subtitlePercent%',
                        );
                      }
                    : null,
                value: playbackTrackProgress,
                secondaryTrackValue:
                    animatedCacheFraction < playbackTrackProgress
                    ? playbackTrackProgress
                    : animatedCacheFraction,
                onChangeStart:
                    !selectedLoaded ||
                        duration.inMilliseconds <= 0 ||
                        cacheFraction <= 0
                    ? null
                    : (value) {
                        _progressDragSequence++;
                        setState(
                          () => _progressDragValue = value.clamp(
                            0.0,
                            cacheFraction,
                          ),
                        );
                      },
                onChanged:
                    !selectedLoaded ||
                        duration.inMilliseconds <= 0 ||
                        cacheFraction <= 0
                    ? null
                    : (value) {
                        setState(
                          () => _progressDragValue = value.clamp(
                            0.0,
                            cacheFraction,
                          ),
                        );
                      },
                onChangeEnd:
                    !selectedLoaded ||
                        duration.inMilliseconds <= 0 ||
                        cacheFraction <= 0
                    ? null
                    : (value) {
                        final cachedValue = value.clamp(0.0, cacheFraction);
                        setState(() => _progressDragValue = cachedValue);
                        final sequence = _progressDragSequence;
                        final seekFraction = cachedValue / cacheFraction;
                        final target = Duration(
                          microseconds: (seekFraction * duration.inMicroseconds)
                              .round(),
                        );
                        unawaited(
                          handler.seek(target).whenComplete(() {
                            if (!mounted || sequence != _progressDragSequence) {
                              return;
                            }
                            setState(() => _progressDragValue = null);
                          }),
                        );
                      },
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(displayPosition),
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
            Builder(
              builder: (anchorContext) => AppControlTextButton(
                key: const ValueKey('player-speed-toggle'),
                tooltip: context.tr('播放倍速', 'Playback speed', '再生速度'),
                label: '${_speed.toStringAsFixed(1)}x',
                color: speedIsCustomized ? accent : secondaryColor,
                onPressed: () => _showSpeedMenu(anchorContext),
              ),
            ),
            IconButton(
              key: const ValueKey('player-backward-10-seconds'),
              tooltip: _isPodcast
                  ? context.tr('后退 15 秒', 'Back 15 seconds', '15秒戻る')
                  : context.tr('后退 10 秒', 'Back 10 seconds', '10秒戻る'),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedGoBackward10Sec,
                size: 36,
              ),
              color: foregroundColor,
              disabledColor: secondaryColor.withValues(alpha: 0.42),
              onPressed: !selectedLoaded
                  ? null
                  : () => handler.seek(
                      (_isPodcast
                              ? handler.position
                              : handler.chapterPosition) -
                          Duration(seconds: _isPodcast ? 15 : 10),
                    ),
            ),
            Tooltip(
              message: primaryTooltip,
              child: Semantics(
                button: true,
                label: primaryTooltip,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('player-primary-audio-action'),
                    customBorder: const CircleBorder(),
                    onTap: !primaryActionEnabled
                        ? null
                        : () => unawaited(
                            _handlePrimaryAudioAction(handler, playing),
                          ),
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
                            color: primaryActionEnabled
                                ? foregroundColor
                                : secondaryColor.withValues(alpha: 0.42),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('player-forward-30-seconds'),
              tooltip: context.tr('前进 30 秒', 'Forward 30 seconds', '30秒進む'),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedGoForward30Sec,
                size: 36,
              ),
              color: foregroundColor,
              disabledColor: secondaryColor.withValues(alpha: 0.42),
              onPressed: !selectedLoaded
                  ? null
                  : () => handler.seek(
                      (_isPodcast
                              ? handler.position
                              : handler.chapterPosition) +
                          const Duration(seconds: 30),
                    ),
            ),
            StreamBuilder<SleepTimerState>(
              stream: ref.watch(sleepTimerServiceProvider).stream,
              initialData: ref.watch(sleepTimerServiceProvider).state,
              builder: (context, timerSnapshot) {
                final timerState =
                    timerSnapshot.data ?? const SleepTimerState.off();
                return Builder(
                  builder: (anchorContext) => AppControlIconButton(
                    key: const ValueKey('player-sleep-timer-toggle'),
                    tooltip: timerState.active
                        ? context.tr(
                            '定时关闭：${_sleepTimerLabel(timerState)}',
                            'Sleep timer: ${_sleepTimerLabel(timerState)}',
                            'スリープタイマー：${_sleepTimerLabel(timerState)}',
                          )
                        : context.tr('定时关闭', 'Sleep timer', 'スリープタイマー'),
                    icon: timerState.active
                        ? AppIcons.timer01
                        : AppIcons.timer01,
                    color: timerState.active ? accent : secondaryColor,
                    onPressed: () =>
                        _showSleepTimerMenu(handler, anchorContext),
                  ),
                );
              },
            ),
          ],
        ),
        if (showSecondaryActions) ...[
          SizedBox(height: design.spaceXl),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: design.spaceXxl),
            child: _buildSecondaryActions(
              context,
              handler: handler,
              transcriptModeActive: transcriptModeActive,
              onTranscriptToggle: onTranscriptToggle,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSecondaryActions(
    BuildContext context, {
    required LuminaAudioHandler handler,
    required bool transcriptModeActive,
    required VoidCallback? onTranscriptToggle,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _buildPodcastActionButton(
        context,
        key: const ValueKey('player-transcript-toggle'),
        icon: AppIcons.bubbleChat,
        tooltip: transcriptModeActive
            ? context.tr('返回封面', 'Back to cover', '表紙に戻る')
            : context.tr('转录', 'Transcript', '文字起こし'),
        chip: true,
        active: transcriptModeActive,
        onPressed: onTranscriptToggle,
      ),
      _buildOutputRouteButton(context),
      _buildPodcastActionButton(
        context,
        key: const ValueKey('player-playlist-toggle'),
        icon: AppIcons.leftToRightListBullet,
        tooltip: context.tr('列表', 'Playlist', '再生リスト'),
        onPressed: () => _showPlaylist(handler),
      ),
    ],
  );

  /// The output button hands its slot to the system route picker where one
  /// exists. Elsewhere it keeps the affordance's place in the row, disabled,
  /// rather than offering a tap that could not open anything.
  Widget _buildOutputRouteButton(BuildContext context) {
    final label = context.tr('输出', 'Output', '出力');
    if (!airPlayRoutePickerSupported) {
      return _buildPodcastActionButton(
        context,
        key: const ValueKey('player-output-toggle'),
        icon: AppIcons.airplayLine,
        tooltip: label,
        onPressed: null,
      );
    }
    return Tooltip(
      message: label,
      child: SizedBox(
        key: const ValueKey('player-output-toggle'),
        width: 46,
        height: 34,
        child: AirPlayRoutePickerButton(
          width: 46,
          height: 34,
          color: context.appTextSecondary,
          activeColor: Theme.of(context).colorScheme.primary,
          semanticLabel: label,
        ),
      ),
    );
  }

  /// Plain secondary controls preserve selection and disabled semantics.
  Widget _buildPodcastActionButton(
    BuildContext context, {
    required Key key,
    required AppIconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool chip = false,
    bool active = false,
  }) => AppControlIconButton(
    key: key,
    icon: icon,
    tooltip: tooltip,
    onPressed: onPressed,
    selected: chip ? active : null,
    color: active ? context.appAccent : context.appTextSecondary,
  );

  Future<void> _showPlaylist(LuminaAudioHandler handler) async {
    if (!mounted) return;
    final entries = _isPodcast
        ? _podcastPlaylistEntries(handler)
        : await _bookPlaylistEntries(handler);
    if (!mounted) return;
    final source = _isPodcast ? widget.podcast!.show.title : widget.book.title;
    final emptyLabel = _isPodcast
        ? context.tr('没有更多单集', 'No more episodes', 'これ以上エピソードはありません')
        : context.tr('没有更多章节', 'No more chapters', 'これ以上章はありません');
    await _showPlaylistSheet(
      entries: entries,
      source: source,
      emptyLabel: emptyLabel,
    );
  }

  /// The remaining episodes after the one playing.
  List<_PlaylistEntry> _podcastPlaylistEntries(LuminaAudioHandler handler) {
    final data = widget.podcast!;
    final currentId = handler.currentPodcastEpisodeId ?? _podcastEpisode?.id;
    final currentIndex = data.episodes.indexWhere(
      (episode) => episode.id == currentId,
    );
    final nextEpisodes = currentIndex < 0
        ? data.episodes
        : data.episodes.skip(currentIndex + 1).toList(growable: false);
    return [
      for (final episode in nextEpisodes)
        _PlaylistEntry(
          title: episode.title,
          subtitle:
              '${data.show.title} · '
              '${_fmt(Duration(milliseconds: episode.durationMs))}',
          leading: PodcastArtwork(
            imageUrl: episode.imageUrl ?? data.show.imageUrl,
            size: 50,
            borderRadius: 11,
          ),
          onTap: () => _selectPodcastEpisode(handler, episode),
        ),
    ];
  }

  /// Every other chapter in the book is offered. Selecting an uncached chapter
  /// starts the same cache-and-play flow as opening it from the album page.
  Future<List<_PlaylistEntry>> _bookPlaylistEntries(
    LuminaAudioHandler handler,
  ) async {
    final chapters = await ref
        .read(appDatabaseProvider)
        .getChapters(widget.book.id);
    final currentId = _selectedAudiobookChapter?.id ?? handler.currentChapterId;
    final entries = <_PlaylistEntry>[];
    for (final chapter in chapters) {
      if (chapter.id == currentId) continue;
      entries.add(
        _PlaylistEntry(
          title: chapter.title,
          subtitle: widget.book.title,
          leading: BookCover(
            coverPath: widget.book.coverPath,
            iconSize: 18,
            borderRadius: 11,
          ),
          onTap: () => _selectAudiobookChapter(handler, chapter),
        ),
      );
    }
    return entries;
  }

  Future<void> _showPlaylistSheet({
    required List<_PlaylistEntry> entries,
    required String source,
    required String emptyLabel,
  }) async {
    final design = context.appDesign;

    await showAppSheet<void>(
      context: context,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.62;
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(design.radiusLarge + 10),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    design.spaceLg,
                    0,
                    design.spaceLg,
                    design.spaceMd,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('接下来播放', 'Up next', '次に再生'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: context.appTextPrimary,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                            SizedBox(height: design.spaceXs),
                            Text(
                              source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: design.spaceXxl),
                    child: Text(
                      emptyLabel,
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        design.spaceSm,
                        0,
                        design.spaceSm,
                        design.spaceLg,
                      ),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: design.spaceXs),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                design.radiusMedium,
                              ),
                            ),
                            leading: SizedBox.square(
                              dimension: 50,
                              child: entry.leading,
                            ),
                            title: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontWeight: FontWeight.normal,
                                fontSize: 14.5,
                              ),
                            ),
                            subtitle: Text(
                              entry.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTextSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                            onTap: () async {
                              await entry.onTap();
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectPodcastEpisode(
    LuminaAudioHandler handler,
    drift_db.PodcastEpisode episode,
  ) async {
    final data = widget.podcast;
    if (data == null) return;
    if (episode.id == _podcastEpisode?.id &&
        _isSelectedChapterLoaded(handler)) {
      await handler.play();
      return;
    }
    // Bind before touching the handler: the screen has to show the episode the
    // user picked even while its audio is still being resolved.
    _bindPodcastEpisode(episode);
    _setStartingPlayback(true);
    try {
      var queueIndex = handler.queue.value.indexWhere(
        (item) => item.extras?['podcastEpisodeId'] == episode.id,
      );
      if (queueIndex < 0) {
        // Load starting from the episode that was picked, not the one that was
        // showing, so the queue never opens on the previous episode.
        await _loadPodcastPlayback(handler, episode: episode);
        queueIndex = handler.queue.value.indexWhere(
          (item) => item.extras?['podcastEpisodeId'] == episode.id,
        );
      }
      if (queueIndex < 0) {
        throw StateError('Episode is not available in the playback queue.');
      }
      if (handler.currentPodcastEpisodeId != episode.id) {
        await handler.skipToQueueItem(queueIndex);
      }
      if (!mounted) return;
      await handler.play();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Playback',
        '播放列表切换单集失败 episode=${episode.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar(
          context.tr(
            '无法切换到该单集：$error',
            'Unable to play episode: $error',
            'エピソードを再生できません：$error',
          ),
        );
      }
    } finally {
      if (mounted) _setStartingPlayback(false);
    }
  }

  String _audioPreparationLabel() {
    if (!_isPodcast && _streamPlaybackRequested && !_startingPlayback) {
      return context.tr('正在生成音频…', 'Generating audio…', '音声を生成中…');
    }
    return context.tr('正在加载音频…', 'Loading audio…', '音声を読み込み中…');
  }

  Widget _buildPrimaryAudioGlyph({
    required PlayerPrimaryAudioAction action,
    required Color color,
  }) {
    return switch (action) {
      PlayerPrimaryAudioAction.play => AppIcon(
        AppIcons.play,
        key: const ValueKey(PlayerPrimaryAudioAction.play),
        size: 32,
        color: color,
      ),
      PlayerPrimaryAudioAction.pause => AppIcon(
        AppIcons.pause,
        key: const ValueKey(PlayerPrimaryAudioAction.pause),
        size: 32,
        color: color,
      ),
      PlayerPrimaryAudioAction.loading => SizedBox.square(
        key: const ValueKey(PlayerPrimaryAudioAction.loading),
        dimension: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: color,
          backgroundColor: color.withValues(alpha: 0.18),
        ),
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

  Future<void> _showSpeedMenu(BuildContext anchorContext) async {
    var draft = _speed;
    final selected = await showAppGlassMenu<double>(
      anchorContext: anchorContext,
      items: [
        PopupMenuItem<double>(
          enabled: false,
          height: 92,
          child: StatefulBuilder(
            builder: (context, update) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${context.tr('播放倍速', 'Playback speed', '再生速度')} · ${draft.toStringAsFixed(1)}x',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Slider(
                  min: 0.5,
                  max: 3,
                  divisions: 25,
                  value: draft,
                  onChanged: (value) {
                    update(() => draft = value);
                    unawaited(_applySpeed(value));
                  },
                ),
              ],
            ),
          ),
        ),
        for (final value in const [0.8, 1.0, 1.2, 1.5, 2.0, 2.5])
          PopupMenuItem<double>(
            value: value,
            child: Text('${value.toStringAsFixed(1)}x'),
          ),
      ],
    );
    if (selected != null && mounted) await _applySpeed(selected);
  }

  String _sleepTimerLabel(SleepTimerState state) {
    return switch (state.mode) {
      SleepTimerMode.off => context.tr('关闭', 'Off', 'オフ'),
      SleepTimerMode.duration => context.tr(
        '${state.duration!.inMinutes} 分钟后',
        'In ${state.duration!.inMinutes} minutes',
        '${state.duration!.inMinutes}分後',
      ),
      SleepTimerMode.chapterEnd => context.tr(
        '本章结束',
        'End of chapter',
        '章の終わり',
      ),
    };
  }

  Future<void> _showSleepTimerMenu(
    LuminaAudioHandler handler,
    BuildContext anchorContext,
  ) async {
    final timerService = ref.read(sleepTimerServiceProvider);
    final selected = await showAppGlassMenu<int>(
      anchorContext: anchorContext,
      items: [
        for (final minutes in const [15, 30, 45, 60])
          PopupMenuItem<int>(
            value: minutes,
            child: Text(
              context.tr('$minutes 分钟', '$minutes minutes', '$minutes分'),
            ),
          ),
        PopupMenuItem<int>(
          value: -1,
          child: Text(context.tr('本章结束', 'End of chapter', '章の終わり')),
        ),
        if (timerService.state.active)
          PopupMenuItem<int>(
            value: 0,
            child: Text(context.tr('关闭定时', 'Turn off', 'タイマーをオフ')),
          ),
      ],
    );
    if (selected == null || !mounted) return;
    if (selected == 0) {
      await timerService.cancel();
    } else if (selected == -1) {
      await timerService.scheduleChapterEnd(handler);
    } else {
      await timerService.scheduleDuration(Duration(minutes: selected), handler);
    }
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
}

/// Draws the rounded dashed outline used by the "transcript moved" pointer.
/// A dashed edge marks the row as a signpost rather than one more content card.
class _DashedBorderPainter extends CustomPainter {
  static const double dashLength = 6;
  static const double gapLength = 5;

  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.75),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
                  child: const AppIcon(AppIcons.subtitle),
                ),
                SizedBox(width: design.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          '下载本地字幕模型',
                          'Download transcript model',
                          '文字起こしモデルをダウンロード',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      SizedBox(height: design.spaceXs),
                      Text(
                        context.tr(
                          'Whisper Base · 约 $sizeMb MB',
                          'Whisper Base · about $sizeMb MB',
                          'Whisper Base · 約$sizeMb MB',
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
                'ダウンロード後、ポッドキャスト音声と文字起こしはこの端末で処理され、第三者の文字起こしサービスには送信されません。',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
            if (_downloading) ...[
              SizedBox(height: design.spaceLg),
              Text(
                context.tr(
                  '正在下载 Whisper Base',
                  'Downloading Whisper Base',
                  'Whisper Baseをダウンロード中',
                ),
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
                  'ダウンロードに失敗しました。接続を確認して、もう一度お試しください。\n$_error',
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
                icon: const AppIcon(AppIcons.download01),
                label: Text(
                  context.tr(
                    '下载并生成字幕',
                    'Download and create transcript',
                    'ダウンロードして文字起こしを作成',
                  ),
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
                child: Text(context.tr('暂不', 'Not now', '今はしない')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
