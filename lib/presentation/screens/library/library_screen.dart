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
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';
import '../../../tts/tts_provider.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/book_card_metadata.dart';
import '../../widgets/book_list_card.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../album/album_screen.dart';
import '../search/search_screen.dart';

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
  final Map<String, _BookCacheProgress> _bookCacheProgress = {};

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

    return CollapsingPageScaffold(
      title: context.tr('书架', 'Your Library'),
      actions: [
        IconButton(
          tooltip: context.tr('搜索书籍', 'Search Books'),
          onPressed: () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
            if (mounted) setState(() => _reloadToken++);
          },
          icon: Icon(Icons.search, color: context.appTextPrimary),
        ),
        IconButton(
          tooltip: context.tr('导入书籍', 'Import Book'),
          onPressed: _importing ? null : () => _importBook(context),
          icon: _importing
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: accent,
                  ),
                )
              : Icon(Icons.add, color: context.appTextPrimary),
        ),
      ],
      body: FutureBuilder<List<drift_db.Book>>(
        key: ValueKey(_reloadToken),
        future: db.getAllBooks(),
        builder: (context, snapshot) {
          final books = snapshot.data ?? const <drift_db.Book>[];

          if (books.isEmpty) {
            return _buildEmptyState();
          }

          _backfillMissingCovers(books);

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(inset, design.spaceLg, inset, 120),
            itemCount: books.length,
            separatorBuilder: (_, _) => SizedBox(height: design.spaceMd),
            itemBuilder: (context, i) {
              final book = books[i];
              return _BookCard(
                book: book,
                cacheProgress: _bookCacheProgress[book.id],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AlbumScreen(book: book)),
                  );
                },
                onEdit: () => _showEditBookSheet(book),
                onReparse: () => _confirmReparseBook(book),
                onCacheBook: () => _cacheWholeBook(book),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              context.tr('你的书架空空如也', 'Your library is empty'),
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
          language: inferLanguageFromTitle(parsed.book.title),
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
          kind: 'book',
          rightsStatus: userUploadedRightsStatus,
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
      await ref.read(cacheManagerProvider).clearBook(book.id);
      await _deleteImportedBookFiles(book);
      await ref.read(appDatabaseProvider).deleteBookCascade(book.id);
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
        title: context.tr('无法缓存', 'Unable to cache'),
        message: context.tr('这本书没有可缓存的章节。', 'This book has no chapters.'),
      );
      return;
    }

    try {
      final provider = await _resolveProvider();
      final voice = await _resolveVoice(book, provider);
      if (!mounted) return;
      if (voice == null) {
        await _showCacheMessage(
          title: context.tr('没有可用音色', 'No voice available'),
          message: context.tr(
            '${provider.displayName} 没有可用于合成的音色。',
            '${provider.displayName} has no voice available for generation.',
          ),
        );
        return;
      }
      final providerValid = await provider.validate();
      if (!mounted) return;
      if (!providerValid) {
        await _showCacheMessage(
          title: context.tr('语音引擎未配置', 'TTS provider not configured'),
          message: context.tr(
            '请先完成 ${provider.displayName} 的模型或 API Key 配置。',
            'Configure the model or API key for ${provider.displayName} first.',
          ),
        );
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('缓存整本书？', 'Cache the entire book?')),
          content: Text(
            context.tr(
              '将使用 ${provider.displayName} · ${voice.name} 依次缓存《${book.title}》的 '
                  '${chapters.length} 个章节。已完成的段落会自动跳过。',
              'Cache all ${chapters.length} chapters of “${book.title}” with '
                  '${provider.displayName} · ${voice.name}. Completed segments will be skipped.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.tr('取消', 'Cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(context.tr('开始缓存', 'Start caching')),
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
            ? context.tr('缓存完成', 'Caching complete')
            : context.tr('缓存部分完成', 'Caching partially complete'),
        message: failedChapters == 0
            ? context.tr(
                '《${book.title}》的全部章节已缓存。',
                'All chapters of “${book.title}” are cached.',
              )
            : context.tr(
                '已处理 ${chapters.length} 个章节，其中 $failedChapters 个章节存在失败段落，可再次执行以重试。',
                'Processed ${chapters.length} chapters. $failedChapters chapters contain failed segments; run caching again to retry.',
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
          title: context.tr('缓存失败', 'Caching failed'),
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
            child: Text(context.tr('完成', 'Done')),
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
              language:
                  book.language ?? inferLanguageFromTitle(parsed.book.title),
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
              kind: book.kind,
              externalSource: book.externalSource,
              externalId: book.externalId,
              rightsStatus: book.rightsStatus,
              externalMetadataJson: book.externalMetadataJson,
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

  Future<void> _showEditBookSheet(drift_db.Book book) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author ?? '');
    final languageController = TextEditingController(
      text: book.language ?? inferLanguageFromTitle(book.title) ?? '',
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

/// 书籍卡片：圆角封面占位 + 标题 + 作者 + 章节数。
class _BookCard extends StatelessWidget {
  final drift_db.Book book;
  final _BookCacheProgress? cacheProgress;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onReparse;
  final VoidCallback onCacheBook;
  final VoidCallback onClearCache;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    this.cacheProgress,
    required this.onTap,
    required this.onEdit,
    required this.onReparse,
    required this.onCacheBook,
    required this.onClearCache,
    required this.onDelete,
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
          label: bookReadingProgressLabel(context, book),
        ),
        if (cacheProgress != null)
          BookListCardMeta(
            icon: Icons.downloading_outlined,
            label: '${(cacheProgress!.percent * 100).round()}%',
          ),
      ],
      trailing: _BookActionsButton(
        onEdit: onEdit,
        onReparse: onReparse,
        onCacheBook: onCacheBook,
        onClearCache: onClearCache,
        cacheProgress: cacheProgress,
        onDelete: onDelete,
      ),
      onTap: onTap,
    );
  }
}

class _BookActionsButton extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onReparse;
  final VoidCallback onCacheBook;
  final VoidCallback onClearCache;
  final VoidCallback onDelete;
  final _BookCacheProgress? cacheProgress;

  const _BookActionsButton({
    required this.onEdit,
    required this.onReparse,
    required this.onCacheBook,
    required this.onClearCache,
    required this.onDelete,
    this.cacheProgress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: PopupMenuButton<String>(
        tooltip: '书籍操作',
        color: context.appSurface,
        padding: EdgeInsets.zero,
        iconSize: 22,
        icon: Icon(Icons.more_horiz, color: context.appTextSecondary),
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'reparse') onReparse();
          if (value == 'cache_book') onCacheBook();
          if (value == 'cache') onClearCache();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('编辑'),
              ],
            ),
          ),
          const PopupMenuItem(
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
            value: 'cache_book',
            enabled: cacheProgress == null,
            child: Row(
              children: [
                const Icon(Icons.download_for_offline_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cacheProgress == null
                        ? context.tr('缓存整本书', 'Cache Entire Book')
                        : context.tr(
                            '缓存中 ${(cacheProgress!.percent * 100).round()}%',
                            'Caching ${(cacheProgress!.percent * 100).round()}%',
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'cache',
            child: Row(
              children: [
                Icon(Icons.cleaning_services_outlined, size: 18),
                SizedBox(width: 8),
                Text('清除音频'),
              ],
            ),
          ),
          const PopupMenuItem(
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
      ),
    );
  }
}
