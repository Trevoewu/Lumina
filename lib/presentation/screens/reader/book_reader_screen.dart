import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../ai/ai_models.dart';
import '../../../core/appearance.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/app_preferences.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../widgets/ai_summary_panel.dart';
import '../../widgets/design_system/macos_toolbar_providers.dart';
import '../../widgets/design_system/macos_window_toolbar.dart';
import '../../widgets/dictionary_lookup_sheet.dart';
import '../player/player_screen.dart';
import 'widgets/epub_reader_view.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_paragraph_view.dart';
import 'widgets/reader_toc_sheet.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  final drift_db.Book book;
  final drift_db.Chapter? initialChapter;
  final int initialParagraphIndex;
  @visibleForTesting
  final Widget Function(BuildContext context, File file)? epubReaderBuilder;

  const BookReaderScreen({
    super.key,
    required this.book,
    this.initialChapter,
    this.initialParagraphIndex = 0,
    this.epubReaderBuilder,
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

  bool _isEpubMode = false;
  File? _epubFile;
  final EpubController _epubController = EpubController();
  List<ReaderTocItem> _epubTocItems = [];
  String? _currentCfi;

  bool _loading = true;
  bool _barsVisible = true;
  int _currentPage = 1;
  int _totalPages = 1;
  double _currentProgress = 0.0;
  bool _userScrolledAway = false;
  int? _lastScrolledPlayingIndex;

  StreamSubscription<dynamic>? _audioSubscription;
  AppToolbarStateNotifier<Widget?>? _macosMiddleNotifier;
  AppToolbarStateNotifier<Widget?>? _macosTrailingNotifier;
  AppToolbarStateNotifier<bool>? _miniPlayerSuppressedNotifier;
  Widget? _previousTrailing;
  String? _lastToolbarChapterId;
  int? _lastToolbarChapterCount;
  bool _toolbarMounted = false;
  ModalRoute<dynamic>? _currentRoute;

  @override
  void initState() {
    super.initState();
    _macosMiddleNotifier = ref.read(macosToolbarMiddleProvider.notifier);
    _macosTrailingNotifier = ref.read(macosToolbarTrailingProvider.notifier);
    _previousTrailing = ref.read(macosToolbarTrailingProvider);
    _miniPlayerSuppressedNotifier = ref.read(
      miniPlayerSuppressedProvider.notifier,
    );
    _loadBookData();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MacosPersistentToolbarScope.hasToolbar(context)) {
        _miniPlayerSuppressedNotifier?.updateValue(true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _currentRoute) {
      _currentRoute?.secondaryAnimation?.removeListener(
        _onSecondaryAnimationChanged,
      );
      _currentRoute = route;
      _currentRoute?.secondaryAnimation?.addListener(
        _onSecondaryAnimationChanged,
      );
    }
  }

  void _onSecondaryAnimationChanged() {
    if (!mounted) return;
    final hasPersistentToolbar = MacosPersistentToolbarScope.hasToolbar(
      context,
    );
    if (!hasPersistentToolbar) return;

    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrent) {
      _syncPersistentToolbar(context, Theme.of(context));
    } else {
      _clearPersistentToolbar();
    }
  }

  void _clearPersistentToolbar() {
    if (_toolbarMounted) {
      _toolbarMounted = false;
      _lastToolbarChapterId = null;
      _lastToolbarChapterCount = null;
      _macosMiddleNotifier?.updateValue(null);
      _macosTrailingNotifier?.updateValue(_previousTrailing);
    }
  }

  @override
  void dispose() {
    _currentRoute?.secondaryAnimation?.removeListener(
      _onSecondaryAnimationChanged,
    );
    _toolbarMounted = false;
    _lastToolbarChapterId = null;
    _lastToolbarChapterCount = null;
    _audioSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    Future.microtask(() {
      try {
        _macosMiddleNotifier?.updateValue(null);
        _macosTrailingNotifier?.updateValue(_previousTrailing);
        _miniPlayerSuppressedNotifier?.updateValue(false);
      } catch (_) {}
    });
    super.dispose();
  }

  void _syncPersistentToolbar(BuildContext context, ThemeData theme) {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) {
      _clearPersistentToolbar();
      return;
    }

    final chapterId = _currentChapter?.id;
    final chapterCount = _isEpubMode && _epubTocItems.isNotEmpty
        ? _epubTocItems.length
        : _chapters.length;
    if (_toolbarMounted &&
        _lastToolbarChapterId == chapterId &&
        _lastToolbarChapterCount == chapterCount) {
      return;
    }
    _toolbarMounted = true;
    _lastToolbarChapterId = chapterId;
    _lastToolbarChapterCount = chapterCount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentRoute = ModalRoute.of(context);
      if (currentRoute != null && !currentRoute.isCurrent) {
        _clearPersistentToolbar();
        return;
      }
      _macosMiddleNotifier?.updateValue(
        _buildReaderToolbarMiddle(context, theme),
      );
      _macosTrailingNotifier?.updateValue(
        _buildReaderToolbarTrailing(context, theme),
      );
    });
  }

  void _onScroll() {
    if (!_isEpubMode && _scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      if (max > 0) {
        final pct = (_scrollController.offset / max).clamp(0.0, 1.0);
        final viewport = MediaQuery.sizeOf(context).height;
        final cur = viewport > 0
            ? (_scrollController.offset / viewport).floor() + 1
            : 1;
        final tot = viewport > 0 ? (max / viewport).ceil() + 1 : 1;
        if (cur != _currentPage ||
            tot != _totalPages ||
            (pct - _currentProgress).abs() > 0.01) {
          setState(() {
            _currentPage = cur;
            _totalPages = tot > 0 ? tot : 1;
            _currentProgress = pct;
          });
        }
      }
    }

    // If the user scrolls manually while audio is playing, note they moved away
    final handler = ref.read(luminaAudioHandlerProvider).asData?.value;
    if (handler != null &&
        handler.currentBookId == widget.book.id &&
        handler.currentChapterId == _currentChapter?.id) {
      final playingIndex = handler.currentParagraphIndex;
      if (playingIndex != null && _lastScrolledPlayingIndex != null) {
        if (!_userScrolledAway &&
            _scrollController.position.isScrollingNotifier.value) {
          setState(() => _userScrolledAway = true);
        }
      }
    }
  }

  Future<void> _saveProgress() async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    try {
      await ref
          .read(appDatabaseProvider)
          .updateReadingProgress(
            widget.book.id,
            chapterId: chapter.id,
            paragraphIndex:
                _lastScrolledPlayingIndex ?? widget.initialParagraphIndex,
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

    // Check if book format is epub and source file exists
    if (widget.book.format.toLowerCase() == 'epub') {
      File file = File(widget.book.sourcePath);
      bool exists = false;
      try {
        exists = file.existsSync();
      } catch (_) {}

      if (!exists && !p.isAbsolute(widget.book.sourcePath)) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final rebased = File(
            p.join(appDir.path, p.basename(widget.book.sourcePath)),
          );
          if (rebased.existsSync()) {
            file = rebased;
            exists = true;
          }
        } catch (_) {}
      }

      if (exists) {
        String? savedCfi;
        try {
          savedCfi = await database.getSetting('epub_cfi_${widget.book.id}');
        } catch (_) {}

        if (mounted) {
          setState(() {
            _isEpubMode = true;
            _epubFile = file;
            _currentChapter = targetChapter ?? chapters.firstOrNull;
            _currentCfi = savedCfi;
            _loading = false;
          });
        }
        return;
      }
    }

    _isEpubMode = false;
    await _loadChapter(
      targetChapter ?? chapters.firstOrNull,
      initialIndex: widget.initialParagraphIndex,
    );
  }

  void _onEpubChaptersLoaded(List<EpubChapter> loaded) {
    final items = <ReaderTocItem>[];
    int itemIdx = 0;
    void addChapter(EpubChapter c) {
      final matchedDbChapter = _chapters.firstWhereOrNull(
        (ch) => _normalizeTitle(ch.title) == _normalizeTitle(c.title),
      );
      items.add(
        ReaderTocItem(
          id: c.id.isNotEmpty ? c.id : c.href,
          title: c.title.trim().isNotEmpty
              ? c.title.trim()
              : 'Chapter ${itemIdx + 1}',
          href: c.href,
          index: itemIdx++,
          dbChapter: matchedDbChapter,
        ),
      );
      for (final sub in c.subitems) {
        addChapter(sub);
      }
    }

    for (final c in loaded) {
      addChapter(c);
    }

    if (mounted) {
      setState(() {
        _epubTocItems = items;
      });

      if (widget.initialChapter != null) {
        final match = items.firstWhereOrNull(
          (item) =>
              item.dbChapter?.id == widget.initialChapter!.id ||
              _normalizeTitle(item.title) ==
                  _normalizeTitle(widget.initialChapter!.title),
        );
        if (match?.href != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _epubController.display(cfi: match!.href!);
            } catch (_) {}
          });
        }
      }
    }
  }

  void _onEpubRelocated(EpubLocation location) {
    _currentCfi = location.startCfi;
    ref
        .read(appDatabaseProvider)
        .setSetting('epub_cfi_${widget.book.id}', location.startCfi);
    _saveProgress();
  }

  static String _normalizeTitle(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _findCurrentEpubTocIndex() {
    if (_currentChapter != null && _epubTocItems.isNotEmpty) {
      final idx = _epubTocItems.indexWhere(
        (item) =>
            item.dbChapter?.id == _currentChapter!.id ||
            _normalizeTitle(item.title) ==
                _normalizeTitle(_currentChapter!.title),
      );
      if (idx != -1) return idx;
    }
    return -1;
  }

  Future<void> _loadChapter(
    drift_db.Chapter? chapter, {
    int initialIndex = 0,
  }) async {
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

  void _scrollToParagraph(
    int index, {
    bool smooth = true,
    double alignment = 0.32,
  }) {
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
    setState(() {
      _barsVisible = !_barsVisible;
    });
    final hasPersistentToolbar = MacosPersistentToolbarScope.hasToolbar(
      context,
    );
    if (hasPersistentToolbar) {
      if (_barsVisible) {
        _syncPersistentToolbar(context, Theme.of(context));
      } else {
        _clearPersistentToolbar();
      }
    }
  }

  void _onPageChanged(int currentPage, int totalPages, double progress) {
    if (mounted) {
      setState(() {
        _currentPage = currentPage;
        _totalPages = totalPages > 0 ? totalPages : 1;
        _currentProgress = progress;
      });
    }
  }

  void _cycleTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref
        .read(appPreferencesProvider.notifier)
        .setTheme(isDark ? AppThemePreference.light : AppThemePreference.dark);
  }

  void _openAiPanel() {
    final chapter = _currentChapter;
    final scope = AiContentScope(
      type: AiScopeType.chapter,
      id: chapter?.id ?? widget.book.id,
      parentId: widget.book.id,
      title: chapter?.title ?? widget.book.title,
      parentTitle: widget.book.title,
      language: widget.book.language,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appDivider.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: AiSummaryPanel(
                    scope: scope,
                    transcriptAvailable: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    final db = ref.read(appDatabaseProvider);
    try {
      await db.addBookmark(
        drift_db.Bookmark(
          id: '${widget.book.id}_${chapter.id}_${DateTime.now().millisecondsSinceEpoch}',
          bookId: widget.book.id,
          chapterId: chapter.id,
          paragraphIndex: _lastScrolledPlayingIndex ?? 0,
          excerpt: chapter.title,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('已添加书签', 'Bookmark added', 'ブックマークを追加しました'),
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('分享', 'Share', '共有'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(
                  context.tr('复制书籍与章节信息', 'Copy book info', '書籍情報をコピー'),
                ),
                onTap: () {
                  final text =
                      '${widget.book.title} - ${_currentChapter?.title ?? ""}';
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr(
                          '已复制到剪贴板',
                          'Copied to clipboard',
                          'クリップボードにコピーしました',
                        ),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(context.tr('书籍信息', 'Book Info', '書籍情報')),
                subtitle: Text(
                  widget.book.author ?? widget.book.format.toUpperCase(),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text(context.tr('重新加载', 'Reload', '再読み込み')),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadBookData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPlayer({
    drift_db.Chapter? chapter,
    bool autoplay = true,
  }) async {
    final targetChapter = chapter ?? _currentChapter;
    final isDesktop =
        (Theme.of(context).platform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.macOS) &&
        MediaQuery.sizeOf(context).width >= 600;
    _toolbarMounted = false;
    _lastToolbarChapterId = null;
    _macosMiddleNotifier?.updateValue(null);
    _macosTrailingNotifier?.updateValue(null);
    await Navigator.of(context, rootNavigator: !isDesktop).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          book: widget.book,
          initialChapter: targetChapter,
          autoplayOnOpen: autoplay,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildReaderToolbarMiddle(BuildContext context, ThemeData theme) {
    final currentIndex = _isEpubMode && _epubTocItems.isNotEmpty
        ? _findCurrentEpubTocIndex()
        : (_currentChapter != null
              ? _chapters.indexWhere((c) => c.id == _currentChapter!.id)
              : -1);
    final totalCount = _isEpubMode && _epubTocItems.isNotEmpty
        ? _epubTocItems.length
        : _chapters.length;

    return Container(
      height: macosTopControlsReservedHeight,
      padding: const EdgeInsets.only(left: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentChapter?.title ?? widget.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
                if (currentIndex >= 0 && totalCount > 0)
                  Text(
                    '${currentIndex + 1} / $totalCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderToolbarTrailing(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MacosToolbarButton(
          key: const ValueKey('reader-bookmark-button'),
          size: 26,
          tooltip: context.tr('书签', 'Bookmark', 'ブックマーク'),
          onPressed: _toggleBookmark,
          child: const Icon(Icons.bookmark_border_rounded, size: 20),
        ),
        const SizedBox(width: 6),
        MacosToolbarButton(
          key: const ValueKey('reader-share-button'),
          size: 26,
          tooltip: context.tr('分享', 'Share', '共有'),
          onPressed: _showShareSheet,
          child: const Icon(Icons.ios_share_rounded, size: 20),
        ),
        const SizedBox(width: 6),
        MacosToolbarButton(
          key: const ValueKey('reader-more-button'),
          size: 26,
          tooltip: context.tr('更多', 'More', 'その他'),
          onPressed: _showMoreMenu,
          child: const Icon(Icons.more_vert_rounded, size: 20),
        ),
      ],
    );
  }

  Future<void> _openTocSheet() async {
    final chosen = await showReaderTocSheet(
      context: context,
      bookTitle: widget.book.title,
      items: _isEpubMode && _epubTocItems.isNotEmpty ? _epubTocItems : null,
      chapters: _chapters,
      currentChapterId: _currentChapter?.id ?? '',
    );
    if (chosen == null) return;
    if (_isEpubMode && chosen.href != null) {
      try {
        _epubController.display(cfi: chosen.href!);
      } catch (_) {}
      if (chosen.dbChapter != null) {
        setState(() => _currentChapter = chosen.dbChapter);
      }
    } else if (chosen.dbChapter != null &&
        chosen.dbChapter!.id != _currentChapter?.id) {
      _loadChapter(chosen.dbChapter!);
    }
  }

  void _goToPreviousChapter() {
    if (_isEpubMode && _epubTocItems.isNotEmpty) {
      final currentIndex = _findCurrentEpubTocIndex();
      if (currentIndex > 0) {
        final target = _epubTocItems[currentIndex - 1];
        if (target.href != null) {
          try {
            _epubController.display(cfi: target.href!);
          } catch (_) {}
          if (target.dbChapter != null) {
            setState(() => _currentChapter = target.dbChapter);
          }
        }
        return;
      }
    }
    final current = _currentChapter;
    if (current == null) return;
    final currentIndex = _chapters.indexWhere((c) => c.id == current.id);
    if (currentIndex > 0) {
      _loadChapter(_chapters[currentIndex - 1]);
    }
  }

  void _goToNextChapter() {
    if (_isEpubMode && _epubTocItems.isNotEmpty) {
      final currentIndex = _findCurrentEpubTocIndex();
      if (currentIndex >= 0 && currentIndex < _epubTocItems.length - 1) {
        final target = _epubTocItems[currentIndex + 1];
        if (target.href != null) {
          try {
            _epubController.display(cfi: target.href!);
          } catch (_) {}
          if (target.dbChapter != null) {
            setState(() => _currentChapter = target.dbChapter);
          }
        }
        return;
      }
    }
    final current = _currentChapter;
    if (current == null) return;
    final currentIndex = _chapters.indexWhere((c) => c.id == current.id);
    if (currentIndex >= 0 && currentIndex < _chapters.length - 1) {
      _loadChapter(_chapters[currentIndex + 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceControllerProvider);
    final design = context.appDesign;
    final scheme = Theme.of(context).colorScheme;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final hasPersistentToolbar = MacosPersistentToolbarScope.hasToolbar(
      context,
    );

    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (hasPersistentToolbar) {
      if (isCurrent) {
        _syncPersistentToolbar(context, Theme.of(context));
      } else {
        _clearPersistentToolbar();
      }
    }

    // Audio sync
    final handler = ref.watch(luminaAudioHandlerProvider).asData?.value;
    final isThisBook = handler?.currentBookId == widget.book.id;
    final isThisChapter =
        isThisBook && handler?.currentChapterId == _currentChapter?.id;
    final playingParagraphIndex = isThisChapter
        ? handler?.currentParagraphIndex
        : null;

    // Follow audio progression if user hasn't explicitly scrolled away
    if (playingParagraphIndex != null &&
        playingParagraphIndex != _lastScrolledPlayingIndex &&
        !_userScrolledAway) {
      _lastScrolledPlayingIndex = playingParagraphIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToParagraph(playingParagraphIndex);
      });
    }

    final currentIndex = _isEpubMode && _epubTocItems.isNotEmpty
        ? _findCurrentEpubTocIndex()
        : (_currentChapter != null
              ? _chapters.indexWhere((c) => c.id == _currentChapter!.id)
              : -1);
    final totalCount = _isEpubMode && _epubTocItems.isNotEmpty
        ? _epubTocItems.length
        : _chapters.length;
    final hasPrevChapter = currentIndex > 0;
    final hasNextChapter = currentIndex >= 0 && currentIndex < totalCount - 1;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.appAccent))
          : Stack(
              children: [
                if (_isEpubMode && _epubFile != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: hasPersistentToolbar
                        ? 0
                        : (MediaQuery.paddingOf(context).top + 8),
                    bottom: (MediaQuery.paddingOf(context).bottom + 32),
                    child: ClipRect(
                      child:
                          widget.epubReaderBuilder?.call(context, _epubFile!) ??
                          EpubReaderView(
                            file: _epubFile!,
                            controller: _epubController,
                            initialCfi: _currentCfi,
                            isScrolledFlow: appearance.readerScrolled,
                            onChaptersLoaded: _onEpubChaptersLoaded,
                            onRelocated: _onEpubRelocated,
                            onPageChanged: _onPageChanged,
                            onTapCenter: _toggleBars,
                            onLookupWord: (word) {
                              showDictionaryLookupSheet(
                                context,
                                initialQuery: word,
                              );
                            },
                          ),
                    ),
                  )
                else
                  // ── Reader Body (Continuous vertical scroll with three-zone tap) ──
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      final width = MediaQuery.sizeOf(context).width;
                      final x = details.localPosition.dx;
                      if (x <= width * 0.25) {
                        if (_scrollController.hasClients) {
                          final target =
                              (_scrollController.offset -
                                      MediaQuery.sizeOf(context).height * 0.8)
                                  .clamp(
                                    0.0,
                                    _scrollController.position.maxScrollExtent,
                                  );
                          _scrollController.animateTo(
                            target,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      } else if (x >= width * 0.75) {
                        if (_scrollController.hasClients) {
                          final target =
                              (_scrollController.offset +
                                      MediaQuery.sizeOf(context).height * 0.8)
                                  .clamp(
                                    0.0,
                                    _scrollController.position.maxScrollExtent,
                                  );
                          _scrollController.animateTo(
                            target,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      } else {
                        _toggleBars();
                      }
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        inset + appearance.readerMargin,
                        hasPersistentToolbar
                            ? design.spaceLg
                            : MediaQuery.paddingOf(context).top + 24,
                        inset + appearance.readerMargin,
                        MediaQuery.paddingOf(context).bottom + 32,
                      ),
                      itemCount:
                          _paragraphs.length +
                          2, // Header + paragraphs + Chapter footer
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
                                      fontWeight: FontWeight.w500,
                                      color: context.appTextSecondary,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  _currentChapter?.title ?? widget.book.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: context.appTextPrimary,
                                        height: 1.25,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Divider(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.12,
                                  ),
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
                                    icon: const AppIcon(
                                      AppIcons.arrowLeft02,
                                      size: 16,
                                    ),
                                    label: Text(
                                      context.tr('上一章', 'Previous', '前へ'),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: context.appTextPrimary,
                                      side: BorderSide(
                                        color: scheme.onSurface.withValues(
                                          alpha: 0.2,
                                        ),
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
                                    icon: const AppIcon(
                                      AppIcons.arrowRight02,
                                      size: 16,
                                    ),
                                    label: Text(
                                      context.tr('下一章', 'Next Chapter', '次へ'),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: context.appAccent,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
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
                        final isPlayingThis =
                            playingParagraphIndex == paragraphIndex;

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

                // ── Bottom-Right Page Progress Pill (visible in pure reading mode) ──
                Positioned(
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _barsVisible ? 0.0 : 0.65,
                    child: IgnorePointer(
                      child: Text(
                        '$_currentPage / $_totalPages',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: context.appTextSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Top Navigation Bar (Immersive Floating) ─────────────────────
                if (!hasPersistentToolbar)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    top: _barsVisible
                        ? 0
                        : -(MediaQuery.paddingOf(context).top + 64),
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: !_barsVisible,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          8,
                          MediaQuery.paddingOf(context).top + (isMac ? 6 : 4),
                          12,
                          8,
                        ),
                        decoration: BoxDecoration(
                          color: context.appBackground.withValues(alpha: 0.94),
                          border: Border(
                            bottom: BorderSide(
                              color: isMac
                                  ? context.appDivider
                                  : scheme.onSurface.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                size: 28,
                              ),
                              color: context.appTextPrimary,
                              tooltip: context.tr('返回', 'Back', '戻る'),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const AppIcon(
                                AppIcons.bookmark02,
                                size: 22,
                              ),
                              color: context.appTextPrimary,
                              tooltip: context.tr('书签', 'Bookmark', 'ブックマーク'),
                              onPressed: _toggleBookmark,
                            ),
                            IconButton(
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedShare01,
                                color: context.appTextPrimary,
                                size: 20,
                              ),
                              color: context.appTextPrimary,
                              tooltip: context.tr('分享', 'Share', '共有'),
                              onPressed: _showShareSheet,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                size: 22,
                              ),
                              color: context.appTextPrimary,
                              tooltip: context.tr('更多', 'More', 'その他'),
                              onPressed: _showMoreMenu,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Floating "Back to Reading Aloud" pill ──────────────────────
                if (_userScrolledAway && playingParagraphIndex != null)
                  Positioned(
                    right: 20,
                    bottom: hasPersistentToolbar
                        ? 24
                        : (_barsVisible ? 110 : 36),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _userScrolledAway ? 1.0 : 0.0,
                      child: FloatingActionButton.extended(
                        backgroundColor: context.appAccent,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        elevation: 4,
                        icon: const AppIcon(AppIcons.target02, size: 18),
                        label: Text(
                          context.tr('回到朗读处', 'Back to audio', '朗読位置へ'),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        onPressed: () {
                          setState(() => _userScrolledAway = false);
                          _scrollToParagraph(playingParagraphIndex);
                        },
                      ),
                    ),
                  ),

                // ── Bottom Controls & Floating Action Trio ──────────────────────
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_barsVisible,
                    child: ReaderBottomBar(
                      isVisible: _barsVisible,
                      isEpub: _isEpubMode,
                      progress: _currentProgress,
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                      chapterTitle: _currentChapter?.title ?? widget.book.title,
                      hasPrevChapter: hasPrevChapter,
                      hasNextChapter: hasNextChapter,
                      onToggleToc: _openTocSheet,
                      onSeekProgress: (val) {
                        setState(() => _currentProgress = val);
                        if (_isEpubMode) {
                          try {
                            if (_epubTocItems.isNotEmpty) {
                              final idx = (val * (_epubTocItems.length - 1))
                                  .round()
                                  .clamp(0, _epubTocItems.length - 1);
                              final href = _epubTocItems[idx].href;
                              if (href != null) {
                                _epubController.display(cfi: href);
                              }
                            }
                          } catch (_) {}
                        } else {
                          if (_scrollController.hasClients) {
                            final max =
                                _scrollController.position.maxScrollExtent;
                            _scrollController.jumpTo(val * max);
                          }
                        }
                      },
                      onToggleTheme: _cycleTheme,
                      onOpenAi: _openAiPanel,
                      onOpenTranslate: () =>
                          showDictionaryLookupSheet(context, initialQuery: ''),
                      onStartListening: () =>
                          _openPlayer(chapter: _currentChapter, autoplay: true),
                      onPrevChapter: hasPrevChapter
                          ? _goToPreviousChapter
                          : null,
                      onNextChapter: hasNextChapter ? _goToNextChapter : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
