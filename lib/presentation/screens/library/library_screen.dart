import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../../services/book_parser.dart';
import '../../widgets/book_cover.dart';
import '../album/album_screen.dart';

/// 书架首页。
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _reloadToken = 0;
  bool _importing = false;
  final Set<String> _coverBackfillStarted = {};

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Your Library',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '导入书籍',
            onPressed: _importing ? null : () => _importBook(context),
            icon: _importing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.add, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: FutureBuilder(
        key: ValueKey(_reloadToken),
        future: db.getAllBooks(),
        builder: (context, snapshot) {
          final books = snapshot.data ?? const <drift_db.Book>[];

          if (books.isEmpty) {
            return _buildEmptyState();
          }

          _backfillMissingCovers(books);

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.66,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
            ),
            itemCount: books.length,
            itemBuilder: (context, i) {
              final book = books[i];
              return _BookCard(
                book: book,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AlbumScreen(book: book)),
                  );
                },
                onEdit: () => _showEditBookSheet(book),
                onReparse: () => _confirmReparseBook(book),
                onClearCache: () => _confirmClearBookCache(book),
                onDelete: () => _confirmDeleteBook(book),
              );
            },
          );
        },
      ),
    );
  }

  void _backfillMissingCovers(List<drift_db.Book> books) {
    for (final book in books) {
      final hasCover =
          book.coverPath != null && File(book.coverPath!).existsSync();
      if (hasCover ||
          book.format != 'epub' ||
          _coverBackfillStarted.contains(book.id)) {
        continue;
      }

      _coverBackfillStarted.add(book.id);
      Future<void>(() async {
        try {
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
        } catch (_) {
          // 封面不是核心数据，提取失败时保留占位图。
        }
      });
    }
  }

  /// 空状态：大图标 + 优雅文案 + 导入按钮。
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 120,
              color: AppColors.surfaceHighlight,
            ),
            const SizedBox(height: 24),
            const Text(
              '你的书架空空如也',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '导入 EPUB 或 TXT 文件，开启你的听书之旅',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                  : const Icon(Icons.upload_file),
              label: Text(
                _importing ? '导入中...' : '导入书籍',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importBook(BuildContext context) async {
    final db = ref.read(appDatabaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);

    try {
      final result = await FilePicker.pickFiles(
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

      await db.upsertBook(
        drift_db.Book(
          id: parsed.book.id,
          title: parsed.book.title,
          author: parsed.book.author,
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
        ),
      );

      await db.insertChapters(
        parsed.chapters
            .map(
              (c) => drift_db.Chapter(
                id: c.id,
                bookId: c.bookId,
                chapterIndex: c.index,
                title: c.title,
                textOffset: c.textOffset,
              ),
            )
            .toList(),
      );

      await db.insertParagraphs(
        parsed.paragraphs
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
    } catch (e) {
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
        title: const Text('删除书籍？'),
        content: Text('将删除《${book.title}》及其章节、歌词、生成音频和导入文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
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
      await ref.read(cacheManagerProvider).clearBook(book.id);
      await _deleteImportedBookFiles(book);
      await ref.read(appDatabaseProvider).deleteBookCascade(book.id);
      if (!mounted) return;
      setState(() => _reloadToken++);
      messenger.showSnackBar(SnackBar(content: Text('已删除《${book.title}》')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('删除失败：$e'),
        ),
      );
    }
  }

  Future<void> _confirmClearBookCache(drift_db.Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除音频缓存？'),
        content: Text('将删除《${book.title}》已经生成的所有音频，书籍和章节内容会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
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
    } catch (e) {
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
        title: const Text('重新解析书籍？'),
        content: Text('将重建《${book.title}》的章节和段落，并清除这本书已生成的音频缓存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重新解析'),
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
      await ref.read(cacheManagerProvider).clearBook(book.id);

      final appDir = await getApplicationDocumentsDirectory();
      final parsed = await BookParser.reparseExisting(
        sourcePath: book.sourcePath,
        bookId: book.id,
        appDir: appDir.path,
      );
      await ref
          .read(appDatabaseProvider)
          .replaceBookData(
            book: drift_db.Book(
              id: parsed.book.id,
              title: parsed.book.title,
              author: parsed.book.author,
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
            ),
            chapterEntries: parsed.chapters
                .map(
                  (c) => drift_db.Chapter(
                    id: c.id,
                    bookId: c.bookId,
                    chapterIndex: c.index,
                    title: c.title,
                    textOffset: c.textOffset,
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

      if (!mounted) return;
      setState(() => _reloadToken++);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '重新解析完成：${parsed.chapters.length} 章，${parsed.paragraphs.length} 段',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('重新解析失败：$e'),
        ),
      );
    }
  }

  Future<void> _showEditBookSheet(drift_db.Book book) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author ?? '');
    String? coverPath = book.coverPath;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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
                    const Text(
                      '编辑书籍',
                      style: TextStyle(
                        color: AppColors.textPrimary,
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
                          avatar: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('更换封面'),
                          onPressed: () async {
                            final picked = await FilePicker.pickFiles(
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
                            avatar: const Icon(
                              Icons.hide_image_outlined,
                              size: 18,
                            ),
                            label: const Text('移除封面'),
                            onPressed: () =>
                                setSheetState(() => coverPath = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('保存'),
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;
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
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.background,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
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

/// 书籍卡片：圆角封面占位 + 标题 + 作者 + 章节数。
class _BookCard extends StatelessWidget {
  final drift_db.Book book;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onReparse;
  final VoidCallback onClearCache;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    required this.onTap,
    required this.onEdit,
    required this.onReparse,
    required this.onClearCache,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const detailsHeight = 74.0;
        final coverSize = math.min(
          constraints.maxWidth,
          math.max(0.0, constraints.maxHeight - detailsHeight),
        );

        return GestureDetector(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: coverSize,
                height: coverSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BookCover(
                        coverPath: book.coverPath,
                        placeholderIcon: Icons.menu_book_rounded,
                        iconSize: 56,
                        borderRadius: 8,
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            book.format.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: detailsHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 18,
                      child: Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 16,
                      child: Text(
                        book.author ?? 'Unknown Author',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.headphones_outlined,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${book.chapterCount} 章',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 28,
                          height: 18,
                          child: _BookActionsButton(
                            onEdit: onEdit,
                            onReparse: onReparse,
                            onClearCache: onClearCache,
                            onDelete: onDelete,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BookActionsButton extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onReparse;
  final VoidCallback onClearCache;
  final VoidCallback onDelete;

  const _BookActionsButton({
    required this.onEdit,
    required this.onReparse,
    required this.onClearCache,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '书籍操作',
      color: AppColors.surface,
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'reparse') onReparse();
        if (value == 'cache') onClearCache();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text('编辑'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reparse',
          child: Row(
            children: [
              Icon(Icons.auto_fix_high_outlined, size: 18),
              SizedBox(width: 8),
              Text('重新解析'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'cache',
          child: Row(
            children: [
              Icon(Icons.cleaning_services_outlined, size: 18),
              SizedBox(width: 8),
              Text('清除音频'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18),
              SizedBox(width: 8),
              Text('删除'),
            ],
          ),
        ),
      ],
    );
  }
}
