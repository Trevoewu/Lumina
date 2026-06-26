/// 章节领域模型。
class Chapter {
  /// 全局唯一 id（bookId + 章节序号 或 hash）。
  final String id;

  final String bookId;

  /// 章节序号（0-based）。
  final int index;

  final String title;

  /// 章节在书中的文本偏移（用于分页计算）。
  final int textOffset;

  const Chapter({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    required this.textOffset,
  });
}
