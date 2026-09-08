import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/book_sources/gutendex_repository.dart';
import '../../../data/book_sources/librivox_repository.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../domain/models/chapter_manifest.dart';
import '../../../domain/models/book_rights.dart';
import '../../../services/app_log_service.dart';
import '../../../services/book_playback_queue.dart';
import '../../widgets/book_card_metadata.dart';
import '../../widgets/book_list_card.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_search_field.dart';
import '../album/album_screen.dart';
import '../library/gutendex_book_detail_screen.dart';
import '../library/librivox_book_detail_screen.dart';
import 'discover_scope.dart';
import 'discover_editorial_feed.dart';
import 'podcast_discover_view.dart';

/// 底部导航的「发现」页：书籍与播客的统一搜索与发现入口。
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Future<_SearchData>? _future;
  Future<_OnlineSearchData>? _onlineFuture;
  Future<_LibrivoxSearchData>? _librivoxFuture;
  DiscoverScope _scope = DiscoverScope.onlineBooks;
  Map<int, List<GutendexBook>> _onlinePages = {};
  Map<int, List<LibrivoxBook>> _librivoxPages = {};
  int _onlinePage = 1;
  int _librivoxPage = 1;
  bool _localSearching = false;
  bool _onlineSearching = false;
  bool _librivoxSearching = false;
  String _podcastQuery = '';
  int _podcastToken = 0;

  @override
  void initState() {
    super.initState();
    _loadForScope();
  }

  /// 只加载当前范围需要的数据，切换范围时再按需拉取。
  void _loadForScope() {
    final query = _controller.text.trim();
    switch (_scope) {
      case DiscoverScope.audiobooks:
        _librivoxPages = {};
        _librivoxPage = 1;
        _librivoxSearching = true;
        _librivoxFuture = _startLibrivoxSearch();
      case DiscoverScope.onlineBooks:
        _onlinePages = {};
        _onlinePage = 1;
        _onlineSearching = true;
        _onlineFuture = _startOnlineSearch();
      case DiscoverScope.podcasts:
        _podcastQuery = query;
        _podcastToken++;
      case DiscoverScope.library:
        _localSearching = true;
        _future = _startLocalSearch(query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(_loadForScope);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(_loadForScope);
    });
  }

  Future<_OnlineSearchData> _startOnlineSearch() {
    late final Future<_OnlineSearchData> future;
    future = _loadOnline();
    void finishSearch() {
      if (!mounted || !identical(_onlineFuture, future)) return;
      setState(() => _onlineSearching = false);
    }

    // Handle both outcomes on this observer; FutureBuilder receives the original
    // future so it can still display failures without an unhandled error branch.
    unawaited(
      future.then<void>((data) {
        if (mounted && identical(_onlineFuture, future)) {
          _onlinePages = data.pages;
        }
        finishSearch();
      }, onError: (Object error, StackTrace stackTrace) => finishSearch()),
    );
    return future;
  }

  Future<_LibrivoxSearchData> _startLibrivoxSearch() {
    late final Future<_LibrivoxSearchData> future;
    future = _loadLibrivox();
    void finishSearch() {
      if (!mounted || !identical(_librivoxFuture, future)) return;
      setState(() => _librivoxSearching = false);
    }

    // Handle both outcomes on this observer; FutureBuilder receives the original
    // future so it can still display failures without an unhandled error branch.
    unawaited(
      future.then<void>((data) {
        if (mounted && identical(_librivoxFuture, future)) {
          _librivoxPages = data.pages;
        }
        finishSearch();
      }, onError: (Object error, StackTrace stackTrace) => finishSearch()),
    );
    return future;
  }

  Future<_LibrivoxSearchData> _loadLibrivox() async {
    final query = _controller.text.trim();
    final page = _librivoxPage;
    final pages = Map<int, List<LibrivoxBook>>.of(_librivoxPages);
    final db = ref.read(appDatabaseProvider);
    final storedBooks = await db.getAllBooks();
    final importedById = <String, drift_db.Book>{};
    for (final book in storedBooks) {
      if (book.externalSource == librivoxSourceId && book.externalId != null) {
        importedById[book.externalId!] = book;
      }
    }
    final result = await ref
        .read(librivoxRepositoryProvider)
        .search(query: query, page: page);
    pages[page] = result.books;
    final combined = [
      for (var number = 1; number <= page; number++) ...?pages[number],
    ];
    return _LibrivoxSearchData(
      result: LibrivoxSearchResult(books: combined, hasMore: result.hasMore),
      pages: pages,
      importedById: importedById,
      query: query,
      page: page,
    );
  }

  Future<_SearchData> _startLocalSearch(String query) {
    late final Future<_SearchData> future;
    future = _load(query);
    void finishSearch() {
      if (!mounted || !identical(_future, future)) return;
      setState(() => _localSearching = false);
    }

    // Handle both outcomes on this observer; FutureBuilder receives the original
    // future so it can still display failures without an unhandled error branch.
    unawaited(
      future.then<void>(
        (_) => finishSearch(),
        onError: (Object error, StackTrace stackTrace) => finishSearch(),
      ),
    );
    return future;
  }

  Future<_OnlineSearchData> _loadOnline() async {
    final query = _controller.text.trim();
    final page = _onlinePage;
    final pages = Map<int, List<GutendexBook>>.of(_onlinePages);
    final db = ref.read(appDatabaseProvider);
    final books = await db.getAllBooks();
    final importedByGutendexId = <int, drift_db.Book>{};
    for (final book in books) {
      if (book.externalSource != gutendexSourceId) continue;
      final externalId = int.tryParse(book.externalId ?? '');
      if (externalId != null) importedByGutendexId[externalId] = book;
    }
    final result = await ref
        .read(gutendexRepositoryProvider)
        .search(query: query, page: page);
    pages[page] = result.books;
    final combined = [
      for (var number = 1; number <= page; number++) ...?pages[number],
    ];
    return _OnlineSearchData(
      result: GutendexSearchResult(
        count: result.count,
        next: result.next,
        previous: result.previous,
        books: combined,
      ),
      pages: pages,
      importedByGutendexId: importedByGutendexId,
      query: query,
      page: page,
    );
  }

  Future<_SearchData> _load(String query) async {
    final db = ref.read(appDatabaseProvider);
    final books = await db.getAllBooks();
    final chapters = await db.getAllChapters();
    final finishedChapterIndexesByBook = await db
        .getFinishedChapterIndexesByBook();
    final bookById = {for (final book in books) book.id: book};
    final chapterById = {for (final chapter in chapters) chapter.id: chapter};

    if (query.isEmpty) {
      final recent = [...books]
        ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
      return _SearchData(
        recentBooks: recent.take(8).toList(),
        finishedChapterIndexesByBook: finishedChapterIndexesByBook,
      );
    }

    final lower = query.toLowerCase();
    bool contains(String? value) => (value ?? '').toLowerCase().contains(lower);

    final bookHits = books
        .where((book) => contains(book.title) || contains(book.author))
        .take(12)
        .toList();
    final chapterHits = chapters
        .where((chapter) => contains(chapter.title))
        .take(24)
        .map((chapter) => _ChapterHit(chapter, bookById[chapter.bookId]))
        .where((hit) => hit.book != null)
        .toList();
    final paragraphHits = (await db.searchParagraphs(query, limit: 60))
        .map(
          (paragraph) => _ParagraphHit(
            paragraph,
            bookById[paragraph.bookId],
            chapterById[paragraph.chapterId],
          ),
        )
        .where((hit) => hit.book != null && hit.chapter != null)
        .toList();

    return _SearchData(
      bookHits: bookHits,
      chapterHits: chapterHits,
      paragraphHits: paragraphHits,
      finishedChapterIndexesByBook: finishedChapterIndexesByBook,
    );
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    // Podcast 范围有自己的加载指示，这里只反映书籍类检索的进度。
    final searching = switch (_scope) {
      DiscoverScope.audiobooks => _librivoxSearching,
      DiscoverScope.onlineBooks => _onlineSearching,
      DiscoverScope.podcasts => false,
      DiscoverScope.library => _localSearching,
    };

    return CollapsingPageScaffold(
      title: context.tr('发现', 'Discover', '発見'),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              inset,
              design.spaceSm,
              inset,
              design.spaceSm,
            ),
            child: AppSearchField(
              fieldKey: const ValueKey('discover-search-field'),
              controller: _controller,
              onChanged: _onQueryChanged,
              autofocus: false,
              autocorrect: _scope != DiscoverScope.podcasts,
              enableSuggestions: _scope != DiscoverScope.podcasts,
              loading: searching,
              onSubmitted: (_) => _runSearch(),
              onSearch: _runSearch,
              hintText: _scope.hintText(context),
            ),
          ),
          SingleChildScrollView(
            key: const ValueKey('discover-scope-selector'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(inset, 0, inset, design.spaceMd),
            child: Row(
              spacing: design.spaceSm,
              children: [
                for (final scope in [
                  DiscoverScope.onlineBooks,
                  DiscoverScope.audiobooks,
                  DiscoverScope.podcasts,
                  DiscoverScope.library,
                ])
                  ChoiceChip(
                    label: Text(scope.label(context)),
                    selected: _scope == scope,
                    showCheckmark: false,
                    onSelected: (_) {
                      if (scope == _scope) return;
                      _debounce?.cancel();
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _scope = scope;
                        _loadForScope();
                      });
                    },
                  ),
              ],
            ),
          ),
          if (_controller.text.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: TextButton.icon(
                  key: const ValueKey('discover-return-to-browse'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(context.tr('返回发现', 'Back to discovery', '発見に戻る')),
                  onPressed: () {
                    _controller.clear();
                    FocusManager.instance.primaryFocus?.unfocus();
                    _runSearch();
                  },
                ),
              ),
            ),
          Expanded(
            child: switch (_scope) {
              DiscoverScope.audiobooks => _buildLibrivoxFuture(inset),
              DiscoverScope.onlineBooks => _buildOnlineFuture(inset),
              DiscoverScope.podcasts => PodcastDiscoverView(
                query: _podcastQuery,
                searchToken: _podcastToken,
                inset: inset,
              ),
              DiscoverScope.library => _buildLocalFuture(),
            },
          ),
        ],
      ),
    );
  }

  void _exploreAuthor(String author) {
    _controller.text = author;
    FocusManager.instance.primaryFocus?.unfocus();
    _runSearch();
  }

  void _runSearch() {
    _debounce?.cancel();
    setState(_loadForScope);
  }

  Widget _buildLocalFuture() {
    return FutureBuilder<_SearchData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data == null) return const SizedBox.shrink();
        return _withSearchProgress(
          visible: _localSearching,
          child: _buildResults(data),
        );
      },
    );
  }

  Widget _buildOnlineFuture(double inset) {
    return FutureBuilder<_OnlineSearchData>(
      future: _onlineFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            data == null) {
          return _controller.text.trim().isEmpty
              ? const DiscoverEditorialLoading()
              : const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _OnlineErrorState(
            message: snapshot.error.toString(),
            onRetry: _runSearch,
          );
        }
        if (data == null) return const SizedBox.shrink();
        return _withSearchProgress(
          visible: _onlineSearching,
          child: _buildOnlineResults(data, inset),
        );
      },
    );
  }

  Widget _buildLibrivoxFuture(double inset) {
    return FutureBuilder<_LibrivoxSearchData>(
      future: _librivoxFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            data == null) {
          return _controller.text.trim().isEmpty
              ? const DiscoverEditorialLoading()
              : const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _OnlineErrorState(
            message: snapshot.error.toString(),
            onRetry: _runSearch,
          );
        }
        if (data == null) return const SizedBox.shrink();
        return _withSearchProgress(
          visible: _librivoxSearching,
          child: _buildLibrivoxResults(data, inset),
        );
      },
    );
  }

  Widget _withSearchProgress({required bool visible, required Widget child}) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: visible
                ? const LinearProgressIndicator(minHeight: 2)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineResults(_OnlineSearchData data, double inset) {
    final books = data.result.books;
    if (books.isEmpty) {
      return Center(
        child: Text(
          context.tr(
            '没有找到可导入的公版书',
            'No importable public-domain books found',
            'インポートできるパブリックドメイン本が見つかりません',
          ),
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }

    if (data.query.isEmpty) {
      return DiscoverEditorialFeed(
        audiobooks: false,
        books: [
          for (final book in books)
            _editorialOnlineBook(book, data.importedByGutendexId[book.id]),
        ],
        onExploreAuthor: _exploreAuthor,
        onNextPage: data.result.next != null
            ? () {
                if (_onlineSearching) return;
                setState(() {
                  _onlinePage++;
                  _onlineSearching = true;
                  _onlineFuture = _startOnlineSearch();
                });
              }
            : null,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(inset, 4, inset, 120),
      itemBuilder: (context, index) {
        if (index == books.length) {
          return Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.expand_more),
              label: Text(context.tr('加载更多', 'Load More', 'さらに読み込む')),
              onPressed: data.result.next == null || _onlineSearching
                  ? null
                  : () => setState(() {
                      _onlinePage++;
                      _onlineSearching = true;
                      _onlineFuture = _startOnlineSearch();
                    }),
            ),
          );
        }
        final book = books[index];
        final imported = data.importedByGutendexId[book.id];
        final importedReadingLevel = imported == null
            ? null
            : bookReadingLevelLabel(context, imported);
        return BookListCard(
          title: book.title,
          subtitle: book.authorLabel,
          remoteCoverUrl: book.coverUrl,
          metadata: [
            BookListCardMeta(icon: Icons.language, label: book.languageLabel),
            BookListCardMeta(
              icon: Icons.download_outlined,
              label: _formatDownloads(book.downloadCount),
            ),
            if (imported != null)
              BookListCardMeta(
                icon: Icons.check_circle_outline,
                label: context.tr('已导入', 'Imported', 'インポート済み'),
              ),
            if (importedReadingLevel != null)
              BookListCardMeta(
                icon: Icons.school_outlined,
                label: importedReadingLevel,
              ),
          ],
          onTap: () => _openOnlineBook(book, imported),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: books.length + (data.result.next == null ? 0 : 1),
    );
  }

  DiscoverEditorialBook _editorialOnlineBook(
    GutendexBook book,
    drift_db.Book? imported,
  ) => DiscoverEditorialBook(
    id: book.id.toString(),
    title: book.title,
    author: book.authorLabel,
    coverUrl: book.coverUrl,
    description: book.summary,
    metadata: [
      '${book.languageLabel} · ${context.tr('公版书', 'Public domain', 'パブリックドメイン')}',
      if (imported != null) context.tr('已导入', 'Imported', 'インポート済み'),
    ].join(' · '),
    onTap: () => _openOnlineBook(book, imported),
  );

  Future<void> _openOnlineBook(
    GutendexBook book,
    drift_db.Book? imported,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GutendexBookDetailScreen(book: book, importedBook: imported),
      ),
    );
    if (!mounted) return;
    setState(() {
      _onlineSearching = true;
      _onlineFuture = _startOnlineSearch();
    });
  }

  Widget _buildLibrivoxResults(_LibrivoxSearchData data, double inset) {
    final books = data.result.books;
    if (books.isEmpty) {
      return Center(
        child: Text(
          context.tr(
            '没有找到可播放的真人有声书',
            'No playable human-narrated audiobooks found',
            '再生できる人間朗読のオーディオブックが見つかりません',
          ),
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }
    if (data.query.isEmpty) {
      return DiscoverEditorialFeed(
        audiobooks: true,
        books: [
          for (final book in books)
            _editorialLibrivoxBook(book, data.importedById[book.id]),
        ],
        onExploreAuthor: _exploreAuthor,
        onNextPage: data.result.hasMore
            ? () {
                if (_librivoxSearching) return;
                setState(() {
                  _librivoxPage++;
                  _librivoxSearching = true;
                  _librivoxFuture = _startLibrivoxSearch();
                });
              }
            : null,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(inset, 4, inset, 120),
      itemCount: books.length + (data.result.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == books.length) {
          return Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.expand_more),
              label: Text(context.tr('加载更多', 'Load More', 'さらに読み込む')),
              onPressed: _librivoxSearching
                  ? null
                  : () => setState(() {
                      _librivoxPage++;
                      _librivoxSearching = true;
                      _librivoxFuture = _startLibrivoxSearch();
                    }),
            ),
          );
        }
        final book = books[index];
        final imported = data.importedById[book.id];
        return BookListCard(
          title: book.title,
          subtitle: book.authorLabel,
          remoteCoverUrl: book.coverUrl,
          metadata: [
            BookListCardMeta(icon: Icons.language, label: book.language),
            BookListCardMeta(
              icon: Icons.schedule,
              label: _formatAudiobookDuration(book.totalTimeSeconds),
            ),
            BookListCardMeta(
              icon: Icons.record_voice_over_outlined,
              label: context.tr('真人朗读', 'Human narrated', '人間による朗読'),
            ),
            if (imported != null)
              BookListCardMeta(
                icon: Icons.check_circle_outline,
                label: context.tr('已加入', 'Added', '追加済み'),
              ),
          ],
          onTap: () => _openLibrivoxBook(book, imported),
        );
      },
    );
  }

  DiscoverEditorialBook _editorialLibrivoxBook(
    LibrivoxBook book,
    drift_db.Book? imported,
  ) => DiscoverEditorialBook(
    id: book.id.toString(),
    title: book.title,
    author: book.authorLabel,
    coverUrl: book.coverUrl,
    description: book.description,
    metadata: [
      context.tr('真人朗读', 'Human narrated', '人間による朗読'),
      _formatAudiobookDuration(book.totalTimeSeconds),
      if (imported != null) context.tr('已加入', 'Added', '追加済み'),
    ].join(' · '),
    onTap: () => _openLibrivoxBook(book, imported),
  );

  Future<void> _openLibrivoxBook(
    LibrivoxBook book,
    drift_db.Book? imported,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LibrivoxBookDetailScreen(book: book, importedBook: imported),
      ),
    );
    if (!mounted) return;
    setState(() {
      _librivoxSearching = true;
      _librivoxFuture = _startLibrivoxSearch();
    });
  }

  Widget _buildResults(_SearchData data) {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      if (data.recentBooks.isEmpty) {
        return Center(
          child: Text(
            context.tr('暂无书籍', 'No books yet', '本はまだありません'),
            style: TextStyle(color: context.appTextSecondary),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _section(context.tr('最近阅读', 'Recently Read', '最近読んだ本')),
          for (final book in data.recentBooks)
            _BookResultTile(
              book: book,
              finishedChapterIndexes:
                  data.finishedChapterIndexesByBook[book.id] ?? const <int>{},
              onTap: () => _openBook(book),
            ),
        ],
      );
    }

    final empty =
        data.bookHits.isEmpty &&
        data.chapterHits.isEmpty &&
        data.paragraphHits.isEmpty;
    if (empty) {
      return Center(
        child: Text(
          context.tr('没有找到结果', 'No results found', '結果が見つかりません'),
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        if (data.bookHits.isNotEmpty) ...[
          _section(context.tr('书籍', 'Books', '本')),
          for (final book in data.bookHits)
            _BookResultTile(
              book: book,
              finishedChapterIndexes:
                  data.finishedChapterIndexesByBook[book.id] ?? const <int>{},
              onTap: () => _openBook(book),
            ),
        ],
        if (data.chapterHits.isNotEmpty) ...[
          _section(context.tr('章节', 'Chapters', '章')),
          for (final hit in data.chapterHits)
            _ResultTile(
              icon: Icons.queue_music_outlined,
              title: hit.chapter.title,
              subtitle: hit.book!.title,
              onTap: () => _openChapter(hit.book!, hit.chapter),
            ),
        ],
        if (data.paragraphHits.isNotEmpty) ...[
          _section(context.tr('正文', 'Text', '本文')),
          for (final hit in data.paragraphHits)
            _ResultTile(
              icon: Icons.notes_outlined,
              title: hit.paragraph.content,
              subtitle: '${hit.book!.title} · ${hit.chapter!.title}',
              maxTitleLines: 2,
              onTap: () => _openParagraph(hit),
            ),
        ],
      ],
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label,
        style: TextStyle(
          color: context.appTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openBook(drift_db.Book book) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AlbumScreen(book: book)));
    if (!mounted) return;
    setState(() {
      _localSearching = true;
      _future = _startLocalSearch(_controller.text.trim());
    });
  }

  void _openChapter(drift_db.Book book, drift_db.Chapter chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumScreen(book: book, initialChapterId: chapter.id),
      ),
    );
  }

  Future<void> _openParagraph(_ParagraphHit hit) async {
    final book = hit.book;
    final chapter = hit.chapter;
    if (book == null || chapter == null) return;

    final paragraphLabel = context.tr('段落', 'Paragraph', '段落');
    final manifestStore = ref.read(manifestStoreProvider);
    final manifest = await manifestStore.load(book.id, chapter.id);
    if (manifest != null &&
        manifest.segments.any(
          (segment) =>
              segment.paragraphId == hit.paragraph.id &&
              segment.state == ParagraphAudioState.ready,
        )) {
      try {
        final handler = await ref.read(luminaAudioHandlerProvider.future);
        await loadBookPlaybackQueue(
          handler: handler,
          database: ref.read(appDatabaseProvider),
          manifestStore: manifestStore,
          bookId: book.id,
          bookTitle: book.title,
          coverPath: book.coverPath,
          initialManifest: manifest,
          paragraphLabel: paragraphLabel,
        );
        await handler.playFromParagraph(hit.paragraph.id);
      } catch (error, stackTrace) {
        AppLogger.error(
          'Playback',
          '搜索结果播放失败 book=${book.id} chapter=${chapter.id}',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                '播放缓存失败，请清除音频后重新生成',
                'Unable to play cached audio. Clear it and generate it again.',
                'キャッシュ済み音声を再生できません。消去して、もう一度生成してください。',
              ),
            ),
          ),
        );
        return;
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            '这一段音频还未缓存，已打开对应章节',
            'This paragraph is not cached yet. Its chapter has been opened.',
            'この段落はまだキャッシュされていません。章を開きました。',
          ),
        ),
      ),
    );
    _openChapter(book, chapter);
  }
}

class _SearchData {
  final List<drift_db.Book> recentBooks;
  final List<drift_db.Book> bookHits;
  final List<_ChapterHit> chapterHits;
  final List<_ParagraphHit> paragraphHits;
  final Map<String, Set<int>> finishedChapterIndexesByBook;

  const _SearchData({
    this.recentBooks = const [],
    this.bookHits = const [],
    this.chapterHits = const [],
    this.paragraphHits = const [],
    this.finishedChapterIndexesByBook = const <String, Set<int>>{},
  });
}

class _OnlineSearchData {
  final Map<int, List<GutendexBook>> pages;
  final String query;
  final int page;
  final GutendexSearchResult result;
  final Map<int, drift_db.Book> importedByGutendexId;

  const _OnlineSearchData({
    required this.pages,
    required this.query,
    required this.page,
    required this.result,
    required this.importedByGutendexId,
  });
}

class _LibrivoxSearchData {
  final Map<int, List<LibrivoxBook>> pages;
  final String query;
  final int page;
  final LibrivoxSearchResult result;
  final Map<String, drift_db.Book> importedById;

  const _LibrivoxSearchData({
    required this.pages,
    required this.result,
    required this.importedById,
    required this.query,
    required this.page,
  });
}

class _ChapterHit {
  final drift_db.Chapter chapter;
  final drift_db.Book? book;

  const _ChapterHit(this.chapter, this.book);
}

class _OnlineErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OnlineErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: context.appTextSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('重试', 'Retry', '再試行')),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDownloads(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}

String _formatAudiobookDuration(int seconds) {
  if (seconds <= 0) return '—';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

class _ParagraphHit {
  final drift_db.Paragraph paragraph;
  final drift_db.Book? book;
  final drift_db.Chapter? chapter;

  const _ParagraphHit(this.paragraph, this.book, this.chapter);
}

class _BookResultTile extends StatelessWidget {
  final drift_db.Book book;
  final Set<int> finishedChapterIndexes;
  final VoidCallback onTap;

  const _BookResultTile({
    required this.book,
    required this.finishedChapterIndexes,
    required this.onTap,
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
      ],
      onTap: onTap,
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int maxTitleLines;
  final VoidCallback onTap;

  const _ResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.maxTitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        leading: Icon(icon, color: context.appTextSecondary),
        title: Text(
          title,
          maxLines: maxTitleLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.appTextSecondary),
        ),
        trailing: Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
