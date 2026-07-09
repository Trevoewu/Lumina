import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/book_sources/gutendex_repository.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../widgets/collapsing_page_scaffold.dart';
import '../album/album_screen.dart';

class GutendexBookDetailScreen extends ConsumerStatefulWidget {
  final GutendexBook book;
  final drift_db.Book? importedBook;

  const GutendexBookDetailScreen({
    super.key,
    required this.book,
    this.importedBook,
  });

  @override
  ConsumerState<GutendexBookDetailScreen> createState() =>
      _GutendexBookDetailScreenState();
}

class _GutendexBookDetailScreenState
    extends ConsumerState<GutendexBookDetailScreen> {
  bool _importing = false;
  drift_db.Book? _importedBook;

  @override
  void initState() {
    super.initState();
    _importedBook = widget.importedBook;
  }

  Future<void> _importOrOpen() async {
    final existing = _importedBook;
    if (existing != null) {
      _openBook(existing);
      return;
    }
    if (_importing) return;
    setState(() => _importing = true);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imported = await ref
          .read(gutendexRepositoryProvider)
          .importPublicDomainBook(
            book: widget.book,
            database: ref.read(appDatabaseProvider),
            appDir: appDir.path,
          );
      if (!mounted) return;
      setState(() => _importedBook = imported);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '已导入《${imported.title}》',
              'Imported "${imported.title}"',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(context.tr('导入失败：$error', 'Import failed: $error')),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _openBook(drift_db.Book book) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AlbumScreen(book: book)));
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final imported = _importedBook != null;
    final summary = book.summary;

    return CollapsingPageScaffold(
      title: context.tr('书籍详情', 'Book Details'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                height: 198,
                child: _RemoteCover(url: book.coverUrl),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.authorLabel,
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.language,
                          label: book.languageLabel,
                        ),
                        _MetaChip(
                          icon: Icons.download_outlined,
                          label: _formatDownloads(book.downloadCount),
                        ),
                        if (book.isPublicDomain)
                          _MetaChip(
                            icon: Icons.public,
                            label: context.tr('公版', 'Public domain'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: design.spaceXl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: book.canImport && !_importing ? _importOrOpen : null,
              icon: _importing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(imported ? Icons.menu_book_outlined : Icons.add),
              label: Text(
                _importing
                    ? context.tr('导入中', 'Importing')
                    : imported
                    ? context.tr('打开书籍', 'Open Book')
                    : context.tr('导入书籍', 'Import Book'),
              ),
            ),
          ),
          if (summary != null) ...[
            SizedBox(height: design.spaceXl),
            Text(
              context.tr('内容简介', 'Summary'),
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              summary,
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemoteCover extends StatelessWidget {
  final String? url;

  const _RemoteCover({this.url});

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: context.appSurfaceHighlight,
        child: imageUrl == null
            ? _placeholder(context)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _placeholder(context);
                },
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: Icon(
        Icons.auto_stories_outlined,
        color: context.appTextSecondary,
        size: 42,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.appTextSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

String _formatDownloads(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}
