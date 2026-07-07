import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../domain/models/chapter_manifest.dart';
import '../../../services/app_log_service.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../album/album_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Future<_SearchData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _future = _load(value.trim()));
    });
  }

  Future<_SearchData> _load(String query) async {
    final db = ref.read(appDatabaseProvider);
    final books = await db.getAllBooks();
    final chapters = await db.getAllChapters();
    final bookById = {for (final book in books) book.id: book};
    final chapterById = {for (final chapter in chapters) chapter.id: chapter};

    if (query.isEmpty) {
      final recent = [...books]
        ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
      return _SearchData(recentBooks: recent.take(8).toList());
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return CollapsingPageScaffold(
      title: context.tr('搜索', 'Search'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              autofocus: true,
              style: TextStyle(color: context.appTextPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.appSurface,
                hintText: context.tr(
                  '搜索书籍、章节或正文',
                  'Search books, chapters, or text',
                ),
                hintStyle: TextStyle(color: context.appTextSecondary),
                prefixIcon: Icon(Icons.search, color: context.appTextSecondary),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('清空', 'Clear'),
                        icon: Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _future = _load(''));
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<_SearchData>(
              future: _future,
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting &&
                    data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (data == null) return const SizedBox.shrink();
                return _buildResults(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(_SearchData data) {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      if (data.recentBooks.isEmpty) {
        return Center(
          child: Text(
            context.tr('暂无书籍', 'No books yet'),
            style: TextStyle(color: context.appTextSecondary),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _section(context.tr('最近阅读', 'Recently Read')),
          for (final book in data.recentBooks)
            _BookResultTile(book: book, onTap: () => _openBook(book)),
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
          context.tr('没有找到结果', 'No results found'),
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        if (data.bookHits.isNotEmpty) ...[
          _section(context.tr('书籍', 'Books')),
          for (final book in data.bookHits)
            _BookResultTile(book: book, onTap: () => _openBook(book)),
        ],
        if (data.chapterHits.isNotEmpty) ...[
          _section(context.tr('章节', 'Chapters')),
          for (final hit in data.chapterHits)
            _ResultTile(
              icon: Icons.queue_music_outlined,
              title: hit.chapter.title,
              subtitle: hit.book!.title,
              onTap: () => _openChapter(hit.book!, hit.chapter),
            ),
        ],
        if (data.paragraphHits.isNotEmpty) ...[
          _section(context.tr('正文', 'Text')),
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

  void _openBook(drift_db.Book book) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AlbumScreen(book: book)));
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
        final audioRoot = await manifestStore.audioRoot(book.id);
        await handler.loadChapter(
          manifest: manifest,
          audioRoot: audioRoot.path,
          bookTitle: book.title,
          chapterTitle: chapter.title,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('播放缓存失败，请清除音频后重新生成')));
        return;
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('这一段音频还未缓存，已打开对应章节')));
    _openChapter(book, chapter);
  }
}

class _SearchData {
  final List<drift_db.Book> recentBooks;
  final List<drift_db.Book> bookHits;
  final List<_ChapterHit> chapterHits;
  final List<_ParagraphHit> paragraphHits;

  const _SearchData({
    this.recentBooks = const [],
    this.bookHits = const [],
    this.chapterHits = const [],
    this.paragraphHits = const [],
  });
}

class _ChapterHit {
  final drift_db.Chapter chapter;
  final drift_db.Book? book;

  const _ChapterHit(this.chapter, this.book);
}

class _ParagraphHit {
  final drift_db.Paragraph paragraph;
  final drift_db.Book? book;
  final drift_db.Chapter? chapter;

  const _ParagraphHit(this.paragraph, this.book, this.chapter);
}

class _BookResultTile extends StatelessWidget {
  final drift_db.Book book;
  final VoidCallback onTap;

  const _BookResultTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ResultTile(
      icon: Icons.menu_book_rounded,
      title: book.title,
      subtitle: '${book.author ?? 'Unknown Author'} · ${book.chapterCount} 章',
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
