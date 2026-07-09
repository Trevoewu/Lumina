import 'dart:convert';
import 'dart:io';

import 'package:epub_pro/epub_pro.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../domain/models/book.dart';
import '../domain/models/chapter.dart';
import '../domain/models/paragraph.dart';

/// 解析结果。
class ParsedBook {
  final Book book;
  final List<Chapter> chapters;
  final List<Paragraph> paragraphs;

  const ParsedBook({
    required this.book,
    required this.chapters,
    required this.paragraphs,
  });
}

/// 书籍解析器：EPUB + TXT。
class BookParser {
  @visibleForTesting
  static List<String> htmlToPlainParagraphsForTest(String html) {
    return _extractHtmlBlocks(_stripNonContentHtml(html));
  }

  @visibleForTesting
  static List<String> epubHtmlChapterTitlesForTest(String html) {
    return _splitEpubHtmlIntoChapterSections(
      html,
    ).map((section) => section.title).toList(growable: false);
  }

  @visibleForTesting
  static List<List<String>> epubHtmlChapterParagraphsForTest(String html) {
    return _splitEpubHtmlIntoChapterSections(
      html,
    ).map((section) => section.paragraphs).toList(growable: false);
  }

  @visibleForTesting
  static bool shouldSkipEpubChapterForTest(
    String title,
    List<String> paragraphs, {
    String? contentFileName,
  }) {
    return _shouldSkipEpubChapter(
      title: title,
      contentFileName: contentFileName,
      paragraphTexts: paragraphs,
    );
  }

  /// 解析文件。返回书籍结构（章节 + 段落）。
  ///
  /// [sourcePath] 源文件路径；[appDir] app 沙盒目录（用于拷贝源文件）。
  static Future<ParsedBook> parse({
    required String sourcePath,
    required String appDir,
  }) async {
    final ext = p.extension(sourcePath).toLowerCase();
    final bookId = 'book_${DateTime.now().millisecondsSinceEpoch}';
    final destDir = p.join(appDir, 'books', bookId);
    await Directory(destDir).create(recursive: true);
    final destPath = p.join(destDir, 'source$ext');
    await File(sourcePath).copy(destPath);

    switch (ext) {
      case '.epub':
        return _parseEpub(sourcePath: destPath, bookId: bookId, appDir: appDir);
      case '.txt':
        return _parseTxt(sourcePath: destPath, bookId: bookId);
      default:
        throw UnsupportedError('不支持的文件格式: $ext');
    }
  }

  static Future<ParsedBook> reparseExisting({
    required String sourcePath,
    required String bookId,
    required String appDir,
  }) async {
    final ext = p.extension(sourcePath).toLowerCase();
    switch (ext) {
      case '.epub':
        return _parseEpub(
          sourcePath: sourcePath,
          bookId: bookId,
          appDir: appDir,
        );
      case '.txt':
        return _parseTxt(sourcePath: sourcePath, bookId: bookId);
      default:
        throw UnsupportedError('不支持的文件格式: $ext');
    }
  }

  // ── EPUB ──

  static Future<ParsedBook> _parseEpub({
    required String sourcePath,
    required String bookId,
    required String appDir,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);

    final title = epub.title ?? p.basenameWithoutExtension(sourcePath);
    final author = epub.author;

    final coverPath = await _writeCoverImage(
      coverImage: epub.coverImage,
      bookId: bookId,
      appDir: appDir,
    );

    final chapters = <Chapter>[];
    final paragraphs = <Paragraph>[];
    final flat = <EpubChapter>[];
    void collect(EpubChapter ch) {
      flat.add(ch);
      for (final sub in ch.subChapters) {
        collect(sub);
      }
    }

    for (final ch in epub.chapters) {
      collect(ch);
    }

    int chIdx = 0;
    int spineIdx = 0;
    int textOffset = 0;
    for (final item in flat) {
      final html = item.htmlContent ?? '';
      final splitSections = _splitEpubHtmlIntoChapterSections(html);
      if (splitSections.isNotEmpty) {
        for (final section in splitSections) {
          final chId = '${bookId}_ch_$chIdx';
          final paras = _paragraphsFromPlainTexts(
            section.paragraphs,
            chId,
            bookId,
          );
          if (paras.isEmpty) continue;
          if (_shouldSkipEpubChapter(
            title: section.title,
            contentFileName: item.contentFileName,
            paragraphTexts: section.paragraphs,
          )) {
            continue;
          }
          chapters.add(
            Chapter(
              id: chId,
              bookId: bookId,
              index: chIdx,
              title: section.title,
              textOffset: textOffset,
            ),
          );
          paragraphs.addAll(paras);
          textOffset += paras.length;
          chIdx++;
        }
        spineIdx++;
        continue;
      }

      final chId = '${bookId}_ch_$chIdx';
      final chTitle =
          item.title ?? item.contentFileName ?? '第 ${spineIdx + 1} 章';
      final paras = _htmlToParagraphs(html, chId, bookId);
      if (paras.isEmpty) {
        spineIdx++;
        continue;
      }
      if (_shouldSkipEpubChapter(
        title: chTitle,
        contentFileName: item.contentFileName,
        paragraphTexts: paras.map((p) => p.text).toList(growable: false),
      )) {
        spineIdx++;
        continue;
      }
      chapters.add(
        Chapter(
          id: chId,
          bookId: bookId,
          index: chIdx,
          title: chTitle,
          textOffset: textOffset,
        ),
      );
      paragraphs.addAll(paras);
      textOffset += paras.length;
      chIdx++;
      spineIdx++;
    }

    final book = Book(
      id: bookId,
      title: title,
      author: author,
      format: BookFormat.epub,
      sourcePath: sourcePath,
      coverPath: coverPath,
      chapterCount: chapters.length,
      paragraphCount: paragraphs.length,
      importedAt: DateTime.now().millisecondsSinceEpoch,
      lastReadAt: DateTime.now().millisecondsSinceEpoch,
    );

    return ParsedBook(book: book, chapters: chapters, paragraphs: paragraphs);
  }

  /// 从已有 EPUB 源文件补提取封面，用于旧书数据迁移。
  static Future<String?> extractCover({
    required String sourcePath,
    required String bookId,
    required String appDir,
  }) async {
    if (p.extension(sourcePath).toLowerCase() != '.epub') return null;
    if (!await File(sourcePath).exists()) return null;

    final bytes = await File(sourcePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    return _writeCoverImage(
      coverImage: epub.coverImage,
      bookId: bookId,
      appDir: appDir,
    );
  }

  static Future<String?> _writeCoverImage({
    required img.Image? coverImage,
    required String bookId,
    required String appDir,
  }) async {
    if (coverImage == null) return null;

    final coverDir = Directory(p.join(appDir, 'books', bookId));
    await coverDir.create(recursive: true);
    final coverPath = p.join(coverDir.path, 'cover.jpg');
    final bytes = img.encodeJpg(coverImage, quality: 88);
    await File(coverPath).writeAsBytes(bytes, flush: true);
    return coverPath;
  }

  static List<Paragraph> _htmlToParagraphs(
    String html,
    String chapterId,
    String bookId,
  ) {
    final body = _stripNonContentHtml(html);
    final lines = _extractHtmlBlocks(body);

    return _paragraphsFromPlainTexts(lines, chapterId, bookId);
  }

  static List<Paragraph> _paragraphsFromPlainTexts(
    List<String> lines,
    String chapterId,
    String bookId,
  ) {
    return lines.asMap().entries.map((e) {
      return Paragraph(
        id: '${chapterId}_p_${e.key}',
        chapterId: chapterId,
        bookId: bookId,
        index: e.key,
        text: e.value,
      );
    }).toList();
  }

  static List<_EpubChapterSection> _splitEpubHtmlIntoChapterSections(
    String html,
  ) {
    final blocks = _extractHtmlBlockEntries(_stripNonContentHtml(html));
    if (blocks.isEmpty) return const [];

    final sections = <_EpubChapterSection>[];
    String? currentTitle;
    var currentParagraphs = <String>[];

    void flushCurrent() {
      final title = currentTitle;
      if (title == null || currentParagraphs.isEmpty) return;
      sections.add(
        _EpubChapterSection(
          title: title,
          paragraphs: _mergeContinuationParagraphs(currentParagraphs),
        ),
      );
      currentParagraphs = <String>[];
    }

    for (final block in blocks) {
      if (_isEpubChapterHeadingBlock(block)) {
        flushCurrent();
        currentTitle = block.text;
        continue;
      }

      if (currentTitle == null) continue;
      currentParagraphs.add(block.text);
    }

    flushCurrent();
    return sections;
  }

  static List<_HtmlBlockEntry> _extractHtmlBlockEntries(String html) {
    final blocks = <_HtmlBlockEntry>[];
    final document = html_parser.parse(html);
    final root = document.body ?? document.documentElement;
    if (root == null) return blocks;

    for (final element in root.querySelectorAll(
      'p, blockquote, li, h1, h2, h3, h4, h5, h6',
    )) {
      final tag = (element.localName ?? '').toLowerCase();
      if (tag == 'blockquote' && _hasDescendantBlock(element)) {
        continue;
      }
      final lines = _elementTextLines(element);
      final text =
          _chapterHeadingTextFromLines(lines) ??
          _decodeHtmlText(lines.join(' '));
      if (!_isContentParagraph(text)) continue;
      blocks.add(
        _HtmlBlockEntry(
          text: text,
          isHeading: tag.startsWith('h'),
          tagName: tag,
          className: element.className,
          id: element.id,
        ),
      );
    }
    return blocks;
  }

  static bool _hasDescendantBlock(html_dom.Element element) {
    return element
        .querySelectorAll('p, blockquote, li, h1, h2, h3, h4, h5, h6')
        .any((candidate) => candidate != element);
  }

  static bool _isEpubChapterHeadingBlock(_HtmlBlockEntry block) {
    if (!_looksLikeEpubChapterHeading(block.text)) return false;
    if (block.isHeading) return true;

    final marker = '${block.tagName} ${block.className} ${block.id}'
        .toLowerCase();
    if (RegExp(r'\b(chapter|chap|heading|title|section)\b').hasMatch(marker)) {
      return true;
    }

    return RegExp(
      r'^(chapter|chapitre|cap[ií]tulo|capitulo)\s+([ivxlcdm]+|\d+)\b\.?$',
      caseSensitive: false,
    ).hasMatch(block.text.trim());
  }

  static bool _looksLikeEpubChapterHeading(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length > 120) return false;

    return RegExp(
      r'^(chapter|chapitre|cap[ií]tulo|capitulo)\s+([ivxlcdm]+|\d+)\b\.?\s*.*$',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  static List<String> _extractHtmlBlocks(String html) {
    final leafBlocks = _extractBlocksForTags(
      html,
      r'p|blockquote|li|h[1-6]',
      skipNestedBlockContent: false,
    );
    if (leafBlocks.isNotEmpty) {
      return _mergeContinuationParagraphs(leafBlocks);
    }

    final containerBlocks = _extractBlocksForTags(
      html,
      r'div|section|article',
      skipNestedBlockContent: true,
    );
    if (containerBlocks.isNotEmpty) {
      return _mergeContinuationParagraphs(containerBlocks);
    }

    final fallback = html
        .replaceAll(
          RegExp(
            r'</?(p|div|section|article|blockquote|li|h[1-6])\b[^>]*>',
            caseSensitive: false,
          ),
          '\n',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');

    return _mergeContinuationParagraphs(
      fallback
          .split(RegExp(r'\n+'))
          .map(_decodeHtmlText)
          .where(_isContentParagraph)
          .toList(),
    );
  }

  static List<String> _extractBlocksForTags(
    String html,
    String tags, {
    required bool skipNestedBlockContent,
  }) {
    final blocks = <String>[];
    final document = html_parser.parse(html);
    final root = document.body ?? document.documentElement;
    if (root == null) return blocks;

    final selector = tags
        .split('|')
        .map((tag) => tag.startsWith('h[') ? 'h1, h2, h3, h4, h5, h6' : tag)
        .join(', ');
    for (final element in root.querySelectorAll(selector)) {
      if (skipNestedBlockContent && _hasNestedContentBlock(element)) {
        continue;
      }
      final lines = _elementTextLines(element);
      final text =
          _chapterHeadingTextFromLines(lines) ??
          _decodeHtmlText(lines.join(' '));
      if (_isContentParagraph(text)) blocks.add(text);
    }
    return blocks;
  }

  static bool _hasNestedContentBlock(html_dom.Element element) {
    return element
        .querySelectorAll(
          'p, div, section, article, blockquote, li, h1, h2, h3, h4, h5, h6',
        )
        .any((candidate) => candidate != element);
  }

  static List<String> _elementTextLines(html_dom.Element element) {
    final buffer = StringBuffer();

    void walk(html_dom.Node node) {
      if (node is html_dom.Text) {
        buffer.write(node.text.replaceAll(RegExp(r'\s+'), ' '));
        return;
      }
      if (node is! html_dom.Element) return;

      final tag = (node.localName ?? '').toLowerCase();
      if (tag == 'br') {
        buffer.write('\n');
        return;
      }

      final isNestedBlock = node != element && _contentBlockTags.contains(tag);
      if (isNestedBlock) buffer.write('\n');
      for (final child in node.nodes) {
        walk(child);
      }
      if (isNestedBlock) buffer.write('\n');
    }

    walk(element);
    return buffer
        .toString()
        .split(RegExp(r'\n+'))
        .map(_decodeHtmlText)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static String? _chapterHeadingTextFromLines(List<String> lines) {
    for (final line in lines.reversed) {
      if (_looksLikeEpubChapterHeading(line)) return line;
    }
    return null;
  }

  static const _contentBlockTags = {
    'p',
    'div',
    'section',
    'article',
    'blockquote',
    'li',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };

  static List<String> _mergeContinuationParagraphs(List<String> paragraphs) {
    final merged = <String>[];
    for (final text in paragraphs) {
      if (merged.isNotEmpty && _looksLikeContinuation(merged.last, text)) {
        merged[merged.length - 1] = '${merged.last} $text'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      } else {
        merged.add(text);
      }
    }
    return merged;
  }

  static bool _looksLikeContinuation(String previous, String next) {
    final prev = previous.trim();
    final current = next.trim();
    if (prev.isEmpty || current.isEmpty) return false;
    if (current.length > 160) return false;
    if (RegExp(r'^[A-Z0-9“"(\[]').hasMatch(current)) return false;
    if (RegExp(r"^[a-z][a-z’']*\b").hasMatch(current)) {
      return !RegExp(r'[.!?。！？…”")\]]$').hasMatch(prev) ||
          RegExp(r'[-—–][A-Za-z]*$').hasMatch(prev);
    }
    return false;
  }

  static String _decodeHtmlText(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final value = int.tryParse(m.group(1)!, radix: 16);
          return value == null ? m.group(0)! : String.fromCharCode(value);
        })
        .replaceAllMapped(RegExp(r'&#([0-9]+);'), (m) {
          final value = int.tryParse(m.group(1)!);
          return value == null ? m.group(0)! : String.fromCharCode(value);
        })
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isContentParagraph(String text) {
    return text.isNotEmpty && text.length > 1 && !_looksLikeCssOrMetadata(text);
  }

  static bool _shouldSkipEpubChapter({
    required String title,
    required String? contentFileName,
    required List<String> paragraphTexts,
  }) {
    final normalizedTitle = _normalizeEpubSectionName(title);
    final normalizedFile = _normalizeEpubSectionName(contentFileName ?? '');

    bool matchesAny(Iterable<String> names) {
      return names.any(
        (name) =>
            normalizedTitle == name ||
            normalizedFile == name ||
            normalizedTitle.startsWith('$name ') ||
            normalizedFile.startsWith('$name '),
      );
    }

    const alwaysSkip = {
      'contents',
      'table of contents',
      'toc',
      'copyright',
      'copyright page',
      'title page',
      'cover',
      'cover page',
      'half title',
      'halftitle',
      'also by',
      'books by',
      'about the author',
      'about author',
      'praise',
      'newsletter',
    };
    if (matchesAny(alwaysSkip)) return true;

    const shortFrontMatter = {
      'dedication',
      'dedications',
      'epigraph',
      'acknowledgments',
      'acknowledgements',
      'notes',
      'bibliography',
      'index',
    };
    if (matchesAny(shortFrontMatter)) {
      final charCount = paragraphTexts.fold<int>(
        0,
        (sum, text) => sum + text.length,
      );
      return paragraphTexts.length <= 4 && charCount <= 600;
    }

    return false;
  }

  static String _normalizeEpubSectionName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\.[a-z0-9]+$'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _stripNonContentHtml(String html) {
    return html
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ')
        .replaceAll(
          RegExp(
            r'<style\b[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<script\b[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<head\b[^>]*>.*?</head>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'<svg\b[^>]*>.*?</svg>', caseSensitive: false, dotAll: true),
          ' ',
        );
  }

  static bool _looksLikeCssOrMetadata(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return true;

    if (RegExp(
      r'^@(page|font-face|media|charset|namespace|import)\b',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return true;
    }

    final hasCssBlock =
        normalized.contains('{') &&
        normalized.contains('}') &&
        RegExp(
          r'[-a-zA-Z]+\s*:\s*[^;{}]+[;}]',
          caseSensitive: false,
        ).hasMatch(normalized);
    if (hasCssBlock) return true;

    final cssDeclarationCount = RegExp(
      r'(^|;)\s*[-a-zA-Z]+\s*:\s*[^;{}]+',
      caseSensitive: false,
    ).allMatches(normalized).length;
    if (cssDeclarationCount >= 2) return true;

    return false;
  }

  // ── TXT ──

  /// TXT 章节正则（可扩展）。
  static final _chapterPatterns = [
    RegExp(r'^第[一二三四五六七八九十百千零0-9]+[章节回卷集部篇话]\s*.*$'),
    RegExp(r'^Chapter\s+\d+', caseSensitive: false),
    RegExp(r'^卷[一二三四五六七八九十百千零0-9]+'),
    RegExp(r'^\d+[\.、]\s+\S+'), // "1. 标题" 或 "1、标题"
  ];

  static Future<ParsedBook> _parseTxt({
    required String sourcePath,
    required String bookId,
  }) async {
    final raw = await File(sourcePath).readAsBytes();
    final text = _decodeWithEncoding(raw);

    final lines = text.split(RegExp(r'\r?\n'));
    final chapters = <Chapter>[];
    final paragraphs = <Paragraph>[];
    int chIdx = 0;
    int textOffset = 0;
    int currentParaIdx = 0;
    String currentChId = '${bookId}_ch_0';
    final title = lines.firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '未命名',
    );

    // 确保至少有一章
    chapters.add(
      Chapter(
        id: currentChId,
        bookId: bookId,
        index: 0,
        title: title.trim(),
        textOffset: 0,
      ),
    );

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (_isChapterHeading(trimmed)) {
        // 新章节
        chIdx++;
        currentChId = '${bookId}_ch_$chIdx';
        currentParaIdx = 0;
        chapters.add(
          Chapter(
            id: currentChId,
            bookId: bookId,
            index: chIdx,
            title: trimmed,
            textOffset: textOffset,
          ),
        );
        continue;
      }

      paragraphs.add(
        Paragraph(
          id: '${currentChId}_p_$currentParaIdx',
          chapterId: currentChId,
          bookId: bookId,
          index: currentParaIdx,
          text: trimmed,
        ),
      );
      currentParaIdx++;
      textOffset++;
    }

    final book = Book(
      id: bookId,
      title: title.trim().isNotEmpty ? title.trim() : '未命名',
      format: BookFormat.txt,
      sourcePath: sourcePath,
      chapterCount: chapters.length,
      paragraphCount: paragraphs.length,
      importedAt: DateTime.now().millisecondsSinceEpoch,
      lastReadAt: DateTime.now().millisecondsSinceEpoch,
    );

    return ParsedBook(book: book, chapters: chapters, paragraphs: paragraphs);
  }

  static bool _isChapterHeading(String line) {
    if (line.length > 50) return false; // 章节标题不会太长
    for (final p in _chapterPatterns) {
      if (p.hasMatch(line)) return true;
    }
    return false;
  }

  /// 编码探测：尝试 UTF-8 → GB18030 → GBK → Latin-1。
  static String _decodeWithEncoding(Uint8List bytes) {
    final codecs = [('utf-8', utf8), ('gb18030', const _GbCodec())];
    for (final (_, codec) in codecs) {
      try {
        return codec.decode(bytes);
      } catch (_) {
        continue;
      }
    }
    // fallback
    return utf8.decode(bytes, allowMalformed: true);
  }
}

class _EpubChapterSection {
  final String title;
  final List<String> paragraphs;

  const _EpubChapterSection({required this.title, required this.paragraphs});
}

class _HtmlBlockEntry {
  final String text;
  final bool isHeading;
  final String tagName;
  final String className;
  final String id;

  const _HtmlBlockEntry({
    required this.text,
    required this.isHeading,
    required this.tagName,
    required this.className,
    required this.id,
  });
}

/// GB18030/GBK 编码（简化版，依赖 dart:convert 的 systemEncoding 或外部包）。
/// MVP 阶段：若 UTF-8 解码成功就用 UTF-8（绝大多数 TXT 都是 UTF-8）。
/// 完整 GB18030 支持需要引入 charset_converter 或自行实现。
class _GbCodec extends Encoding {
  const _GbCodec();

  @override
  Converter<List<int>, String> get decoder => const _GbDecoder();

  @override
  Converter<String, List<int>> get encoder =>
      throw UnsupportedError('GB encoder not needed');

  @override
  String get name => 'gb18030';
}

class _GbDecoder extends Converter<List<int>, String> {
  const _GbDecoder();

  @override
  String convert(List<int> input) {
    // 简化：直接尝试 systemEncoding
    return const SystemEncoding().decode(input);
  }
}
