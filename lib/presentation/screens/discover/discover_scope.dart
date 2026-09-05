import 'package:flutter/widgets.dart';

import '../../../core/app_localizations.dart';

/// 统一搜索页的检索范围。
enum DiscoverScope { audiobooks, onlineBooks, podcasts, library }

extension DiscoverScopeLabels on DiscoverScope {
  String label(BuildContext context) => switch (this) {
    DiscoverScope.audiobooks => context.tr('有声书', 'Audiobooks', 'オーディオブック'),
    DiscoverScope.onlineBooks => context.tr('公版书', 'Books', '書籍'),
    DiscoverScope.podcasts => context.tr('播客', 'Podcasts', 'ポッドキャスト'),
    DiscoverScope.library => context.tr('书架', 'Library', '本棚'),
  };

  String hintText(BuildContext context) => switch (this) {
    DiscoverScope.audiobooks => context.tr(
      '搜索 LibriVox 真人有声书',
      'Search LibriVox audiobooks',
      'LibriVoxのオーディオブックを検索',
    ),
    DiscoverScope.onlineBooks => context.tr(
      '搜索 Gutenberg 公版书',
      'Search Gutenberg books',
      'Gutenbergのパブリックドメイン本を検索',
    ),
    DiscoverScope.podcasts => context.tr(
      '搜索节目或创作者',
      'Search shows or creators',
      '番組やクリエイターを検索',
    ),
    DiscoverScope.library => context.tr(
      '搜索书籍、章节或正文',
      'Search books, chapters, or text',
      '本・章・本文を検索',
    ),
  };
}
