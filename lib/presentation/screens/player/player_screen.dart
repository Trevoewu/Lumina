import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

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
import '../../../services/audiobook_manifest_validator.dart';
import '../../../services/book_playback_queue.dart';
import '../../../services/cover_palette_service.dart';
import '../../../services/generation_orchestrator.dart';
import '../../../services/generation_task_store.dart';
import '../../../services/image_disk_cache.dart';
import '../../../services/lumina_audio_handler.dart';
import '../../../services/podcast_transcription_service.dart';
import '../../../services/sleep_timer_service.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/ai_summary_panel.dart';
import '../../widgets/airplay_route_picker_button.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/podcast_artwork.dart';
import '../../widgets/podcast_link_text.dart';
import '../../widgets/synced_lyrics_list.dart';
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
  static const _transcriptPageTransitionDuration = Duration(milliseconds: 720);
  static const _transcriptPageReverseDuration = Duration(milliseconds: 520);

  late final ScrollController _playerScrollController;

  /// The transcript page owns a separate controller because it is pushed over
  /// the cover route, and one controller cannot be attached to both scroll
  /// views while the Hero transition is in flight.
  late final ScrollController _transcriptScrollController;
  final ValueNotifier<bool> _pageScrollActive = ValueNotifier(false);
  bool? _pendingPageScrollActive;
  bool _pageScrollUpdateScheduled = false;
  double _speed = 1.0;
  double _stickyMiniPlayerTriggerOffset = 360;
  final ValueNotifier<bool> _showStickyMiniPlayer = ValueNotifier(false);
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
  final ValueNotifier<int> _transcriptPageRevision = ValueNotifier<int>(0);
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
  bool _showFullPodcastNotes = false;
  double _readingScrollSpeed = 1.0;
  bool _lyricSweepEnabled = true;
  bool _transcriptPageActive = false;
  bool _transcriptRouteOpen = false;
  Timer? _transcriptPageActivationTimer;
  String? _ambientArtworkUrl;
  Future<Color?>? _ambientSeed;
  drift_db.Chapter? _activeAudiobookChapter;
  int _audiobookSelectionRevision = 0;

  bool get _isPodcast => widget.podcast != null;
  drift_db.Chapter? get _selectedAudiobookChapter =>
      _activeAudiobookChapter ?? widget.initialChapter;

  @override
  void initState() {
    super.initState();
    _playerScrollController = ScrollController(
      onAttach: _handlePageScrollPositionAttached,
      onDetach: _handlePageScrollPositionDetached,
    );
    _transcriptScrollController = ScrollController(
      onAttach: _handlePageScrollPositionAttached,
      onDetach: _handlePageScrollPositionDetached,
    );
    _playerScrollController.addListener(_handlePlayerScroll);
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
    unawaited(_generationSubscription?.cancel());
    unawaited(_podcastEpisodeSubscription?.cancel());
    unawaited(_transcriptionSubscription?.cancel());
    unawaited(_playbackParagraphSubscription?.cancel());
    unawaited(_audiobookMediaItemSubscription?.cancel());
    _transcriptPageActivationTimer?.cancel();
    _playerScrollController
      ..removeListener(_handlePlayerScroll)
      ..dispose();
    _transcriptScrollController.dispose();
    _pageScrollActive.dispose();
    _showStickyMiniPlayer.dispose();
    _controlStateRevision.dispose();
    _transcriptPageRevision.dispose();
    super.dispose();
  }

  void _handlePlayerScroll() {
    if (!_playerScrollController.hasClients) return;
    final position = _playerScrollController.position;
    final offset = position.pixels;
    // Do not swap the header while any part of the full-size player stage is
    // still visible. Besides matching the visual handoff, this avoids an
    // AnimatedSwitcher + page rebuild halfway through the user's cover swipe.
    final trigger = _stickyMiniPlayerTriggerOffset;
    final canScrollPlayerFullyOut = position.maxScrollExtent >= trigger;
    final shouldShow = canScrollPlayerFullyOut && !position.outOfRange
        ? _showStickyMiniPlayer.value
              ? offset >= trigger - 24
              : offset >= trigger
        : false;
    if (shouldShow == _showStickyMiniPlayer.value || !mounted) return;
    _showStickyMiniPlayer.value = shouldShow;
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
      ..._transcriptScrollController.positions,
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

  String get _transcriptArtworkHeroTag =>
      'player-transcript-artwork:${widget.book.id}';

  Future<void> _openTranscriptPage({
    required LuminaAudioHandler handler,
    required String? chapterId,
    required String chapterTitle,
  }) async {
    if (!mounted || (!_isPodcast && chapterId == null)) return;
    _transcriptRouteOpen = true;
    if (_showStickyMiniPlayer.value) {
      _showStickyMiniPlayer.value = false;
    }
    if (_pageScrollActive.value) _pageScrollActive.value = false;

    // The transcript grows while a Podcast is still being transcribed and the
    // handler can load a different episode from under this route, so nothing
    // here may close over the manifest, duration or loaded state captured when
    // the page was pushed. Each rebuild reads them again.
    Widget buildTranscriptPage(BuildContext routeContext) {
      return ValueListenableBuilder<int>(
        valueListenable: _transcriptPageRevision,
        builder: (context, _, _) =>
            _buildOnLoadedMediaChange(handler, (context, selectedLoaded) {
              final manifest = _effectiveManifest(handler);
              return _buildTranscriptRoutePage(
                routeContext: routeContext,
                pageAnimation: ModalRoute.of(routeContext)?.animation,
                handler: handler,
                selectedLoaded: selectedLoaded,
                duration: _selectedDuration(
                  handler,
                  selectedLoaded: selectedLoaded,
                  manifest: manifest,
                ),
                manifest: manifest,
                chapterId: _selectedAudiobookChapter?.id ?? chapterId,
                chapterTitle: _selectedAudiobookChapter?.title ?? chapterTitle,
              );
            }),
      );
    }

    final route = PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'player-transcript'),
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: _transcriptPageTransitionDuration,
      reverseTransitionDuration: _transcriptPageReverseDuration,
      pageBuilder: (routeContext, _, _) => buildTranscriptPage(routeContext),
      // The route only supplies back-stack semantics. It must not animate as
      // a page: the Hero artwork and transcript content own the transition,
      // while both copies of the transport chrome stay on the same baseline.
      transitionsBuilder: (context, animation, _, child) => child,
    );

    _transcriptPageActivationTimer?.cancel();
    _transcriptPageActivationTimer = Timer(
      _transcriptPageTransitionDuration,
      () {
        _transcriptPageActivationTimer = null;
        if (!mounted || !_transcriptRouteOpen) return;
        setState(() => _transcriptPageActive = true);
      },
    );

    final popped = Navigator.of(context).push(route);
    void handleRouteAnimation(AnimationStatus status) {
      if (!mounted || !_transcriptRouteOpen) return;
      if (status == AnimationStatus.reverse) {
        // An iOS edge swipe reveals the cover interactively before the route
        // has popped. Restore it as soon as that gesture begins.
        _transcriptPageActivationTimer?.cancel();
        _transcriptPageActivationTimer = null;
        if (_transcriptPageActive) {
          setState(() => _transcriptPageActive = false);
        }
      } else if (status == AnimationStatus.completed && route.isCurrent) {
        // A short swipe can be cancelled. Hide the covered parent again once
        // the transcript settles back into place.
        if (!_transcriptPageActive) {
          setState(() => _transcriptPageActive = true);
        }
      }
    }

    route.animation?.addStatusListener(handleRouteAnimation);
    await popped;
    route.animation?.removeStatusListener(handleRouteAnimation);
    _transcriptRouteOpen = false;
    _transcriptPageActivationTimer?.cancel();
    _transcriptPageActivationTimer = null;
    if (mounted) {
      setState(() => _transcriptPageActive = false);
    }
  }

  Widget _buildTranscriptRoutePage({
    required BuildContext routeContext,
    required Animation<double>? pageAnimation,
    required LuminaAudioHandler handler,
    required bool selectedLoaded,
    required Duration duration,
    required ChapterManifest? manifest,
    required String? chapterId,
    required String chapterTitle,
  }) {
    final theme = Theme.of(context);
    final topTint = theme.colorScheme.surfaceContainer;
    final pageBottom = theme.colorScheme.surface;
    final middleTint = Color.lerp(topTint, pageBottom, 0.62)!;
    void closePage() {
      _transcriptRouteOpen = false;
      _transcriptPageActivationTimer?.cancel();
      _transcriptPageActivationTimer = null;
      if (mounted) setState(() => _transcriptPageActive = false);
      Navigator.of(routeContext).pop();
    }

    void closePlayer() {
      _transcriptRouteOpen = false;
      _transcriptPageActivationTimer?.cancel();
      _transcriptPageActivationTimer = null;
      if (mounted) setState(() => _transcriptPageActive = false);
      final navigator = Navigator.of(routeContext);
      final transcriptRoute = ModalRoute.of(routeContext);
      if (!navigator.canPop()) return;
      navigator.pop();
      if (transcriptRoute == null) {
        navigator.pop();
        return;
      }
      unawaited(
        transcriptRoute.popped.then<void>((_) {
          if (navigator.mounted) navigator.pop();
        }),
      );
    }

    int? edgeSwipePointer;
    Offset? edgeSwipeStart;
    Offset? edgeSwipeLatest;

    return Listener(
      key: const ValueKey('player-transcript-page'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.position.dx > 28 || edgeSwipePointer != null) return;
        edgeSwipePointer = event.pointer;
        edgeSwipeStart = event.position;
        edgeSwipeLatest = event.position;
      },
      onPointerMove: (event) {
        if (event.pointer == edgeSwipePointer) edgeSwipeLatest = event.position;
      },
      onPointerUp: (event) {
        if (event.pointer != edgeSwipePointer) return;
        final start = edgeSwipeStart;
        final latest = edgeSwipeLatest ?? event.position;
        edgeSwipePointer = null;
        edgeSwipeStart = null;
        edgeSwipeLatest = null;
        if (start != null &&
            latest.dx - start.dx > 72 &&
            (latest.dx - start.dx).abs() > (latest.dy - start.dy).abs() * 1.2 &&
            Navigator.of(routeContext).canPop()) {
          closePage();
        }
      },
      onPointerCancel: (event) {
        if (event.pointer != edgeSwipePointer) return;
        edgeSwipePointer = null;
        edgeSwipeStart = null;
        edgeSwipeLatest = null;
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topTint, middleTint, pageBottom],
            stops: const [0, 0.46, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: _buildPageAmbience()),
            Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pageInset = context.appDesign.pageInsetFor(
                      constraints.maxWidth,
                    );
                    if (_isPodcast) {
                      final data = widget.podcast!;
                      final episode = _podcastEpisode ?? data.episode;
                      return _buildTranscriptModeBody(
                        constraints: constraints,
                        handler: handler,
                        selectedLoaded: selectedLoaded,
                        duration: duration,
                        manifest: manifest,
                        pageInset: pageInset,
                        lyricsChapterId: episode.id,
                        scrollKey: const ValueKey(
                          'podcast-transcript-scroll-view',
                        ),
                        viewportKey: const ValueKey(
                          'podcast-transcript-focus-viewport',
                        ),
                        miniHeader: _buildTranscriptMiniHeader(
                          title: episode.title,
                          subtitle: data.show.title,
                          pageInset: pageInset,
                          trailing: _buildPodcastTranscriptionActions(episode),
                          onClosePlayer: closePlayer,
                        ),
                        belowFold: [
                          _buildPodcastShownotesCard(
                            episode: episode,
                            handler: handler,
                          ),
                          SizedBox(height: context.appDesign.spaceMd),
                          _buildAiSummaryCard(
                            handler: handler,
                            manifest: manifest,
                          ),
                        ],
                        pageAnimation: pageAnimation,
                        onExit: closePage,
                      );
                    }

                    if (chapterId == null) return const SizedBox.shrink();
                    return _buildTranscriptModeBody(
                      constraints: constraints,
                      handler: handler,
                      selectedLoaded: selectedLoaded,
                      duration: duration,
                      manifest: manifest,
                      pageInset: pageInset,
                      lyricsChapterId: chapterId,
                      scrollKey: const ValueKey('book-transcript-scroll-view'),
                      viewportKey: const ValueKey(
                        'book-transcript-focus-viewport',
                      ),
                      miniHeader: _buildTranscriptMiniHeader(
                        title: chapterTitle,
                        subtitle: widget.book.title,
                        pageInset: pageInset,
                        onClosePlayer: closePlayer,
                      ),
                      belowFold: [
                        _buildAiSummaryCard(
                          handler: handler,
                          manifest: manifest,
                        ),
                      ],
                      pageAnimation: pageAnimation,
                      onExit: closePage,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          _transcriptPageRevision.value++;
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
        icon: const Icon(Icons.cloud_outlined),
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
    _followedPodcastEpisodeId = selected.id;

    final database = ref.read(appDatabaseProvider);
    final freshEpisodes = await database.getPodcastEpisodes(data.show.id);
    final episodes = freshEpisodes.isEmpty ? data.episodes : freshEpisodes;

    final playbackUrls = <String, String>{};
    for (final episode in episodes) {
      final localPath = episode.localAudioPath;
      final hasLocal =
          localPath != null &&
          localPath.isNotEmpty &&
          await File(localPath).exists();
      playbackUrls[episode.id] = hasLocal
          ? File(localPath).uri.toString()
          : episode.audioUrl;
      if (episode.id == selected.id) {
        _selectedPodcastLocalAudioAvailable = hasLocal;
      }
    }

    await handler.loadPodcastQueue(
      episodes: [
        for (final episode in episodes)
          PodcastPlaybackSource(
            episodeId: episode.id,
            showId: data.show.id,
            showTitle: data.show.title,
            title: episode.title,
            audioUrl: playbackUrls[episode.id] ?? episode.audioUrl,
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
    final episode = _podcastEpisode;
    final data = widget.podcast;
    if (episode == null ||
        data == null ||
        episode.transcriptStatus == 'complete') {
      return;
    }
    final database = ref.read(appDatabaseProvider);
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
    if (mounted) _transcriptPageRevision.value++;
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
    final preferences = ref.watch(appPreferencesProvider);
    _readingScrollSpeed = preferences.readingScrollSpeed;
    _lyricSweepEnabled = preferences.lyricSweepEnabled;
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    final theme = Theme.of(context);
    final topTint = theme.colorScheme.surfaceContainer;
    final pageBottom = theme.colorScheme.surface;
    final middleTint = Color.lerp(topTint, pageBottom, 0.62)!;
    final isDark = theme.brightness == Brightness.dark;
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
          ],
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
    final viewportContentHeight = math.max(360.0, constraints.maxHeight);
    _stickyMiniPlayerTriggerOffset = viewportContentHeight;
    if (_transcriptPageActive) return const SizedBox.shrink();

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
                  child: Padding(
                    key: const ValueKey('book-cover-focus-viewport'),
                    padding: EdgeInsets.symmetric(horizontal: pageInset),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, artworkConstraints) {
                              return Center(
                                child: _buildTranscriptHeroArtwork(
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
                      transcriptModeActive: false,
                      onTranscriptToggle: onTranscriptTap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
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
                  child: _buildAiSummaryCard(
                    handler: handler,
                    manifest: manifest,
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
    _stickyMiniPlayerTriggerOffset = viewportContentHeight;

    if (_transcriptPageActive) return const SizedBox.shrink();

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
                  child: Padding(
                    key: const ValueKey('podcast-cover-focus-viewport'),
                    padding: EdgeInsets.symmetric(horizontal: pageInset),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, artworkConstraints) {
                              return Center(
                                child: _buildTranscriptHeroArtwork(
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
                      transcriptModeActive: false,
                      onTranscriptToggle: onTranscriptTap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
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
                  child: _buildAiSummaryCard(
                    handler: handler,
                    manifest: manifest,
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
                Icon(
                  Icons.chat_bubble_outline_rounded,
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
                          fontWeight: FontWeight.w700,
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
                Icon(
                  Icons.chevron_right_rounded,
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
  Widget _buildTranscriptModeBody({
    required BoxConstraints constraints,
    required LuminaAudioHandler handler,
    required bool selectedLoaded,
    required Duration duration,
    required ChapterManifest? manifest,
    required double pageInset,
    required String lyricsChapterId,
    required Key scrollKey,
    required Key viewportKey,
    required Widget miniHeader,
    required List<Widget> belowFold,
    required Animation<double>? pageAnimation,
    required VoidCallback onExit,
  }) {
    final design = context.appDesign;
    // The transcript owns the first screen outright, but its chrome stays in
    // fixed bands: the mini player at the top, the lyrics only in the space
    // vacated by the cover, and the transport controls at the bottom.
    final stageHeight = math.max(360.0, constraints.maxHeight);

    return CustomScrollView(
      key: scrollKey,
      controller: _transcriptScrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: stageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTranscriptChromeBand(
                      fromTop: true,
                      child: miniHeader,
                    ),
                    Expanded(
                      child: SizedBox.expand(
                        child: KeyedSubtree(
                          key: viewportKey,
                          child: _buildTranscriptEnteringContent(
                            animation: pageAnimation,
                            // A ShaderMask around a moving ListView forces an
                            // offscreen saveLayer to be rasterized on every
                            // drag frame. Static edge scrims preserve the fade
                            // while the transcript remains independently
                            // composited by the viewport.
                            child: _buildTranscriptEdgeFade(
                              child: _buildSyncedLyrics(
                                chapterId: lyricsChapterId,
                                handler: handler,
                                manifest: manifest,
                                playbackEnabled: selectedLoaded,
                                expanded: true,
                                focusMode: true,
                                listKey: ValueKey(
                                  'transcript-focus:$lyricsChapterId',
                                ),
                              ),
                            ),
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
                          transcriptModeActive: true,
                          onTranscriptToggle: onExit,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            pageInset,
            design.spaceLg,
            pageInset,
            design.spaceXxl,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                for (final child in belowFold) RepaintBoundary(child: child),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptEnteringContent({
    required Widget child,
    required Animation<double>? animation,
  }) {
    if (animation == null) return child;
    final opacity = Tween<double>(begin: 0, end: 1)
        .chain(
          CurveTween(
            curve: const Interval(0.14, 1, curve: Curves.easeOutCubic),
          ),
        )
        .animate(animation);
    final position = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: position, child: child),
    );
  }

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

  /// Memoizes the artwork's dominant color per source. The future has to be
  /// stable across rebuilds or the `FutureBuilder` below would refetch every
  /// frame.
  ///
  /// A podcast cover is a URL that has to come through the image disk cache; a
  /// book cover is already a local file. Both end at the same seed.
  Future<Color?> _pageAmbientSeed() {
    final source = _isPodcast
        ? (_podcastEpisode?.imageUrl ?? widget.podcast?.show.imageUrl)
        : widget.book.coverPath;
    if (source != _ambientArtworkUrl || _ambientSeed == null) {
      _ambientArtworkUrl = source;
      _ambientSeed = source == null || source.isEmpty
          ? Future<Color?>.value(null)
          : _resolveAmbientSeed(source);
    }
    return _ambientSeed!;
  }

  Future<Color?> _resolveAmbientSeed(String source) async {
    try {
      if (!_isPodcast) return await CoverPaletteService.seedForPath(source);
      final file = await appImageDiskCache.load(source);
      return await CoverPaletteService.seedForPath(file.path);
    } catch (_) {
      // A cover that will not resolve is not worth reporting: the page simply
      // keeps its plain background.
      return null;
    }
  }

  /// A very faint wash of the cover's own color across the whole player. The
  /// design deliberately stops short of Apple's dark glass — this only has to
  /// hint that the page belongs to this episode or book.
  Widget _buildPageAmbience() {
    return FutureBuilder<Color?>(
      future: _pageAmbientSeed(),
      builder: (context, snapshot) {
        final seed = snapshot.data;
        if (seed == null) return const SizedBox.shrink();
        final brightness = Theme.of(context).brightness;
        // The raw artwork color is usually far darker than the page, so laying
        // it on at low alpha just greys the background out. Normalizing it to
        // the page's own lightness first is what makes the wash read as the
        // cover's color rather than as dirt.
        final tint = CoverPaletteService.pageTopForSeed(seed, brightness);
        // One hue only. An earlier pass paired the tint with a hue-rotated
        // counterpart for depth, which turned the lower half olive against a
        // red cover — over a whole page any second hue reads as dirt rather
        // than as depth.
        final strength = brightness == Brightness.dark ? 0.34 : 0.4;
        return IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tint.withValues(alpha: strength),
                  tint.withValues(alpha: strength * 0.42),
                  tint.withValues(alpha: 0),
                ],
                stops: const [0, 0.42, 0.88],
              ),
            ),
          ),
        );
      },
    );
  }

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
  List<Widget> _buildPodcastTranscriptionActions(
    drift_db.PodcastEpisode episode,
  ) {
    if (_transcribingPodcast) {
      return [
        IconButton(
          key: const ValueKey('podcast-transcript-pause'),
          tooltip: _pausingPodcastTranscription
              ? context.tr('正在暂停…', 'Pausing…', '一時停止中…')
              : context.tr('暂停转写', 'Pause transcription', '文字起こしを一時停止'),
          icon: _pausingPodcastTranscription
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.pause_circle_outline),
          onPressed: _pausingPodcastTranscription
              ? null
              : _pausePodcastTranscription,
        ),
      ];
    }
    if ((_podcastTranscript?.timingCount ?? 0) > 0) {
      return [
        IconButton(
          key: const ValueKey('podcast-transcript-restart'),
          tooltip: _transcriptPaused(episode)
              ? context.tr('继续转写', 'Resume transcription', '文字起こしを再開')
              : context.tr('重新转写', 'Transcribe again', '文字起こしをやり直す'),
          icon: Icon(
            _transcriptPaused(episode)
                ? Icons.play_circle_outline
                : Icons.auto_awesome_rounded,
          ),
          onPressed: _transcriptPaused(episode)
              ? _startPodcastTranscription
              : _restartPodcastTranscription,
        ),
      ];
    }
    return const [];
  }

  /// The collapsed identity strip at the top of transcript mode. [trailing]
  /// carries whatever actions belong to the source — a podcast adds its
  /// transcription controls, a book has none.
  Widget _buildTranscriptMiniHeader({
    required String title,
    required String subtitle,
    required double pageInset,
    List<Widget> trailing = const [],
    required VoidCallback onClosePlayer,
  }) {
    final design = context.appDesign;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        pageInset,
        design.spaceSm,
        pageInset,
        design.spaceXl,
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('player-transcript-close-player'),
            tooltip: context.tr('收起播放器', 'Close player', 'プレーヤーを閉じる'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: context.appTextPrimary,
            onPressed: onClosePlayer,
          ),
          _buildTranscriptHeroArtwork(58, borderRadius: design.radiusMedium),
          SizedBox(width: design.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: design.spaceXs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...trailing,
        ],
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
                      '文字起こしの参照 ${citation.label}',
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
                    child: Text(context.tr('关闭', 'Close', '閉じる')),
                  ),
                ),
                if (canPlay) ...[
                  SizedBox(width: sheetContext.appDesign.spaceSm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.play_arrow_rounded),
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
            icon: Icons.notes_rounded,
            title: context.tr('节目笔记', 'Shownotes', '番組ノート'),
          ),
          SizedBox(height: context.appDesign.spaceMd),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: PodcastLinkText(
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
              onPressed: () {
                setState(() => _showFullPodcastNotes = !_showFullPodcastNotes);
                _transcriptPageRevision.value++;
              },
              iconAlignment: IconAlignment.end,
              icon: Icon(
                _showFullPodcastNotes
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                _showFullPodcastNotes
                    ? context.tr('收起', 'Show less', '折りたたむ')
                    : context.tr('查看完整笔记', 'Show full notes', '番組ノートをすべて表示'),
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
    if (_transcriptPageActive) {
      return SizedBox(height: design.toolbarHeight);
    }
    // Keep the toolbar's slot fixed while its content changes. Transcript is
    // a separate route now, so its own mini header and chrome own their input.
    return SizedBox(
      height: design.toolbarHeight,
      child: ClipRect(
        child: ValueListenableBuilder<bool>(
          valueListenable: _showStickyMiniPlayer,
          builder: (context, showStickyMiniPlayer, _) => AnimatedSwitcher(
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
            child: showStickyMiniPlayer
                ? handlerAsync.maybeWhen(
                    data: (handler) => _buildStickyMiniPlayerHeader(handler),
                    orElse: _buildDefaultPlayerHeader,
                  )
                : _buildDefaultPlayerHeader(),
          ),
        ),
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
            tooltip: context.tr('收起播放器', 'Close player', 'プレーヤーを閉じる'),
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
            tooltip: context.tr('更多选项', 'More options', 'その他のオプション'),
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
        _selectedAudiobookChapter?.title ??
        handler.mediaItem.valueOrNull?.title ??
        widget.book.title;
    final sourceTitle = _isPodcast
        ? widget.podcast!.show.title
        : widget.book.title;
    return StreamBuilder<({bool playing, bool buffering})>(
      key: const ValueKey('player-sticky-mini-player'),
      stream: handler.playbackState.map(_transportState).distinct(),
      initialData: _transportState(handler.playbackState.value),
      builder: (context, playbackSnapshot) {
        final transport =
            playbackSnapshot.data ?? (playing: false, buffering: false);
        final selectedLoaded = _isSelectedChapterLoaded(handler);
        final playing = selectedLoaded && transport.playing;
        final buffering = selectedLoaded && transport.buffering;
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
                    tooltip: context.tr('收起播放器', 'Close player', 'プレーヤーを閉じる'),
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
                        buffering: buffering,
                      );
                      final tooltip = switch (action) {
                        PlayerPrimaryAudioAction.play => context.tr(
                          '播放',
                          'Play',
                          '再生',
                        ),
                        PlayerPrimaryAudioAction.pause => context.tr(
                          '暂停',
                          'Pause',
                          '一時停止',
                        ),
                        PlayerPrimaryAudioAction.loading => context.tr(
                          '正在准备音频',
                          'Preparing audio',
                          '音声を準備中',
                        ),
                      };
                      return IconButton(
                        key: const ValueKey('player-sticky-mini-player-action'),
                        tooltip: tooltip,
                        icon: _buildPrimaryAudioGlyph(
                          action: action,
                          color: context.appTextPrimary,
                        ),
                        onPressed:
                            action == PlayerPrimaryAudioAction.loading &&
                                !playing
                            ? null
                            : () => unawaited(
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
    return RepaintBoundary(
      key: const ValueKey('player-artwork-repaint-boundary'),
      child: SizedBox.square(
        key: const ValueKey('player-artwork'),
        dimension: size,
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

  Widget _buildTranscriptHeroArtwork(
    double size, {
    required double borderRadius,
  }) {
    return Hero(
      tag: _transcriptArtworkHeroTag,
      transitionOnUserGestures: true,
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      child: _buildArtwork(size, borderRadius: borderRadius),
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
                          ? context.tr('正在暂停…', 'Pausing…', '一時停止中…')
                          : context.tr('暂停', 'Pause', '一時停止'),
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
                      '${transcript?.timingCount ?? 0}件をキャッシュ済み',
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
            : context.tr('正在准备音频', 'Preparing audio', '音声を準備中'),
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
            IconButton(
              tooltip: context.tr('播放倍速', 'Playback speed', '再生速度'),
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
                  color: context.appTextPrimary,
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
                return IconButton(
                  tooltip: timerState.active
                      ? context.tr(
                          '定时关闭：${_sleepTimerLabel(timerState)}',
                          'Sleep timer: ${_sleepTimerLabel(timerState)}',
                          'スリープタイマー：${_sleepTimerLabel(timerState)}',
                        )
                      : context.tr('定时关闭', 'Sleep timer', 'スリープタイマー'),
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
        if (showSecondaryActions) ...[
          SizedBox(height: design.spaceXl),
          Padding(
            // The three actions sit further in than the transport row above
            // them, so they read as a secondary tier rather than as more
            // playback controls. This is on top of the page gutter the
            // controls already carry, landing them at the mock's inset.
            padding: EdgeInsets.symmetric(horizontal: design.spaceXxl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPodcastActionButton(
                  context,
                  key: const ValueKey('player-transcript-toggle'),
                  icon: Icons.chat_bubble_outline_rounded,
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
                  icon: Icons.format_list_bulleted_rounded,
                  tooltip: context.tr('列表', 'Playlist', '再生リスト'),
                  onPressed: () => _showPlaylist(handler),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The output button hands its slot to the system route picker where one
  /// exists. Elsewhere it keeps the affordance's place in the row, disabled,
  /// rather than offering a tap that could not open anything.
  Widget _buildOutputRouteButton(BuildContext context) {
    final label = context.tr('输出', 'Output', '出力');
    if (!airPlayRoutePickerSupported) {
      return _buildPodcastActionButton(
        context,
        key: const ValueKey('player-output-toggle'),
        icon: Icons.airplay_rounded,
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

  /// An icon-only secondary action. [chip] gives the button a standing pill so
  /// the transcript toggle reads as a switch rather than a one-shot action;
  /// [active] deepens that pill while transcript mode is on. A null
  /// [onPressed] renders the icon as unavailable.
  Widget _buildPodcastActionButton(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool chip = false,
    bool active = false,
  }) {
    final design = context.appDesign;
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(design.radiusMedium);
    final foreground = !enabled
        ? context.appTextSecondary.withValues(alpha: 0.4)
        : active
        ? context.appTextPrimary
        : context.appTextSecondary;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: InkWell(
          key: key,
          onTap: onPressed,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chip
                  ? context.appTextPrimary.withValues(
                      alpha: active ? 0.09 : 0.06,
                    )
                  : Colors.transparent,
              borderRadius: radius,
            ),
            child: Icon(icon, size: 21, color: foreground),
          ),
        ),
      ),
    );
  }

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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
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
                  padding: EdgeInsets.only(
                    top: design.spaceMd,
                    bottom: design.spaceSm,
                  ),
                  child: Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.appTextPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    design.spaceLg,
                    design.spaceSm,
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
                                    fontWeight: FontWeight.w800,
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
                      IconButton(
                        tooltip: context.tr('关闭', 'Close', '閉じる'),
                        icon: const Icon(Icons.close_rounded),
                        color: context.appTextSecondary,
                        onPressed: () => Navigator.of(sheetContext).pop(),
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
                                fontWeight: FontWeight.w600,
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
      PlayerPrimaryAudioAction.loading => Icon(
        key: const ValueKey(PlayerPrimaryAudioAction.loading),
        Icons.hourglass_top_rounded,
        size: 28,
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
                          context.tr('播放倍速', 'Playback speed', '再生速度'),
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
                  context.tr('定时关闭', 'Sleep timer', 'スリープタイマー'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
                SizedBox(height: context.appDesign.spaceXs),
                Text(
                  context.tr(
                    '当前：${_sleepTimerLabel(timerService.state)}',
                    'Current: ${_sleepTimerLabel(timerService.state)}',
                    '現在：${_sleepTimerLabel(timerService.state)}',
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
                          context.tr(
                            '$minutes 分钟',
                            '$minutes minutes',
                            '$minutes分',
                          ),
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
                      label: Text(
                        context.tr('本章结束', 'End of chapter', '章の終わり'),
                      ),
                      onPressed: () async {
                        await timerService.scheduleChapterEnd(handler);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                    if (timerService.state.active)
                      ActionChip(
                        label: Text(context.tr('关闭定时', 'Turn off', 'タイマーをオフ')),
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
                  child: const Icon(Icons.subtitles_rounded),
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
                          fontWeight: FontWeight.w800,
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
                icon: const Icon(Icons.download_rounded),
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
