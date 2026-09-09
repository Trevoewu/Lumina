import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../widgets/app_back_button.dart';
import '../../widgets/design_system/macos_window_toolbar.dart';
import '../player/player_screen.dart';
import 'widgets/reader_appearance_sheet.dart';
import 'widgets/reader_audio_bar.dart';
import 'widgets/reader_paragraph_view.dart';
import 'widgets/reader_toc_sheet.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  final drift_db.Book book;
  final drift_db.Chapter? initialChapter;
  final int initialParagraphIndex;

  const BookReaderScreen({
    super.key,
    required this.book,
    this.initialChapter,
    this.initialParagraphIndex = 0,
  });

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _paragraphKeys = {};

  List<drift_db.Chapter> _chapters = [];
  drift_db.Chapter? _currentChapter;
  List<drift_db.Paragraph> _paragraphs = [];

  bool _loading = true;
  bool _barsVisible = true;
  bool _userScrolledAway = false;
  int? _lastScrolledPlayingIndex;

  StreamSubscription<dynamic>? _audioSubscription;

  @override
  void initState() {
    super.initState();
    _loadBookData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // If the user scrolls manually while audio is playing, note they moved away
    final handler = ref.read(luminaAudioHandlerProvider).asData?.value;
    if (handler != null &&
        handler.currentBookId == widget.book.id &&
        handler.currentChapterId == _currentChapter?.id) {
      final playingIndex = handler.currentParagraphIndex;
      if (playingIndex != null && _lastScrolledPlayingIndex != null) {
        if (!_userScrolledAway && _scrollController.position.isScrollingNotifier.value) {
          setState(() => _userScrolledAway = true);
        }
      }
    }
  }

  Future<void> _saveProgress() async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    try {
      await ref.read(appDatabaseProvider).updateReadingProgress(
            widget.book.id,
            chapterId: chapter.id,
            paragraphIndex: _lastScrolledPlayingIndex ?? widget.initialParagraphIndex,
          );
    } catch (_) {}
  }

  Future<void> _loadBookData() async {
    setState(() => _loading = true);
    final database = ref.read(appDatabaseProvider);
    final chapters = await database.getChapters(widget.book.id);

    drift_db.Chapter? targetChapter = widget.initialChapter;
    if (targetChapter == null && chapters.isNotEmpty) {
      final lastChapterId = widget.book.currentChapterId;
      targetChapter = chapters.firstWhere(
        (c) => c.id == lastChapterId,
        orElse: () => chapters.first,
      );
    }

    _chapters = chapters;
    await _loadChapter(targetChapter ?? chapters.firstOrNull, initialIndex: widget.initialParagraphIndex);
  }

  Future<void> _loadChapter(drift_db.Chapter? chapter, {int initialIndex = 0}) async {
    if (chapter == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final database = ref.read(appDatabaseProvider);
    final paragraphs = await database.getParagraphs(chapter.id);

    _paragraphKeys.clear();
    for (var i = 0; i < paragraphs.length; i++) {
      _paragraphKeys[i] = GlobalKey();
    }

    if (mounted) {
      setState(() {
        _currentChapter = chapter;
        _paragraphs = paragraphs;
        _loading = false;
        _userScrolledAway = false;
      });
    }

    // Scroll to initial index if specified
    if (initialIndex > 0 && paragraphs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToParagraph(initialIndex, smooth: false);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }

    _saveProgress();
  }

  void _scrollToParagraph(int index, {bool smooth = true, double alignment = 0.32}) {
    final key = _paragraphKeys[index];
    final targetContext = key?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      Scrollable.ensureVisible(
        targetContext,
        duration: smooth ? const Duration(milliseconds: 350) : Duration.zero,
        curve: Curves.easeOutCubic,
        alignment: alignment,
      );
      _lastScrolledPlayingIndex = index;
    }
  }

  void _toggleBars() {
    setState(() => _barsVisible = !_barsVisible);
  }

  void _openPlayer({drift_db.Chapter? chapter, bool autoplay = true}) {
    final targetChapter = chapter ?? _currentChapter;
    if (targetChapter == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          book: widget.book,
          initialChapter: targetChapter,
          autoplayOnOpen: autoplay,
        ),
      ),
    );
  }

  Future<void> _openTocSheet() async {
    final chosen = await showReaderTocSheet(
      context: context,
      bookTitle: widget.book.title,
      chapters: _chapters,
      currentChapterId: _currentChapter?.id ?? '',
    );
    if (chosen != null && chosen.id != _currentChapter?.id) {
      _loadChapter(chosen);
    }
  }

  void _goToPreviousChapter() {
    final current = _currentChapter;
    if (current == null) return;
    final currentIndex = _chapters.indexWhere((c) => c.id == current.id);
    if (currentIndex > 0) {
      _loadChapter(_chapters[currentIndex - 1]);
    }
  }

  void _goToNextChapter() {
    final current = _currentChapter;
    if (current == null) return;
    final currentIndex = _chapters.indexWhere((c) => c.id == current.id);
    if (currentIndex >= 0 && currentIndex < _chapters.length - 1) {
      _loadChapter(_chapters[currentIndex + 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

    // Audio sync
    final handler = ref.watch(luminaAudioHandlerProvider).asData?.value;
    final isThisBook = handler?.currentBookId == widget.book.id;
    final isThisChapter = isThisBook && handler?.currentChapterId == _currentChapter?.id;
    final playingParagraphIndex = isThisChapter ? handler?.currentParagraphIndex : null;

    // Follow audio progression if user hasn't explicitly scrolled away
    if (playingParagraphIndex != null &&
        playingParagraphIndex != _lastScrolledPlayingIndex &&
        !_userScrolledAway) {
      _lastScrolledPlayingIndex = playingParagraphIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToParagraph(playingParagraphIndex);
      });
    }

    final currentIndex = _currentChapter != null
        ? _chapters.indexWhere((c) => c.id == _currentChapter!.id)
        : -1;
    final hasPrevChapter = currentIndex > 0;
    final hasNextChapter = currentIndex >= 0 && currentIndex < _chapters.length - 1;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: context.appAccent),
            )
          : Stack(
              children: [
                // ── Reader Body (Continuous vertical scroll) ───────────────────
                GestureDetector(
                  onTap: _toggleBars,
                  behavior: HitTestBehavior.translucent,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MediaQuery.paddingOf(context).top + 72,
                      inset,
                      MediaQuery.paddingOf(context).bottom + 120,
                    ),
                    itemCount: _paragraphs.length + 2, // Header + paragraphs + Chapter footer
                    itemBuilder: (context, index) {
                      // 0: Chapter Title Header
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_currentChapter != null)
                                Text(
                                  'CHAPTER ${_currentChapter!.chapterIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.appAccent,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                _currentChapter?.title ?? widget.book.title,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: context.appTextPrimary,
                                      height: 1.25,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Divider(
                                color: scheme.onSurface.withValues(alpha: 0.12),
                                thickness: 0.8,
                              ),
                            ],
                          ),
                        );
                      }

                      // Chapter Footer: Prev / Next Chapter buttons
                      if (index == _paragraphs.length + 1) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 36, bottom: 48),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (hasPrevChapter)
                                OutlinedButton.icon(
                                  onPressed: _goToPreviousChapter,
                                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                  label: Text(context.tr('上一章', 'Previous', '前へ')),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: context.appTextPrimary,
                                    side: BorderSide(
                                      color: scheme.onSurface.withValues(alpha: 0.2),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              if (hasNextChapter)
                                FilledButton.icon(
                                  onPressed: _goToNextChapter,
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                  label: Text(context.tr('下一章', 'Next Chapter', '次へ')),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: context.appAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                        );
                      }

                      final paragraphIndex = index - 1;
                      final paragraph = _paragraphs[paragraphIndex];
                      final isPlayingThis = playingParagraphIndex == paragraphIndex;

                      return KeyedSubtree(
                        key: _paragraphKeys[paragraphIndex],
                        child: ReaderParagraphView(
                          paragraph: paragraph,
                          isPlaying: isPlayingThis,
                          onPlayFromHere: () {
                            _openPlayer(
                              chapter: _currentChapter,
                              autoplay: true,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                // ── Top Navigation Bar (Immersive Floating) ─────────────────────
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  top: _barsVisible ? 0 : -90,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      isMac ? 0 : 12,
                      isMac ? 0 : MediaQuery.paddingOf(context).top + 4,
                      isMac ? 12 : 12,
                      isMac ? 0 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.appBackground.withValues(alpha: 0.94),
                      border: Border(
                        bottom: BorderSide(
                          color: isMac
                              ? AppColors.divider
                              : scheme.onSurface.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isMac
                        ? SizedBox(
                            height: 48.0,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: macosTopControlsReservedWidth,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _currentChapter?.title ??
                                                widget.book.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: context.appTextPrimary,
                                            ),
                                          ),
                                          if (_currentChapter != null)
                                            Text(
                                              '${_currentChapter!.chapterIndex + 1} / ${_chapters.length}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: context.appTextSecondary,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.format_size_rounded,
                                      ),
                                      color: context.appTextPrimary,
                                      tooltip: context.tr(
                                        '阅读排版',
                                        'Typography',
                                        '読書設定',
                                      ),
                                      onPressed: () =>
                                          showReaderAppearanceSheet(context),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.menu_book_rounded,
                                      ),
                                      color: context.appTextPrimary,
                                      tooltip: context.tr(
                                        '目录',
                                        'Table of Contents',
                                        '目次',
                                      ),
                                      onPressed: _openTocSheet,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.headphones_outlined,
                                      ),
                                      color: context.appAccent,
                                      tooltip: context.tr(
                                        '听书播放器',
                                        'Player',
                                        '再生プレーヤー',
                                      ),
                                      onPressed: () => _openPlayer(
                                        chapter: _currentChapter,
                                        autoplay: false,
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  top: 6.0,
                                  left: 0,
                                  child: MacosWindowToolbar(
                                    isSidebarVisible: true,
                                    onToggleSidebar: _openTocSheet,
                                    canGoBack: true,
                                    onBack: () =>
                                        Navigator.of(context).maybePop(),
                                    canGoForward: false,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              const AppBackButton(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _currentChapter?.title ?? widget.book.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: context.appTextPrimary,
                                      ),
                                    ),
                                    if (_currentChapter != null)
                                      Text(
                                        '${_currentChapter!.chapterIndex + 1} / ${_chapters.length}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.appTextSecondary,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Aa Appearance settings
                              IconButton(
                                icon: const Icon(Icons.format_size_rounded),
                                color: context.appTextPrimary,
                                tooltip: context.tr('阅读排版', 'Typography', '読書設定'),
                                onPressed: () => showReaderAppearanceSheet(context),
                              ),
                              // TOC Sheet
                              IconButton(
                                icon: const Icon(Icons.menu_book_rounded),
                                color: context.appTextPrimary,
                                tooltip: context.tr('目录', 'Table of Contents', '目次'),
                                onPressed: _openTocSheet,
                              ),
                              // Listen in Full Player
                              IconButton(
                                icon: const Icon(Icons.headphones_outlined),
                                color: context.appAccent,
                                tooltip: context.tr('听书播放器', 'Player', '再生プレーヤー'),
                                onPressed: () => _openPlayer(chapter: _currentChapter, autoplay: false),
                              ),
                            ],
                          ),
                  ),
                ),

                // ── Floating "Back to Reading Aloud" pill ──────────────────────
                if (_userScrolledAway && playingParagraphIndex != null)
                  Positioned(
                    right: 20,
                    bottom: _barsVisible ? 100 : 36,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _userScrolledAway ? 1.0 : 0.0,
                      child: FloatingActionButton.extended(
                        backgroundColor: context.appAccent,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                          context.tr('回到朗读处', 'Back to audio', '朗読位置へ'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          setState(() => _userScrolledAway = false);
                          _scrollToParagraph(playingParagraphIndex);
                        },
                      ),
                    ),
                  ),

                // ── Bottom Floating Audio Bar ─────────────────────────────────
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  bottom: _barsVisible ? MediaQuery.paddingOf(context).bottom : -100,
                  left: 0,
                  right: 0,
                  child: ReaderAudioBar(
                    book: widget.book,
                    currentChapter: _currentChapter,
                    onStartListening: () => _openPlayer(chapter: _currentChapter, autoplay: true),
                  ),
                ),
              ],
            ),
    );
  }
}
