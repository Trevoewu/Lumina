import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../widgets/book_cover.dart';

Color _accentTint(BuildContext context, double amount) {
  return Color.lerp(
    AppColors.background,
    Theme.of(context).colorScheme.primary,
    amount,
  )!;
}

String? _themeFontFamily(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.fontFamily;
}

class PlayerScreen extends ConsumerStatefulWidget {
  final drift_db.Book book;
  final drift_db.Chapter? initialChapter;

  const PlayerScreen({super.key, required this.book, this.initialChapter});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  String? _highlightParagraphId;
  StreamSubscription? _paragraphSub;
  final ScrollController _lyricsScrollController = ScrollController();
  final Map<String, GlobalKey> _paragraphKeys = {};
  List<drift_db.Paragraph> _inlineLyricsParagraphs = const [];
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAudioHandler();
      _loadPlaybackSpeed();
    });
  }

  Future<void> _loadPlaybackSpeed() async {
    final value = await ref.read(appDatabaseProvider).getSetting('playback_speed');
    final speed = (double.tryParse(value ?? '') ?? 1.0).clamp(0.5, 3.0);
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await handler.setSpeed(speed);
    if (!mounted) return;
    setState(() => _speed = speed.toDouble());
  }

  void _listenToAudioHandler() async {
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    final currentParagraphId = handler.currentParagraphId;
    if (mounted && currentParagraphId != null) {
      setState(() => _highlightParagraphId = currentParagraphId);
      _scrollToParagraph(currentParagraphId);
    }

    _paragraphSub = handler.currentParagraphIdStream.listen((paragraphId) {
      if (!mounted) return;
      setState(() => _highlightParagraphId = paragraphId);
      _scrollToParagraph(paragraphId);
    });
  }

  void _scrollToParagraph(String? paragraphId) {
    if (paragraphId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = _inlineLyricsParagraphs.indexWhere(
        (paragraph) => paragraph.id == paragraphId,
      );
      final context = _paragraphKeys[paragraphId]?.currentContext;
      if (context == null && index >= 0 && _lyricsScrollController.hasClients) {
        final target = (index * 84.0).clamp(
          0.0,
          _lyricsScrollController.position.maxScrollExtent,
        );
        _lyricsScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.2, // 靠上对齐
      );
    });
  }

  @override
  void dispose() {
    _paragraphSub?.cancel();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    final topTint = _accentTint(context, 0.22);

    return Scaffold(
      backgroundColor: Colors.transparent, // Let the gradient show through
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topTint, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        size: 32,
                        color: Colors.white,
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
                          color: Colors.white70,
                          fontFamily: _themeFontFamily(context),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
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

                        final playing = state?.playing ?? false;
                        final duration = handler.chapterDuration;
                        final currentChapterId =
                            currentItem?.extras?['chapterId'] as String?;

                        return Column(
                          children: [
                            // 1. Cover Art (Perfect Square)
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
                                        color: AppColors.surfaceHighlight,
                                        borderRadius: BorderRadius.circular(12),
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

                            // 2. Song Title & Author
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
                                          currentItem?.title ??
                                              widget.initialChapter?.title ??
                                              'Unknown Chapter',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.book.author ??
                                              'Unknown Author',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: AppColors.textSecondary,
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

                            // 3. Progress Bar & Controls
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
                                    positionSnapshot.data ?? Duration.zero,
                                    duration,
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 4. Lyrics View
                            Expanded(
                              flex: 5,
                              child: _buildLyricsCard(
                                currentChapterId ?? widget.initialChapter?.id,
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
  }

  Widget _buildControls(
    dynamic handler,
    bool playing,
    Duration position,
    Duration duration,
  ) {
    final accent = Theme.of(context).colorScheme.primary;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.textPrimary,
            inactiveTrackColor: AppColors.surfaceHighlight,
            thumbColor: AppColors.textPrimary,
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: progress,
            onChanged: (value) {
              final seekMs = (value * duration.inMilliseconds).round();
              handler.seek(Duration(milliseconds: seekMs));
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _fmt(position),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              _fmt(duration),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: '播放倍速',
              icon: Text(
                '${_speed.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              color: AppColors.textSecondary,
              onPressed: _showSpeedSheet,
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 36),
              color: AppColors.textPrimary,
              onPressed: handler.skipToPrevious,
            ),
            GestureDetector(
              onTap: playing ? handler.pause : handler.play,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 32,
                  color: Colors.black,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 36),
              color: AppColors.textPrimary,
              onPressed: handler.skipToNext,
            ),
            IconButton(
              icon: const Icon(Icons.repeat),
              color: AppColors.textSecondary,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLyricsCard(String? chapterId) {
    if (chapterId == null) return const SizedBox.shrink();

    final db = ref.watch(appDatabaseProvider);
    final cardColor = _accentTint(context, 0.3);
    final fontFamily = _themeFontFamily(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lyrics',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                      fontFamily: fontFamily,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.share_outlined,
                          size: 20,
                          color: Colors.white70,
                        ),
                        tooltip: '分享歌词',
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_full,
                          size: 20,
                          color: Colors.white70,
                        ),
                        tooltip: '全屏歌词',
                        onPressed: () => _showFullScreenLyrics(chapterId),
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
                  _inlineLyricsParagraphs = paragraphs;
                  if (paragraphs.isEmpty) {
                    return const Center(
                      child: Text(
                        '无歌词',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  if (_highlightParagraphId != null) {
                    _scrollToParagraph(_highlightParagraphId);
                  }

                  return ListView.builder(
                    controller: _lyricsScrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                    itemCount: paragraphs.length,
                    itemBuilder: (context, index) {
                      final paragraph = paragraphs[index];
                      final highlighted = paragraph.id == _highlightParagraphId;
                      _paragraphKeys[paragraph.id] ??= GlobalKey();

                      return InkWell(
                        key: _paragraphKeys[paragraph.id],
                        onTap: () => _playParagraph(paragraph),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: highlighted ? 24 : 18,
                              fontWeight: highlighted
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: highlighted
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              height: 1.4,
                              fontFamily: fontFamily,
                            ),
                            child: Text(paragraph.content),
                          ),
                        ),
                      );
                    },
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

  Future<void> _playParagraph(drift_db.Paragraph paragraph) async {
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await handler.playFromParagraph(paragraph.id);
  }

  void _showSpeedSheet() {
    var draft = _speed;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
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
                        const Expanded(
                          child: Text(
                            '播放倍速',
                            style: TextStyle(
                              color: AppColors.textPrimary,
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
                        inactiveTrackColor: AppColors.surfaceHighlight,
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
                                  : AppColors.textPrimary,
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

  void _showFullScreenLyrics(String chapterId) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenLyricsSheet(
          bookTitle: widget.book.title,
          chapterId: chapterId,
        ),
      ),
    );
  }
}

class _FullScreenLyricsSheet extends ConsumerStatefulWidget {
  final String bookTitle;
  final String chapterId;

  const _FullScreenLyricsSheet({
    required this.bookTitle,
    required this.chapterId,
  });

  @override
  ConsumerState<_FullScreenLyricsSheet> createState() =>
      _FullScreenLyricsSheetState();
}

class _FullScreenLyricsSheetState
    extends ConsumerState<_FullScreenLyricsSheet> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _paragraphKeys = {};
  List<drift_db.Paragraph> _lyricsParagraphs = const [];
  StreamSubscription<String?>? _paragraphSub;
  String? _highlightParagraphId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAudioHandler();
    });
  }

  Future<void> _listenToAudioHandler() async {
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    final currentParagraphId = handler.currentParagraphId;

    if (mounted && currentParagraphId != null) {
      setState(() => _highlightParagraphId = currentParagraphId);
      _scrollToParagraph(currentParagraphId);
    }

    _paragraphSub = handler.currentParagraphIdStream.listen((paragraphId) {
      if (!mounted || paragraphId == null) return;
      setState(() => _highlightParagraphId = paragraphId);
      _scrollToParagraph(paragraphId);
    });
  }

  void _scrollToParagraph(String paragraphId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = _lyricsParagraphs.indexWhere(
        (paragraph) => paragraph.id == paragraphId,
      );
      final context = _paragraphKeys[paragraphId]?.currentContext;
      if (context == null && index >= 0 && _scrollController.hasClients) {
        final target = (index * 92.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.24,
      );
    });
  }

  @override
  void dispose() {
    _paragraphSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final handlerAsync = ref.watch(luminaAudioHandlerProvider);
    final topTint = _accentTint(context, 0.42);
    final fontFamily = _themeFontFamily(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        height: MediaQuery.sizeOf(context).height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topTint, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
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
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Lyrics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<drift_db.Paragraph>>(
                  future: db.getParagraphs(widget.chapterId),
                  builder: (context, snapshot) {
                    final paragraphs =
                        snapshot.data ?? const <drift_db.Paragraph>[];
                    _lyricsParagraphs = paragraphs;
                    if (paragraphs.isEmpty) {
                      return const Center(
                        child: Text(
                          '无歌词',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    if (_highlightParagraphId != null) {
                      _scrollToParagraph(_highlightParagraphId!);
                    }

                    return handlerAsync.when(
                      loading: () => _LyricsList(
                        paragraphs: paragraphs,
                        highlightedParagraphId: _highlightParagraphId,
                        paragraphKeys: _paragraphKeys,
                        scrollController: _scrollController,
                        onTap: (_) {},
                      ),
                      error: (_, _) => _LyricsList(
                        paragraphs: paragraphs,
                        highlightedParagraphId: _highlightParagraphId,
                        paragraphKeys: _paragraphKeys,
                        scrollController: _scrollController,
                        onTap: (_) {},
                      ),
                      data: (handler) => _LyricsList(
                        paragraphs: paragraphs,
                        highlightedParagraphId: _highlightParagraphId,
                        paragraphKeys: _paragraphKeys,
                        scrollController: _scrollController,
                        onTap: (paragraph) async {
                          await handler.playFromParagraph(paragraph.id);
                          if (!mounted) return;
                          setState(() => _highlightParagraphId = paragraph.id);
                          _scrollToParagraph(paragraph.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricsList extends StatelessWidget {
  final List<drift_db.Paragraph> paragraphs;
  final String? highlightedParagraphId;
  final Map<String, GlobalKey> paragraphKeys;
  final ScrollController scrollController;
  final ValueChanged<drift_db.Paragraph> onTap;

  const _LyricsList({
    required this.paragraphs,
    required this.highlightedParagraphId,
    required this.paragraphKeys,
    required this.scrollController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fontFamily = _themeFontFamily(context);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
      itemCount: paragraphs.length,
      itemBuilder: (context, index) {
        final paragraph = paragraphs[index];
        final highlighted = paragraph.id == highlightedParagraphId;

        return InkWell(
          key: paragraphKeys.putIfAbsent(paragraph.id, GlobalKey.new),
          onTap: () => onTap(paragraph),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: highlighted ? 28 : 22,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
                color: highlighted
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.42),
                height: 1.35,
                fontFamily: fontFamily,
              ),
              child: Text(paragraph.content),
            ),
          ),
        );
      },
    );
  }
}
