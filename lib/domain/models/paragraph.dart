/// 段落领域模型。段落是 TTS 合成与阅读/播放同步的最小单位。
class Paragraph {
  /// 全局唯一 id（chapterId + 段落序号）。
  final String id;

  final String chapterId;

  final String bookId;

  /// 段落序号（章节内 0-based）。
  final int index;

  /// 段落文本。
  final String text;

  const Paragraph({
    required this.id,
    required this.chapterId,
    required this.bookId,
    required this.index,
    required this.text,
  });
}
