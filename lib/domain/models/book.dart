/// 书籍文件格式。
enum BookFormat { epub, txt }

/// 书籍领域模型。
class Book {
  final String id;
  final String title;
  final String? author;
  final BookFormat format;

  /// 源文件在 app 沙盒内的相对路径。
  final String sourcePath;

  /// 封面图片路径（若有）。
  final String? coverPath;

  /// 总章节数。
  final int chapterCount;

  /// 总段落数。
  final int paragraphCount;

  /// 当前阅读到的章节 id（进度记忆）。
  final String? currentChapterId;

  /// 当前阅读到的段落索引。
  final int currentParagraphIndex;

  /// 当前音频播放偏移（毫秒）。
  final int playbackOffsetMs;

  /// 该书使用的音色 id。
  final String? voiceId;

  /// 导入时间（毫秒）。
  final int importedAt;

  /// 最后阅读时间（毫秒）。
  final int lastReadAt;

  const Book({
    required this.id,
    required this.title,
    this.author,
    required this.format,
    required this.sourcePath,
    this.coverPath,
    required this.chapterCount,
    required this.paragraphCount,
    this.currentChapterId,
    this.currentParagraphIndex = 0,
    this.playbackOffsetMs = 0,
    this.voiceId,
    required this.importedAt,
    required this.lastReadAt,
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    BookFormat? format,
    String? sourcePath,
    String? coverPath,
    int? chapterCount,
    int? paragraphCount,
    String? currentChapterId,
    int? currentParagraphIndex,
    int? playbackOffsetMs,
    String? voiceId,
    int? importedAt,
    int? lastReadAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format ?? this.format,
      sourcePath: sourcePath ?? this.sourcePath,
      coverPath: coverPath ?? this.coverPath,
      chapterCount: chapterCount ?? this.chapterCount,
      paragraphCount: paragraphCount ?? this.paragraphCount,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      currentParagraphIndex:
          currentParagraphIndex ?? this.currentParagraphIndex,
      playbackOffsetMs: playbackOffsetMs ?? this.playbackOffsetMs,
      voiceId: voiceId ?? this.voiceId,
      importedAt: importedAt ?? this.importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
