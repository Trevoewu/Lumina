import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../domain/models/book_language.dart';
import '../../../domain/models/book_rights.dart';
import '../../../services/app_log_service.dart';
import '../../../services/book_parser.dart';
import '../../../services/reading_level_estimator.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/book_card_metadata.dart';
import '../../widgets/book_list_card.dart';
import '../../widgets/half_screen_action_sheet.dart';
import '../album/album_screen.dart';
import '../podcast/podcast_index_search_screen.dart';
import '../podcast/podcast_library_view.dart';
import '../search/search_screen.dart';
import 'home_overview_view.dart';

enum _HomeSection { all, books, podcasts }

enum _HomeAddAction { importBook, discoverPodcast, addPodcast }

class _HomeSectionSelector extends StatelessWidget {
  final _HomeSection selected;
  final ValueChanged<_HomeSection> onSelected;

  const _HomeSectionSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final labels = <_HomeSection, String>{
      _HomeSection.all: context.tr('全部', 'All', 'すべて'),
      _HomeSection.books: context.tr('书籍', 'Books', '本'),
      _HomeSection.podcasts: 'Podcast',
    };
    return SizedBox(
      height: 44,
      child: ListView.separated(
        key: const ValueKey('home-section-selector'),
        padding: EdgeInsets.fromLTRB(inset + 6, 0, design.spaceXs, 0),
        scrollDirection: Axis.horizontal,
        primary: false,
        itemCount: _HomeSection.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 22),
        itemBuilder: (context, index) {
          final section = _HomeSection.values[index];
          return _HomeSectionTab(
            key: ValueKey('home-section-${section.name}'),
            label: labels[section]!,
            selected: selected == section,
            onTap: () => onSelected(section),
          );
        },
      ),
    );
  }
}

/// Underline tab from the Lumina home design: weight, opacity and a 2px rule
/// carry the selected state instead of a filled chip.
class _HomeSectionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HomeSectionTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: IntrinsicWidth(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? ink : ink.withValues(alpha: 0.35),
                ),
                child: Text(label),
              ),
              const SizedBox(height: 7),
              AnimatedScale(
                duration: const Duration(milliseconds: 300),
                curve: const Cubic(0.2, 0.7, 0.2, 1),
                alignment: Alignment.centerLeft,
                scale: selected ? 1 : 0.3,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: selected ? 1 : 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 书架首页。
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _reloadToken = 0;
  bool _importing = false;
  bool _addingPodcast = false;
  _HomeSection _section = _HomeSection.all;
  final Set<String> _coverBackfillStarted = {};
  final Map<String, _BookCacheProgress> _bookCacheProgress = {};
  Future<_LibraryBooksData>? _booksDataFuture;
  int _booksDataToken = -1;
  final PageController _sectionPageController = PageController();
  final ScrollController _overviewScrollController = ScrollController();
  final ScrollController _booksScrollController = ScrollController();
  final ScrollController _podcastsScrollController = ScrollController();

  @override
  void dispose() {
    _sectionPageController.dispose();
    _overviewScrollController.dispose();
    _booksScrollController.dispose();
    _podcastsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Material(
              key: const ValueKey('home-fixed-header'),
              color: context.appBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset + 6,
                      14,
                      design.spaceXs,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Lumina',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.38,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('home-search-action'),
                          tooltip: _section == _HomeSection.podcasts
                              ? context.tr(
                                  '搜索 Podcast Index',
                                  'Search Podcast Index',
                                  'Podcast Indexを検索',
                                )
                              : context.tr('搜索书籍', 'Search books', '本を検索'),
                          onPressed: _openSearch,
                          icon: Icon(
                            Icons.search,
                            size: 22,
                            color: context.appTextPrimary,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('home-add-action'),
                          tooltip: _section == _HomeSection.podcasts
                              ? context.tr(
                                  '添加 Podcast',
                                  'Add podcast',
                                  'ポッドキャストを追加',
                                )
                              : _section == _HomeSection.books
                              ? context.tr('导入书籍', 'Import book', '本をインポート')
                              : context.tr('添加内容', 'Add content', 'コンテンツを追加'),
                          onPressed: _importing || _addingPodcast
                              ? null
                              : _handleAddAction,
                          icon: _importing || _addingPodcast
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: accent,
                                  ),
                                )
                              : Icon(
                                  Icons.add,
                                  size: 22,
                                  color: context.appTextPrimary,
                                ),
                        ),
                      ],
                    ),
                  ),
                  _HomeSectionSelector(
                    selected: _section,
                    onSelected: _selectSection,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                key: const ValueKey('home-section-pages'),
                controller: _sectionPageController,
                onPageChanged: (index) {
                  final section = _HomeSection.values[index];
                  if (section != _section) {
                    setState(() => _section = section);
                  }
                },
                children: [
                  _KeepAliveHomeSection(
                    child: HomeOverviewView(
                      reloadToken: _reloadToken,
                      scrollController: _overviewScrollController,
                      onImportBook: () => _importBook(context),
                      onAddPodcast: _showAddPodcastDialog,
                      onSearchPodcastIndex: _showPodcastIndexSearch,
                      onBookLongPress: _showBookActions,
                      onOpenBook: _openBook,
                    ),
                  ),
                  _KeepAliveHomeSection(child: _buildBooks(db, inset, design)),
                  _KeepAliveHomeSection(
                    child: PodcastLibraryView(
                      scrollController: _podcastsScrollController,
                      onAddPodcast: _showAddPodcastDialog,
                      onSearchPodcastIndex: _showPodcastIndexSearch,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSection(_HomeSection section) {
    if (section == _section) return;
    setState(() => _section = section);
    _animateToSection(section);
  }

  void _animateToSection(_HomeSection section) {
    if (!_sectionPageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_sectionPageController.hasClients) return;
        _sectionPageController.jumpToPage(section.index);
      });
      return;
    }
    _sectionPageController.animateToPage(
      section.index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _section == _HomeSection.podcasts
            ? const PodcastIndexSearchScreen()
            : const SearchScreen(),
      ),
    );
    if (mounted) setState(() => _reloadToken++);
  }

  void _handleAddAction() {
    switch (_section) {
      case _HomeSection.all:
        _showAddContentSheet();
        break;
      case _HomeSection.books:
        _importBook(context);
        break;
      case _HomeSection.podcasts:
        _showAddPodcastDialog();
        break;
    }
  }

  Widget _buildBooks(
    drift_db.AppDatabase db,
    double inset,
    AppDesignTokens design,
  ) {
    return FutureBuilder<_LibraryBooksData>(
      key: ValueKey(_reloadToken),
      future: _libraryBooksData(db),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _LibraryBooksData();
        final books = data.books;

        if (books.isEmpty) return _buildEmptyState();
        _backfillMissingCovers(books);

        return ListView.separated(
          key: const PageStorageKey('home-books-list'),
          controller: _booksScrollController,
          primary: false,
          padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 120),
          itemCount: books.length,
          separatorBuilder: (_, _) => const SizedBox.shrink(),
          itemBuilder: (context, i) {
            final book = books[i];
            return _BookCard(
              book: book,
              cacheProgress: _bookCacheProgress[book.id],
              finishedChapterIndexes:
                  data.finishedChapterIndexesByBook[book.id] ?? const <int>{},
              onTap: () => _openBook(book),
              onLongPress: () => _showBookActions(book),
            );
          },
        );
      },
    );
  }

  Future<_LibraryBooksData> _loadLibraryBooksData(
    drift_db.AppDatabase database,
  ) async {
    final results = await Future.wait<Object>([
      database.getAllBooks(),
      database.getFinishedChapterIndexesByBook(),
    ]);
    return _LibraryBooksData(
      books: results[0] as List<drift_db.Book>,
      finishedChapterIndexesByBook: results[1] as Map<String, Set<int>>,
    );
  }

  Future<_LibraryBooksData> _libraryBooksData(drift_db.AppDatabase database) {
    if (_booksDataFuture == null || _booksDataToken != _reloadToken) {
      _booksDataToken = _reloadToken;
      _booksDataFuture = _loadLibraryBooksData(database);
    }
    return _booksDataFuture!;
  }

  Future<void> _openBook(drift_db.Book book) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AlbumScreen(book: book)));
    if (mounted) setState(() => _reloadToken++);
  }

  void _showBookActions(drift_db.Book book) {
    final cacheProgress = _bookCacheProgress[book.id];
    showHalfScreenActionSheet(
      context,
      title: book.title,
      actions: [
        HalfScreenActionSheetItem(
          label: book.isRead
              ? context.tr('标记为未读', 'Mark as unread', '未読にする')
              : context.tr('标记为已读', 'Mark as read', '既読にする'),
          icon: book.isRead
              ? Icons.remove_done_outlined
              : Icons.done_all_rounded,
          onPressed: () => _setBookReadStatus(book, !book.isRead),
        ),
        HalfScreenActionSheetItem(
          label: context.tr('编辑', 'Edit', '編集'),
          icon: Icons.edit_outlined,
          onPressed: () => _showEditBookSheet(book),
        ),
        HalfScreenActionSheetItem(
          label: context.tr('重新解析', 'Reparse', '再解析'),
          icon: Icons.auto_fix_high_outlined,
          onPressed: () => _confirmReparseBook(book),
        ),
        HalfScreenActionSheetItem(
          label: cacheProgress == null
              ? context.tr('缓存整本书', 'Cache Entire Book', '本全体をキャッシュ')
              : context.tr(
                  '缓存中 ${(cacheProgress.percent * 100).round()}%',
                  'Caching ${(cacheProgress.percent * 100).round()}%',
                  'キャッシュ中 ${(cacheProgress.percent * 100).round()}%',
                ),
          icon: Icons.download_for_offline_outlined,
          onPressed: cacheProgress == null ? () => _cacheWholeBook(book) : null,
        ),
        HalfScreenActionSheetItem(
          label: context.tr('清除音频', 'Clear Audio', '音声を消去'),
          icon: Icons.cleaning_services_outlined,
          onPressed: () => _confirmClearBookCache(book),
        ),
        HalfScreenActionSheetItem(
          label: context.tr('删除', 'Delete', '削除'),
          icon: Icons.delete_outline,
          onPressed: () => _confirmDeleteBook(book),
          destructive: true,
        ),
      ],
    );
  }

  Future<void> _setBookReadStatus(drift_db.Book book, bool isRead) async {
    await ref.read(appDatabaseProvider).updateBookReadStatus(book.id, isRead);
    if (!mounted) return;
    setState(() => _reloadToken++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRead
              ? context.tr(
                  '已标记《${book.title}》为已读',
                  'Marked “${book.title}” as read',
                  '「${book.title}」を既読にしました',
                )
              : context.tr(
                  '已标记《${book.title}》为未读',
                  'Marked “${book.title}” as unread',
                  '「${book.title}」を未読にしました',
                ),
        ),
      ),
    );
  }

  Future<void> _showAddContentSheet() async {
    final action = await showModalBottomSheet<_HomeAddAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_stories_rounded),
              title: Text(context.tr('导入书籍', 'Import book', '本をインポート')),
              subtitle: const Text('EPUB / TXT'),
              onTap: () =>
                  Navigator.pop(sheetContext, _HomeAddAction.importBook),
            ),
            ListTile(
              leading: const Icon(Icons.travel_explore_rounded),
              title: Text(
                context.tr('发现 Podcast', 'Discover podcasts', 'ポッドキャストを探す'),
              ),
              subtitle: const Text('Podcast Index'),
              onTap: () =>
                  Navigator.pop(sheetContext, _HomeAddAction.discoverPodcast),
            ),
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: Text(context.tr('通过 RSS 添加', 'Add with RSS', 'RSSから追加')),
              subtitle: Text(
                context.tr('粘贴 Feed 地址', 'Paste a feed URL', 'フィードURLを貼り付け'),
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, _HomeAddAction.addPodcast),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _HomeAddAction.importBook:
        await _importBook(context);
        break;
      case _HomeAddAction.discoverPodcast:
        await _showPodcastIndexSearch();
        break;
      case _HomeAddAction.addPodcast:
        await _showAddPodcastDialog();
        break;
    }
  }

  Future<void> _showPodcastIndexSearch() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PodcastIndexSearchScreen()));
    if (mounted) setState(() => _reloadToken++);
  }

  Future<void> _showAddPodcastDialog() async {
    if (_addingPodcast) return;
    final controller = TextEditingController();
    final feedUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('添加 Podcast', 'Add podcast', 'ポッドキャストを追加')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'RSS URL',
            hintText: 'https://example.com/feed.xml',
            prefixIcon: const Icon(Icons.rss_feed),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.tr('订阅', 'Subscribe', '購読')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || feedUrl == null || feedUrl.isEmpty) return;

    setState(() => _addingPodcast = true);
    try {
      final result = await ref
          .read(podcastRepositoryProvider)
          .subscribe(feedUrl);
      if (!mounted) return;
      setState(() => _reloadToken++);
      _selectSection(_HomeSection.podcasts);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '已订阅 ${result.show.title}，获取 ${result.importedEpisodes} 个单集',
              'Subscribed to ${result.show.title} with ${result.importedEpisodes} episodes',
              '「${result.show.title}」を購読しました（${result.importedEpisodes}エピソード）',
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _addingPodcast = false);
    }
  }

  void _backfillMissingCovers(List<drift_db.Book> books) {
    for (final book in books) {
      if (book.format != 'epub' || _coverBackfillStarted.contains(book.id)) {
        continue;
      }

      _coverBackfillStarted.add(book.id);
      Future<void>(() async {
        try {
          final existingPath = book.coverPath;
          if (existingPath != null &&
              existingPath.isNotEmpty &&
              await File(existingPath).exists()) {
            return;
          }
          final appDir = await getApplicationDocumentsDirectory();
          final coverPath = await BookParser.extractCover(
            sourcePath: book.sourcePath,
            bookId: book.id,
            appDir: appDir.path,
          );
          if (coverPath == null || !mounted) return;

          await ref
              .read(appDatabaseProvider)
              .updateBookCoverPath(book.id, coverPath);
          if (mounted) setState(() => _reloadToken++);
        } catch (error, stackTrace) {
          AppLogger.warning(
            'Library',
            '提取书籍封面失败 book=${book.id}',
            error: error,
            stackTrace: stackTrace,
          );
          // 封面不是核心数据，提取失败时保留占位图。
        }
      });
    }
  }

  /// 空状态：大图标 + 优雅文案 + 导入按钮。
  Widget _buildEmptyState() {
    final accent = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 120,
                color: context.appSurfaceHighlight,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('你的书架空空如也', 'Your library is empty', '本棚は空です'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  '导入 EPUB 或 TXT 文件，开启你的听书之旅',
                  'Import an EPUB or TXT file to start listening',
                  'EPUBまたはTXTファイルをインポートして聴き始めましょう',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.appTextSecondary),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _importing ? null : () => _importBook(context),
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Icon(Icons.upload_file),
                label: Text(
                  _importing ? '导入中...' : '导入书籍',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importBook(BuildContext context) async {
    final db = ref.read(appDatabaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        if (result == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('未选择文件：FilePicker 返回 null')),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('未选择文件：files 为空')),
          );
        }
        return;
      }

      final picked = result.files.single;
      if (picked.path == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('导入失败：FilePicker 没有返回文件路径')),
        );
        return;
      }
      if (!context.mounted) return;

      messenger.showSnackBar(const SnackBar(content: Text('正在解析书籍...')));
      final appDir = await getApplicationDocumentsDirectory();

      final parsed = await BookParser.parse(
        sourcePath: picked.path!,
        appDir: appDir.path,
      );
      final language = inferLanguageFromTitle(parsed.book.title);
      final readingLevel = await _estimateReadingLevel(
        language: language,
        paragraphTexts: parsed.paragraphs.map((paragraph) => paragraph.text),
      );

      await db.replaceBookData(
        book: drift_db.Book(
          id: parsed.book.id,
          title: parsed.book.title,
          author: parsed.book.author,
          language: language,
          format: parsed.book.format.name,
          sourcePath: parsed.book.sourcePath,
          coverPath: parsed.book.coverPath,
          chapterCount: parsed.book.chapterCount,
          paragraphCount: parsed.book.paragraphCount,
          currentChapterId: parsed.book.currentChapterId,
          currentParagraphIndex: parsed.book.currentParagraphIndex,
          playbackOffsetMs: parsed.book.playbackOffsetMs,
          voiceId: parsed.book.voiceId,
          importedAt: parsed.book.importedAt,
          lastReadAt: parsed.book.lastReadAt,
          isRead: false,
          kind: 'book',
          rightsStatus: userUploadedRightsStatus,
          readingLevelSystem: readingLevel?.system,
          readingLevelCode: readingLevel?.code,
          readingLevelSource: readingLevel?.source,
        ),
        chapterEntries: parsed.chapters
            .map(
              (c) => drift_db.Chapter(
                id: c.id,
                bookId: c.bookId,
                chapterIndex: c.index,
                title: c.title,
                textOffset: c.textOffset,
                isHidden: false,
              ),
            )
            .toList(),
        paragraphEntries: parsed.paragraphs
            .map(
              (p) => drift_db.Paragraph(
                id: p.id,
                chapterId: p.chapterId,
                bookId: p.bookId,
                paragraphIndex: p.index,
                content: p.text,
              ),
            )
            .toList(),
      );

      if (!context.mounted) return;
      setState(() => _reloadToken++);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '解析成功：${parsed.book.title}，${parsed.chapters.length} 章，${parsed.paragraphs.length} 段',
          ),
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Library', '导入书籍失败', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('导入失败：$e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirmDeleteBook(drift_db.Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除书籍？'),
        content: Text('将删除《${book.title}》及其章节、歌词、生成音频和导入文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final handler = await ref.read(luminaAudioHandlerProvider.future);
      await handler.unloadIfBook(book.id);
      await ref.read(cacheManagerProvider).clearBookAndRun(book.id, () async {
        await _deleteImportedBookFiles(book);
        await ref.read(appDatabaseProvider).deleteBookCascade(book.id);
      });
      if (!mounted) return;
      setState(() => _reloadToken++);
      messenger.showSnackBar(SnackBar(content: Text('已删除《${book.title}》')));
    } catch (e, stackTrace) {
      AppLogger.error(
        'Library',
        '删除书籍失败 book=${book.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('删除失败：$e'),
        ),
      );
    }
  }

  Future<void> _cacheWholeBook(drift_db.Book book) async {
    if (_bookCacheProgress.containsKey(book.id)) return;

    final chapters = await ref.read(appDatabaseProvider).getChapters(book.id);
    if (!mounted) return;
    if (chapters.isEmpty) {
      await _showCacheMessage(
        title: context.tr('无法缓存', 'Unable to cache', 'キャッシュできません'),
        message: context.tr(
          '这本书没有可缓存的章节。',
          'This book has no chapters.',
          'この本にはキャッシュできる章がありません。',
        ),
      );
      return;
    }

    try {
      final provider = await _resolveProvider();
      final voice = await _resolveVoice(book, provider);
      if (!mounted) return;
      if (voice == null) {
        await _showCacheMessage(
          title: context.tr('没有可用音色', 'No voice available', '利用できる音声がありません'),
          message: context.tr(
            '${provider.displayName} 没有可用于合成的音色。',
            '${provider.displayName} has no voice available for generation.',
            '${provider.displayName}には生成に使える音声がありません。',
          ),
        );
        return;
      }
      final providerValid = await provider.validate();
      if (!mounted) return;
      if (!providerValid) {
        await _showCacheMessage(
          title: context.tr(
            '语音引擎未配置',
            'TTS provider not configured',
            'TTSプロバイダーが未設定です',
          ),
          message: context.tr(
            '请先完成 ${provider.displayName} 的模型或 API Key 配置。',
            'Configure the model or API key for ${provider.displayName} first.',
            'まず${provider.displayName}のモデルまたはAPIキーを設定してください。',
          ),
        );
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            context.tr('缓存整本书？', 'Cache the entire book?', '本全体をキャッシュしますか？'),
          ),
          content: Text(
            context.tr(
              '将使用 ${provider.displayName} · ${voice.name} 依次缓存《${book.title}》的 '
                  '${chapters.length} 个章节。已完成的段落会自动跳过。',
              'Cache all ${chapters.length} chapters of “${book.title}” with '
                  '${provider.displayName} · ${voice.name}. Completed segments will be skipped.',
              '${provider.displayName} · ${voice.name}で『${book.title}』の${chapters.length}章をキャッシュします。完了済みの部分はスキップされます。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.tr('取消', 'Cancel', 'キャンセル')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(context.tr('开始缓存', 'Start caching', 'キャッシュ開始')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      setState(() {
        _bookCacheProgress[book.id] = _BookCacheProgress(
          completedChapters: 0,
          totalChapters: chapters.length,
          chapterTitle: chapters.first.title,
        );
      });
      AppLogger.info(
        'Generation',
        '整书缓存开始 book=${book.id} chapters=${chapters.length} '
            'provider=${provider.id} voice=${voice.id}',
      );

      var failedChapters = 0;
      final orchestrator = ref.read(generationOrchestratorProvider);
      for (var index = 0; index < chapters.length; index++) {
        final chapter = chapters[index];
        var chapterFailed = false;
        try {
          await for (final progress in orchestrator.generateChapter(
            bookId: book.id,
            chapterId: chapter.id,
            provider: provider,
            voice: voice,
          )) {
            chapterFailed = progress.failed > 0;
            if (!mounted) return;
            setState(() {
              _bookCacheProgress[book.id] = _BookCacheProgress(
                completedChapters: index,
                totalChapters: chapters.length,
                chapterTitle: chapter.title,
                chapterProgress: progress.percent,
              );
            });
          }
        } catch (error, stackTrace) {
          chapterFailed = true;
          AppLogger.error(
            'Generation',
            '整书缓存章节失败 book=${book.id} chapter=${chapter.id}',
            error: error,
            stackTrace: stackTrace,
          );
        }
        if (chapterFailed) failedChapters++;
        if (!mounted) return;
        setState(() {
          _bookCacheProgress[book.id] = _BookCacheProgress(
            completedChapters: index + 1,
            totalChapters: chapters.length,
            chapterTitle: chapter.title,
            chapterProgress: 0,
          );
        });
      }

      AppLogger.info(
        'Generation',
        '整书缓存结束 book=${book.id} failedChapters=$failedChapters',
      );
      if (!mounted) return;
      await _showCacheMessage(
        title: failedChapters == 0
            ? context.tr('缓存完成', 'Caching complete', 'キャッシュ完了')
            : context.tr('缓存部分完成', 'Caching partially complete', 'キャッシュが一部完了'),
        message: failedChapters == 0
            ? context.tr(
                '《${book.title}》的全部章节已缓存。',
                'All chapters of “${book.title}” are cached.',
                '「${book.title}」の全章をキャッシュしました。',
              )
            : context.tr(
                '已处理 ${chapters.length} 个章节，其中 $failedChapters 个章节存在失败段落，可再次执行以重试。',
                'Processed ${chapters.length} chapters. $failedChapters chapters contain failed segments; run caching again to retry.',
                '${chapters.length}章を処理しました。$failedChapters章に失敗した部分があります。再度キャッシュしてお試しください。',
              ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Generation',
        '整书缓存失败 book=${book.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        await _showCacheMessage(
          title: context.tr('缓存失败', 'Caching failed', 'キャッシュに失敗しました'),
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _bookCacheProgress.remove(book.id));
      }
    }
  }

  Future<TtsProvider> _resolveProvider() async {
    return ref.read(activeTtsProviderProvider);
  }

  Future<TtsVoice?> _resolveVoice(
    drift_db.Book book,
    TtsProvider provider,
  ) async {
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

    final activeVoiceId = await ref
        .read(providerSelectionRepositoryProvider)
        .selectedVoice(provider.id);
    for (final preferredVoiceId in [book.voiceId, activeVoiceId]) {
      if (preferredVoiceId == null) continue;
      for (final voice in voices) {
        if (voice.id == preferredVoiceId ||
            voice.providerVoiceId == preferredVoiceId) {
          return voice;
        }
      }
    }

    final cloneVoices =
        savedVoices
            .where((voice) => voice.type == VoiceType.clone.name)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return cloneVoices.isNotEmpty
        ? _voiceFromDb(cloneVoices.first)
        : voices.first;
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

  Future<void> _showCacheMessage({
    required String title,
    required String message,
  }) {
    if (!mounted) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('完成', 'Done', '完了')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearBookCache(drift_db.Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清除音频缓存？'),
        content: Text('将删除《${book.title}》已经生成的所有音频，书籍和章节内容会保留。'),
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
    try {
      final handler = await ref.read(luminaAudioHandlerProvider.future);
      await handler.unloadIfBook(book.id);
      await ref.read(cacheManagerProvider).clearBook(book.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已清除《${book.title}》音频缓存')));
      setState(() => _reloadToken++);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Cache',
        '清除书籍音频失败 book=${book.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('清除失败：$e'),
        ),
      );
    }
  }

  Future<void> _confirmReparseBook(drift_db.Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重新解析书籍？'),
        content: Text('将重建《${book.title}》的章节和段落，并清除这本书已生成的音频缓存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('重新解析'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        SnackBar(content: Text('正在重新解析《${book.title}》...')),
      );
      final handler = await ref.read(luminaAudioHandlerProvider.future);
      await handler.unloadIfBook(book.id);
      late ParsedBook parsed;
      await ref.read(cacheManagerProvider).clearBookAndRun(book.id, () async {
        final appDir = await getApplicationDocumentsDirectory();
        parsed = await BookParser.reparseExisting(
          sourcePath: book.sourcePath,
          bookId: book.id,
          appDir: appDir.path,
        );
        final language =
            book.language ?? inferLanguageFromTitle(parsed.book.title);
        final estimatedReadingLevel =
            book.readingLevelSource == userReadingLevelSource
            ? null
            : await _estimateReadingLevel(
                language: language,
                paragraphTexts: parsed.paragraphs.map(
                  (paragraph) => paragraph.text,
                ),
              );
        await ref
            .read(appDatabaseProvider)
            .replaceBookData(
              book: drift_db.Book(
                id: parsed.book.id,
                title: parsed.book.title,
                author: parsed.book.author,
                language: language,
                format: parsed.book.format.name,
                sourcePath: parsed.book.sourcePath,
                coverPath: parsed.book.coverPath,
                chapterCount: parsed.book.chapterCount,
                paragraphCount: parsed.book.paragraphCount,
                currentChapterId: parsed.book.currentChapterId,
                currentParagraphIndex: parsed.book.currentParagraphIndex,
                playbackOffsetMs: parsed.book.playbackOffsetMs,
                voiceId: book.voiceId,
                importedAt: book.importedAt,
                lastReadAt: DateTime.now().millisecondsSinceEpoch,
                isRead: book.isRead,
                kind: book.kind,
                externalSource: book.externalSource,
                externalId: book.externalId,
                rightsStatus: book.rightsStatus,
                externalMetadataJson: book.externalMetadataJson,
                readingLevelSystem:
                    book.readingLevelSource == userReadingLevelSource
                    ? book.readingLevelSystem
                    : estimatedReadingLevel?.system,
                readingLevelCode:
                    book.readingLevelSource == userReadingLevelSource
                    ? book.readingLevelCode
                    : estimatedReadingLevel?.code,
                readingLevelSource:
                    book.readingLevelSource == userReadingLevelSource
                    ? book.readingLevelSource
                    : estimatedReadingLevel?.source,
              ),
              chapterEntries: parsed.chapters
                  .map(
                    (c) => drift_db.Chapter(
                      id: c.id,
                      bookId: c.bookId,
                      chapterIndex: c.index,
                      title: c.title,
                      textOffset: c.textOffset,
                      isHidden: false,
                    ),
                  )
                  .toList(),
              paragraphEntries: parsed.paragraphs
                  .map(
                    (p) => drift_db.Paragraph(
                      id: p.id,
                      chapterId: p.chapterId,
                      bookId: p.bookId,
                      paragraphIndex: p.index,
                      content: p.text,
                    ),
                  )
                  .toList(),
            );
      });

      if (!mounted) return;
      setState(() => _reloadToken++);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '重新解析完成：${parsed.chapters.length} 章，${parsed.paragraphs.length} 段',
          ),
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Library',
        '重新解析书籍失败 book=${book.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('重新解析失败：$e'),
        ),
      );
    }
  }

  Future<ReadingLevelEstimate?> _estimateReadingLevel({
    required String? language,
    required Iterable<String> paragraphTexts,
  }) async {
    if (normalizeBookLanguage(language) != 'en') return null;
    try {
      return await ReadingLevelEstimator.instance.estimateEnglish(
        paragraphTexts,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Library',
        '阅读难度估算失败',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _showEditBookSheet(drift_db.Book book) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author ?? '');
    final languageController = TextEditingController(
      text: book.language ?? inferLanguageFromTitle(book.title) ?? '',
    );
    final readingLevelController = TextEditingController(
      text: book.readingLevelCode ?? '',
    );
    String? coverPath = book.coverPath;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '编辑书籍',
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: BookCover(
                            coverPath: coverPath,
                            borderRadius: 8,
                            iconSize: 42,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _darkTextField(
                                controller: titleController,
                                hint: '书名',
                                icon: Icons.title,
                              ),
                              const SizedBox(height: 10),
                              _darkTextField(
                                controller: authorController,
                                hint: '作者',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 10),
                              _darkTextField(
                                controller: languageController,
                                hint: '语言代码（如 zh / en）',
                                icon: Icons.language,
                              ),
                              const SizedBox(height: 10),
                              _darkTextField(
                                controller: readingLevelController,
                                hint: '阅读难度（如 A2 / B1）',
                                icon: Icons.school_outlined,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ActionChip(
                          avatar: Icon(Icons.image_outlined, size: 18),
                          label: Text('更换封面'),
                          onPressed: () async {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                            );
                            final path = picked?.files.single.path;
                            if (path == null) return;
                            final appDir =
                                await getApplicationDocumentsDirectory();
                            final coverDir = Directory(
                              p.join(appDir.path, 'books', book.id),
                            );
                            await coverDir.create(recursive: true);
                            final ext = p.extension(path).toLowerCase();
                            final target = p.join(
                              coverDir.path,
                              'cover_custom$ext',
                            );
                            await File(path).copy(target);
                            setSheetState(() => coverPath = target);
                          },
                        ),
                        if (coverPath != null)
                          ActionChip(
                            avatar: Icon(Icons.hide_image_outlined, size: 18),
                            label: Text('移除封面'),
                            onPressed: () =>
                                setSheetState(() => coverPath = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: Icon(Icons.check),
                        label: Text('保存'),
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;
                          final language = normalizeBookLanguage(
                            languageController.text,
                          );
                          final readingLevel = normalizeCefrReadingLevel(
                            readingLevelController.text,
                          );
                          await ref
                              .read(appDatabaseProvider)
                              .updateBookMetadata(
                                book.id,
                                title: title,
                                author: authorController.text.trim(),
                                clearAuthor: authorController.text
                                    .trim()
                                    .isEmpty,
                                coverPath: coverPath,
                                clearCover: coverPath == null,
                                language: language,
                                clearLanguage: language == null,
                                readingLevelSystem: readingLevel == null
                                    ? null
                                    : cefrJReadingLevelSystem,
                                readingLevelCode: readingLevel,
                                readingLevelSource: readingLevel == null
                                    ? null
                                    : userReadingLevelSource,
                                clearReadingLevel: readingLevel == null,
                              );
                          if (!mounted) return;
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          setState(() => _reloadToken++);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    authorController.dispose();
    languageController.dispose();
    readingLevelController.dispose();
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: context.appTextPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: context.appBackground,
        hintText: hint,
        hintStyle: TextStyle(color: context.appTextSecondary),
        prefixIcon: Icon(icon, color: context.appTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _deleteImportedBookFiles(drift_db.Book book) async {
    final source = File(book.sourcePath);
    final parent = source.parent;
    if (await parent.exists() && p.basename(parent.path) == book.id) {
      await parent.delete(recursive: true);
      return;
    }
    if (await source.exists()) {
      await source.delete();
    }
    final coverPath = book.coverPath;
    if (coverPath != null) {
      final cover = File(coverPath);
      if (await cover.exists()) await cover.delete();
    }
  }
}

class _KeepAliveHomeSection extends StatefulWidget {
  final Widget child;

  const _KeepAliveHomeSection({required this.child});

  @override
  State<_KeepAliveHomeSection> createState() => _KeepAliveHomeSectionState();
}

class _KeepAliveHomeSectionState extends State<_KeepAliveHomeSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _BookCacheProgress {
  final int completedChapters;
  final int totalChapters;
  final String chapterTitle;
  final double chapterProgress;

  const _BookCacheProgress({
    required this.completedChapters,
    required this.totalChapters,
    required this.chapterTitle,
    this.chapterProgress = 0,
  });

  double get percent {
    if (totalChapters <= 0) return 0;
    return ((completedChapters + chapterProgress) / totalChapters).clamp(0, 1);
  }
}

class _LibraryBooksData {
  final List<drift_db.Book> books;
  final Map<String, Set<int>> finishedChapterIndexesByBook;

  const _LibraryBooksData({
    this.books = const <drift_db.Book>[],
    this.finishedChapterIndexesByBook = const <String, Set<int>>{},
  });
}

/// 书籍卡片：圆角封面占位 + 标题 + 作者 + 章节数。
class _BookCard extends StatelessWidget {
  final drift_db.Book book;
  final _BookCacheProgress? cacheProgress;
  final Set<int> finishedChapterIndexes;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookCard({
    required this.book,
    this.cacheProgress,
    required this.finishedChapterIndexes,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return BookListCard(
      title: book.title,
      subtitle: book.author ?? 'Unknown Author',
      localCoverPath: book.coverPath,
      metadata: [
        BookListCardMeta(
          icon: Icons.language,
          label: bookLanguageLabel(context, book),
        ),
        BookListCardMeta(
          icon: Icons.trending_up_outlined,
          label: bookReadingProgressLabel(
            context,
            book,
            finishedChapterIndexes: finishedChapterIndexes,
          ),
        ),
        if (bookReadingLevelLabel(context, book) case final level?)
          BookListCardMeta(icon: Icons.school_outlined, label: level),
        if (cacheProgress != null)
          BookListCardMeta(
            icon: Icons.downloading_outlined,
            label: '${(cacheProgress!.percent * 100).round()}%',
          ),
      ],
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
