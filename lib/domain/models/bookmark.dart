/// 书签领域模型。
class Bookmark {
  final String id;
  final String bookId;
  final String chapterId;

  /// 书签锚定的段落索引。
  final int paragraphIndex;

  /// 段落文本（用于书签列表预览）。
  final String excerpt;

  /// 用户备注。
  final String? note;

  /// 创建时间（毫秒）。
  final int createdAt;

  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.paragraphIndex,
    required this.excerpt,
    this.note,
    required this.createdAt,
  });
}
