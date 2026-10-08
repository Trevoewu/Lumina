import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/book_sources/librivox_repository.dart';
import '../../../data/database/app_database.dart' as drift_db;
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/disk_cached_network_image.dart';
import '../album/album_screen.dart';
import '../search/search_links.dart';

class LibrivoxBookDetailScreen extends ConsumerStatefulWidget {
  final LibrivoxBook book;
  final drift_db.Book? importedBook;

  const LibrivoxBookDetailScreen({
    super.key,
    required this.book,
    this.importedBook,
  });

  @override
  ConsumerState<LibrivoxBookDetailScreen> createState() =>
      _LibrivoxBookDetailScreenState();
}

class _LibrivoxBookDetailScreenState
    extends ConsumerState<LibrivoxBookDetailScreen> {
  bool _importing = false;
  drift_db.Book? _importedBook;

  @override
  void initState() {
    super.initState();
    _importedBook = widget.importedBook;
  }

  Future<void> _addOrOpen() async {
    final existing = _importedBook;
    if (existing != null) {
      _open(existing);
      return;
    }
    if (_importing) return;
    setState(() => _importing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imported = await ref
          .read(librivoxRepositoryProvider)
          .importAudiobook(
            book: widget.book,
            database: ref.read(appDatabaseProvider),
            manifestStore: ref.read(manifestStoreProvider),
            appDir: appDir.path,
          );
      if (!mounted) return;
      setState(() => _importedBook = imported);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '已将《${imported.title}》加入书架',
              'Added “${imported.title}” to your library',
              '「${imported.title}」を本棚に追加しました',
            ),
          ),
        ),
      );
      _open(imported);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '加入失败，请检查网络后重试',
              'Could not add this audiobook. Check your connection and try again.',
              '追加できませんでした。接続を確認してもう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _open(drift_db.Book book) {
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
    return CollapsingPageScaffold(
      title: context.tr('有声书详情', 'Audiobook Details', 'オーディオブックの詳細'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                height: 198,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(design.radiusMedium),
                  child: book.coverUrl == null
                      ? _coverPlaceholder()
                      : DiskCachedNetworkImage(
                          url: book.coverUrl!,
                          placeholder: _coverPlaceholder(),
                        ),
                ),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AuthorSearchLink(author: book.authorLabel, fontSize: 16),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(icon: AppIcons.globe02, label: book.language),
                        _MetaChip(
                          icon: AppIcons.playList,
                          label: context.tr(
                            '${book.sections.length} 章',
                            '${book.sections.length} chapters',
                            '${book.sections.length}章',
                          ),
                        ),
                        _MetaChip(
                          icon: AppIcons.clock01,
                          label: _formatDuration(book.totalTimeSeconds),
                        ),
                        _MetaChip(
                          icon: AppIcons.aiVoice,
                          label: context.tr(
                            '真人朗读',
                            'Human narrated',
                            '人間による朗読',
                          ),
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
              key: const ValueKey('librivox-add-button'),
              onPressed: _importing ? null : _addOrOpen,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : AppIcon(imported ? AppIcons.play : AppIcons.bookPlus),
              label: Text(
                imported
                    ? context.tr('打开并收听', 'Open and listen', '開いて聴く')
                    : context.tr('加入书架', 'Add to library', '本棚に追加'),
              ),
            ),
          ),
          SizedBox(height: design.spaceLg),
          Row(
            children: [
              AppIcon(
                AppIcons.globe02,
                size: 18,
                color: context.appTextSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(
                    'LibriVox 公版录音 · 在线播放',
                    'LibriVox public-domain recording · Streams online',
                    'LibriVoxパブリックドメイン録音・オンライン再生',
                  ),
                  style: TextStyle(color: context.appTextSecondary),
                ),
              ),
            ],
          ),
          if (book.description.isNotEmpty) ...[
            SizedBox(height: design.spaceXl),
            Text(
              context.tr('内容简介', 'Summary', '概要'),
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              book.description,
              style: TextStyle(color: context.appTextSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coverPlaceholder() => ColoredBox(
    color: context.appSurface,
    child: Center(
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedHeadphones,
        size: 52,
        color: context.appTextSecondary,
      ),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  final AppIconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: context.appTextSecondary),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: context.appTextSecondary, fontSize: 12),
        ),
      ],
    ),
  );
}

String _formatDuration(int seconds) {
  if (seconds <= 0) return '—';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}
