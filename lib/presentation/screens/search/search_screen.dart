import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/user_facing_error.dart';
import '../../../data/book_sources/gutendex_repository.dart';
import '../../../data/book_sources/librivox_repository.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../data/podcasts/podcast_index_repository.dart';
import '../../../data/podcasts/podcast_repository.dart';
import '../../../domain/models/book_rights.dart';
import '../../../domain/models/chapter_manifest.dart';
import '../../../services/app_log_service.dart';
import '../../../services/book_playback_queue.dart';
import '../../widgets/book_card_metadata.dart';
import '../../widgets/book_list_card.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_icon.dart';
import '../../widgets/design_system/app_search_field.dart';
import '../../widgets/design_system/editorial_type.dart';
import '../../widgets/podcast_artwork.dart';
import '../album/album_screen.dart';
import 'podcast_discover_section.dart';
import '../library/gutendex_book_detail_screen.dart';
import '../library/librivox_book_detail_screen.dart';
import '../podcast/podcast_discovery_detail_screen.dart';
import 'search_history.dart';

/// Rows a source shows before "Show all".
const _collapsedRows = 3;

/// Bumped when something outside the page, such as the tab bar's search
/// button, asks Search to take the keyboard.
final searchFieldFocusRequestProvider =
    NotifierProvider<SearchFieldFocusRequest, int>(SearchFieldFocusRequest.new);

class SearchFieldFocusRequest extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

/// The Search tab: one query across the reader's library, LibriVox
/// audiobooks, Gutenberg books and Podcast Index, grouped by source.
///
/// Before anything is typed it offers what the reader has already shown
/// interest in: recent searches and the authors and podcast genres in their
/// own library.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  Timer? _debounce;
  String _query = '';
  _SearchContext _context = _SearchContext.empty;
  int _podcastRefreshToken = 0;

  Future<List<_LibraryHit>>? _libraryFuture;
  Map<String, Set<int>> _finishedChapters = const {};
  Future<List<LibrivoxBook>>? _audiobooksFuture;
  Future<List<GutendexBook>>? _booksFuture;
  Future<List<PodcastIndexPodcast>>? _podcastsFuture;

  SearchHistory get _history => SearchHistory(ref.read(appDatabaseProvider));

  @override
  void initState() {
    super.initState();
    unawaited(_loadContext());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  /// What the empty state and the "already added" marks are built from.
  Future<void> _loadContext() async {
    final database = ref.read(appDatabaseProvider);
    final results = await Future.wait<Object>([
      database.getAllBooks(),
      database.getPodcastShows(),
      database.getRecentPodcastEpisodes(limit: 30),
      _history.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _context = _SearchContext.from(
        books: results[0] as List<drift_db.Book>,
        shows: results[1] as List<drift_db.PodcastShow>,
        episodes: results[2] as List<drift_db.PodcastEpisode>,
        recentQueries: results[3] as List<String>,
      );
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _runQuery('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _runQuery(value);
    });
  }

  /// Runs [query] everywhere at once. Each source resolves on its own, so a
  /// slow catalog never holds back the others.
  void _runQuery(String query) {
    _debounce?.cancel();
    final term = query.trim();
    if (term == _query && term.isNotEmpty) return;
    setState(() {
      _query = term;
      if (term.isEmpty) {
        _libraryFuture = null;
        _audiobooksFuture = null;
        _booksFuture = null;
        _podcastsFuture = null;
        return;
      }
      _libraryFuture = _observed(_searchLibrary(term));
      _audiobooksFuture = _observed(_searchAudiobooks(term));
      _booksFuture = _observed(_searchBooks(term));
      _podcastsFuture = _observed(_searchPodcasts(term));
    });
  }

  /// A source can fail before its section is built to listen, for instance
  /// at once when offline. Marking the future as observed keeps that from
  /// surfacing as an unhandled error; the section still receives it.
  Future<T> _observed<T>(Future<T> future) => future..ignore();

  /// Fills the field and searches straight away, for recents and shortcuts.
  void _searchFor(String term) {
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    FocusManager.instance.primaryFocus?.unfocus();
    _runQuery(term);
    unawaited(_remember(term));
  }

  Future<void> _remember(String term) async {
    final recent = await _history.record(term);
    if (mounted) setState(() => _context = _context.withRecent(recent));
  }

  Future<void> _clearHistory() async {
    await _history.clear();
    if (mounted) setState(() => _context = _context.withRecent(const []));
  }

  Future<List<_LibraryHit>> _searchLibrary(String query) async {
    final database = ref.read(appDatabaseProvider);
    final books = await database.getAllBooks();
    final chapters = await database.getAllChapters();
    final finished = await database.getFinishedChapterIndexesByBook();
    final bookById = {for (final book in books) book.id: book};
    final chapterById = {for (final chapter in chapters) chapter.id: chapter};
    final lower = query.toLowerCase();
    bool matches(String? value) => (value ?? '').toLowerCase().contains(lower);

    final paragraphs = await database.searchParagraphs(query, limit: 30);
    _finishedChapters = finished;
    return [
      for (final book in books)
        if (matches(book.title) || matches(book.author)) _LibraryHit.book(book),
      for (final chapter in chapters)
        if (matches(chapter.title))
          if (bookById[chapter.bookId] case final book?)
            _LibraryHit.chapter(book, chapter),
      for (final paragraph in paragraphs)
        if ((bookById[paragraph.bookId], chapterById[paragraph.chapterId])
            case (final book?, final chapter?))
          _LibraryHit.text(book, chapter, paragraph),
    ];
  }

  Future<List<LibrivoxBook>> _searchAudiobooks(String query) async =>
      (await ref.read(librivoxRepositoryProvider).search(query: query)).books;

  Future<List<GutendexBook>> _searchBooks(String query) async =>
      (await ref.read(gutendexRepositoryProvider).search(query: query)).books;

  Future<List<PodcastIndexPodcast>> _searchPodcasts(String query) =>
      ref.read(podcastIndexRepositoryProvider).search(query);

  /// Opens a result and keeps the query in recents: opening something is the
  /// clearest sign the search was worth repeating.
  Future<void> _open(Widget page) async {
    if (_query.isNotEmpty) unawaited(_remember(_query));
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _loadContext();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(searchFieldFocusRequestProvider, (_, _) {
      _fieldFocus.requestFocus();
    });
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

    return CollapsingPageScaffold(
      title: context.tr('搜索', 'Search', '検索'),
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
              fieldKey: const ValueKey('search-field'),
              controller: _controller,
              focusNode: _fieldFocus,
              onChanged: _onChanged,
              onSubmitted: (value) {
                _runQuery(value);
                unawaited(_remember(value));
              },
              onSearch: () {
                _runQuery(_controller.text);
                unawaited(_remember(_controller.text));
              },
              hintText: context.tr(
                '书、有声书、播客或作者',
                'Books, audiobooks, podcasts or authors',
                '本、オーディオブック、ポッドキャスト、著者',
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty ? _buildIdle(inset) : _buildResults(inset),
          ),
        ],
      ),
    );
  }

  // ── Before typing ─────────────────────────────────────────────────────────

  Widget _buildIdle(double inset) {
    final gutter = inset + 6;
    final recent = _context.recentQueries;
    final shortcuts = _context.shortcuts;

    return ListView(
      key: const ValueKey('search-idle'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        if (recent.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: _KickerRow(
              label: context.tr('最近搜索', 'RECENT', '最近の検索'),
              actionLabel: context.tr('清除', 'Clear', '消去'),
              actionKey: const ValueKey('search-clear-recent'),
              onAction: _clearHistory,
            ),
          ),
          for (final term in recent)
            _RecentRow(
              key: ValueKey('search-recent-$term'),
              term: term,
              gutter: gutter,
              onTap: () => _searchFor(term),
            ),
          const SizedBox(height: 20),
        ],
        if (shortcuts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: _KickerRow(
              label: context.tr('来自你的书架', 'FROM YOUR LIBRARY', 'あなたの本棚から'),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in shortcuts)
                  _ShortcutChip(
                    key: ValueKey('search-shortcut-$term'),
                    label: term,
                    onTap: () => _searchFor(term),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (recent.isEmpty && shortcuts.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 24),
            child: Text(
              context.tr(
                '一次搜索你的书架、公版书、LibriVox 有声书和播客。',
                'Search your library, public-domain books, LibriVox audiobooks '
                    'and podcasts in one go.',
                '本棚、パブリックドメインの本、LibriVoxのオーディオブック、'
                    'ポッドキャストをまとめて検索できます。',
              ),
              style: TextStyle(color: context.appTextSecondary, height: 1.45),
            ),
          ),
        // Seeded by the reader's own subscriptions, so it only appears once
        // there is something to base it on.
        if (_context.shows.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: PodcastDiscoverSection(
              shows: _context.shows,
              episodes: _context.episodes,
              preferredLanguage: Localizations.localeOf(context).languageCode,
              refreshToken: _podcastRefreshToken,
              onSubscribed: () {
                setState(() => _podcastRefreshToken++);
                unawaited(_loadContext());
              },
            ),
          ),
      ],
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(double inset) {
    final gutter = inset + 6;
    final query = _query;

    return ListView(
      key: ValueKey('search-results-$query'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        top: 4,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        _SourceSection<_LibraryHit>(
          key: const ValueKey('search-section-library'),
          title: context.tr('你的书架', 'IN YOUR LIBRARY', 'あなたの本棚'),
          gutter: gutter,
          inset: inset,
          future: _libraryFuture!,
          emptyLabel: context.tr(
            '书架里没有匹配项',
            'Nothing in your library matches',
            '本棚に一致するものはありません',
          ),
          onRetry: () => setState(() {
            _libraryFuture = _observed(_searchLibrary(query));
          }),
          itemBuilder: (context, hit) => _buildLibraryHit(hit),
        ),
        _SourceSection<LibrivoxBook>(
          key: const ValueKey('search-section-audiobooks'),
          title: context.tr(
            '有声书 · LIBRIVOX',
            'AUDIOBOOKS · LIBRIVOX',
            'オーディオブック · LIBRIVOX',
          ),
          gutter: gutter,
          inset: inset,
          future: _audiobooksFuture!,
          emptyLabel: context.tr(
            '没有匹配的真人朗读有声书',
            'No narrated audiobooks match',
            '一致する朗読オーディオブックはありません',
          ),
          onRetry: () => setState(() {
            _audiobooksFuture = _observed(_searchAudiobooks(query));
          }),
          itemBuilder: (context, book) => _buildAudiobook(book),
        ),
        _SourceSection<GutendexBook>(
          key: const ValueKey('search-section-books'),
          title: context.tr(
            '公版书 · GUTENBERG',
            'PUBLIC-DOMAIN BOOKS · GUTENBERG',
            'パブリックドメインの本 · GUTENBERG',
          ),
          gutter: gutter,
          inset: inset,
          future: _booksFuture!,
          emptyLabel: context.tr(
            '没有匹配的公版书',
            'No public-domain books match',
            '一致するパブリックドメインの本はありません',
          ),
          onRetry: () => setState(() {
            _booksFuture = _observed(_searchBooks(query));
          }),
          itemBuilder: (context, book) => _buildPublicDomainBook(book),
        ),
        _SourceSection<PodcastIndexPodcast>(
          key: const ValueKey('search-section-podcasts'),
          title: context.tr('播客', 'PODCASTS', 'ポッドキャスト'),
          gutter: gutter,
          inset: inset,
          future: _podcastsFuture!,
          emptyLabel: context.tr(
            '没有匹配的播客',
            'No podcasts match',
            '一致するポッドキャストはありません',
          ),
          onRetry: () => setState(() {
            _podcastsFuture = _observed(_searchPodcasts(query));
          }),
          itemBuilder: (context, podcast) => _PodcastRow(
            podcast: podcast,
            subscribed: _context.subscribedFeedUrls.contains(podcast.feedUrl),
            onTap: () => _open(PodcastDiscoveryDetailScreen(podcast: podcast)),
          ),
          footer: const _PodcastIndexCredit(),
        ),
      ],
    );
  }

  Widget _buildLibraryHit(_LibraryHit hit) {
    final book = hit.book;
    switch (hit.kind) {
      case _LibraryHitKind.book:
        return BookListCard(
          title: book.title,
          subtitle: book.author ?? context.tr('未知作者', 'Unknown author', '著者不明'),
          localCoverPath: book.coverPath,
          metadata: [
            BookListCardMeta(
              icon: AppIcons.chartIncrease,
              label: bookReadingProgressLabel(
                context,
                book,
                finishedChapterIndexes:
                    _finishedChapters[book.id] ?? const <int>{},
              ),
            ),
          ],
          onTap: () => _open(AlbumScreen(book: book)),
        );
      case _LibraryHitKind.chapter:
        return _TextRow(
          icon: AppIcons.playList,
          title: hit.chapter!.title,
          subtitle: book.title,
          onTap: () =>
              _open(AlbumScreen(book: book, initialChapterId: hit.chapter!.id)),
        );
      case _LibraryHitKind.text:
        return _TextRow(
          icon: AppIcons.note01,
          title: hit.paragraph!.content,
          subtitle: '${book.title} · ${hit.chapter!.title}',
          maxTitleLines: 2,
          onTap: () => _openParagraph(hit),
        );
    }
  }

  Widget _buildAudiobook(LibrivoxBook book) {
    final imported = _context.importedLibrivox[book.id];
    return BookListCard(
      title: book.title,
      subtitle: book.authorLabel,
      remoteCoverUrl: book.coverUrl,
      metadata: [
        BookListCardMeta(
          icon: AppIcons.clock01,
          label: _audiobookDuration(book.totalTimeSeconds),
        ),
        BookListCardMeta(icon: AppIcons.globe02, label: book.language),
        if (imported != null)
          BookListCardMeta(
            icon: AppIcons.checkmarkCircle02,
            label: context.tr('已加入', 'Added', '追加済み'),
          ),
      ],
      onTap: () =>
          _open(LibrivoxBookDetailScreen(book: book, importedBook: imported)),
    );
  }

  Widget _buildPublicDomainBook(GutendexBook book) {
    final imported = _context.importedGutendex[book.id];
    return BookListCard(
      title: book.title,
      subtitle: book.authorLabel,
      remoteCoverUrl: book.coverUrl,
      metadata: [
        BookListCardMeta(icon: AppIcons.globe02, label: book.languageLabel),
        if (imported != null)
          BookListCardMeta(
            icon: AppIcons.checkmarkCircle02,
            label: context.tr('已导入', 'Imported', 'インポート済み'),
          ),
      ],
      onTap: () =>
          _open(GutendexBookDetailScreen(book: book, importedBook: imported)),
    );
  }

  /// Plays a matching paragraph when its audio is cached, otherwise opens its
  /// chapter.
  Future<void> _openParagraph(_LibraryHit hit) async {
    final book = hit.book;
    final chapter = hit.chapter!;
    final paragraph = hit.paragraph!;
    if (_query.isNotEmpty) unawaited(_remember(_query));

    final paragraphLabel = context.tr('段落', 'Paragraph', '段落');
    final manifestStore = ref.read(manifestStoreProvider);
    final manifest = await manifestStore.load(book.id, chapter.id);
    final cached =
        manifest?.segments.any(
          (segment) =>
              segment.paragraphId == paragraph.id &&
              segment.state == ParagraphAudioState.ready,
        ) ??
        false;
    if (cached) {
      try {
        final handler = await ref.read(luminaAudioHandlerProvider.future);
        await loadBookPlaybackQueue(
          handler: handler,
          database: ref.read(appDatabaseProvider),
          manifestStore: manifestStore,
          bookId: book.id,
          bookTitle: book.title,
          coverPath: book.coverPath,
          initialManifest: manifest!,
          paragraphLabel: paragraphLabel,
        );
        await handler.playFromParagraph(paragraph.id);
        return;
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
    await _open(AlbumScreen(book: book, initialChapterId: chapter.id));
  }

  String _audiobookDuration(int seconds) {
    if (seconds <= 0) return '—';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

// ── Data ────────────────────────────────────────────────────────────────────

class _SearchContext {
  final List<String> recentQueries;
  final List<String> shortcuts;
  final List<drift_db.PodcastShow> shows;
  final List<drift_db.PodcastEpisode> episodes;
  final Set<String> subscribedFeedUrls;
  final Map<int, drift_db.Book> importedGutendex;
  final Map<String, drift_db.Book> importedLibrivox;

  const _SearchContext({
    required this.recentQueries,
    required this.shortcuts,
    required this.shows,
    required this.episodes,
    required this.subscribedFeedUrls,
    required this.importedGutendex,
    required this.importedLibrivox,
  });

  static const empty = _SearchContext(
    recentQueries: [],
    shortcuts: [],
    shows: [],
    episodes: [],
    subscribedFeedUrls: {},
    importedGutendex: {},
    importedLibrivox: {},
  );

  /// Shortcuts are the authors the reader keeps coming back to, most books
  /// first, then the genres of the shows they follow.
  factory _SearchContext.from({
    required List<drift_db.Book> books,
    required List<drift_db.PodcastShow> shows,
    required List<drift_db.PodcastEpisode> episodes,
    required List<String> recentQueries,
  }) {
    return _SearchContext(
      recentQueries: recentQueries,
      shortcuts: [
        ..._mostFrequent([
          for (final book in books)
            if (book.kind != 'podcast') ?_searchableAuthor(book.author),
        ], 6),
        ..._mostFrequent([
          for (final show in shows)
            for (final genre in decodePodcastCategories(show.categoriesJson))
              // Some feeds file themselves under "Podcasts", which says
              // nothing about what they are.
              if (genre.toLowerCase() != 'podcasts') genre,
        ], 4),
      ],
      shows: shows,
      episodes: episodes,
      subscribedFeedUrls: {for (final show in shows) show.feedUrl},
      importedGutendex: {
        for (final book in books)
          if (book.externalSource == gutendexSourceId)
            ?int.tryParse(book.externalId ?? ''): book,
      },
      importedLibrivox: {
        for (final book in books)
          if (book.externalSource == librivoxSourceId) ?book.externalId: book,
      },
    );
  }

  _SearchContext withRecent(List<String> recent) => _SearchContext(
    recentQueries: recent,
    shortcuts: shortcuts,
    shows: shows,
    episodes: episodes,
    subscribedFeedUrls: subscribedFeedUrls,
    importedGutendex: importedGutendex,
    importedLibrivox: importedLibrivox,
  );

  /// Catalogs such as Gutenberg store "Austen, Jane", which other sources
  /// do not match; searches use the name the way it is written on a cover.
  static String? _searchableAuthor(String? author) {
    final name = author?.trim() ?? '';
    if (name.isEmpty) return null;
    final parts = name.split(',');
    if (parts.length != 2) return name;
    final last = parts[0].trim();
    final first = parts[1].trim();
    return first.isEmpty ? last : '$first $last';
  }

  static List<String> _mostFrequent(List<String> values, int count) {
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    // A stable sort keeps first-seen order among ties.
    final ranked = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return ranked.take(count).toList(growable: false);
  }
}

enum _LibraryHitKind { book, chapter, text }

class _LibraryHit {
  final _LibraryHitKind kind;
  final drift_db.Book book;
  final drift_db.Chapter? chapter;
  final drift_db.Paragraph? paragraph;

  const _LibraryHit.book(this.book)
    : kind = _LibraryHitKind.book,
      chapter = null,
      paragraph = null;

  const _LibraryHit.chapter(this.book, this.chapter)
    : kind = _LibraryHitKind.chapter,
      paragraph = null;

  const _LibraryHit.text(this.book, this.chapter, this.paragraph)
    : kind = _LibraryHitKind.text;
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// One source's results: its own loading, error and empty states, and the
/// first few rows with a way to see the rest.
class _SourceSection<T> extends StatefulWidget {
  final String title;
  final double gutter;
  final double inset;
  final Future<List<T>> future;
  final String emptyLabel;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? footer;

  const _SourceSection({
    super.key,
    required this.title,
    required this.gutter,
    required this.inset,
    required this.future,
    required this.emptyLabel,
    required this.onRetry,
    required this.itemBuilder,
    this.footer,
  });

  @override
  State<_SourceSection<T>> createState() => _SourceSectionState<T>();
}

class _SourceSectionState<T> extends State<_SourceSection<T>> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _SourceSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.future, widget.future)) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(
      color: context.appTextSecondary,
      fontSize: 14,
      height: 1.4,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: FutureBuilder<List<T>>(
        future: widget.future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          final done = snapshot.connectionState == ConnectionState.done;
          final visible = _expanded
              ? items
              : items.take(_collapsedRows).toList(growable: false);
          final hidden = items.length - visible.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.gutter),
                child: _KickerRow(
                  label: widget.title,
                  actionLabel: hidden > 0
                      ? context.tr(
                          '全部 ${items.length}',
                          'Show all ${items.length}',
                          'すべて ${items.length}',
                        )
                      : null,
                  onAction: hidden > 0
                      ? () => setState(() => _expanded = true)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              if (!done)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.gutter),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('搜索中…', 'Searching…', '検索中…'),
                        style: secondary,
                      ),
                    ],
                  ),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.gutter),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          userFacingErrorMessage(context, snapshot.error!),
                          style: secondary,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onRetry,
                        child: Text(context.tr('重试', 'Retry', '再試行')),
                      ),
                    ],
                  ),
                )
              else if (items.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.gutter),
                  child: Text(widget.emptyLabel, style: secondary),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.inset),
                  child: Column(
                    children: [
                      for (final (index, item) in visible.indexed) ...[
                        if (index > 0) const SizedBox(height: 8),
                        widget.itemBuilder(context, item),
                      ],
                    ],
                  ),
                ),
              if (done && widget.footer != null) widget.footer!,
            ],
          );
        },
      ),
    );
  }
}

class _KickerRow extends StatelessWidget {
  final String label;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  const _KickerRow({
    required this.label,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(child: Text(label, style: kickerTextStyle(context))),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              key: actionKey,
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final String term;
  final double gutter;
  final VoidCallback onTap;

  const _RecentRow({
    super.key,
    required this.term,
    required this.gutter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 11),
        child: Row(
          children: [
            AppIcon(
              AppIcons.clock01,
              size: 18,
              color: context.appTextSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: context.appTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ShortcutChip({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: context.appTextPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  final AppIconData icon;
  final String title;
  final String subtitle;
  final int maxTitleLines;
  final VoidCallback onTap;

  const _TextRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.maxTitleLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppIcon(icon, size: 18, color: context.appTextSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: maxTitleLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
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
}

class _PodcastRow extends StatelessWidget {
  final PodcastIndexPodcast podcast;
  final bool subscribed;
  final VoidCallback onTap;

  const _PodcastRow({
    required this.podcast,
    required this.subscribed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = [
      ?podcast.author,
      if (podcast.genres.isNotEmpty) podcast.genres.first,
      if (subscribed) context.tr('已订阅', 'Subscribed', '購読済み'),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            PodcastArtwork(imageUrl: podcast.imageUrl, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      metadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Podcast Index asks apps that use its directory to credit it.
class _PodcastIndexCredit extends StatelessWidget {
  const _PodcastIndexCredit();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        key: const ValueKey('podcast-index-attribution'),
        onPressed: () => launchUrl(
          Uri.parse('https://podcastindex.org/'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          'Powered by Podcast Index',
          style: TextStyle(fontSize: 12, color: context.appTextSecondary),
        ),
      ),
    );
  }
}
