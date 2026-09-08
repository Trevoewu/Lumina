import 'package:flutter/material.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../widgets/book_list_card.dart';
import '../../widgets/design_system/app_section_header.dart';
import '../../widgets/disk_cached_network_image.dart';

/// Presentation data only. Source-specific navigation stays with DiscoverScreen.
class DiscoverEditorialBook {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? description;
  final String metadata;
  final VoidCallback onTap;

  const DiscoverEditorialBook({
    required this.id,
    required this.title,
    required this.author,
    required this.metadata,
    required this.onTap,
    this.coverUrl,
    this.description,
  });
}

/// Magazine rhythm: one cover story, a shelf, an author feature, then a list.
/// No fabricated rankings or editorial endorsements are attached to API order.
class DiscoverEditorialFeed extends StatelessWidget {
  final List<DiscoverEditorialBook> books;
  final bool audiobooks;
  final VoidCallback? onNextPage;
  final ValueChanged<String> onExploreAuthor;

  const DiscoverEditorialFeed({
    super.key,
    required this.books,
    required this.audiobooks,
    required this.onExploreAuthor,
    this.onNextPage,
  }) : assert(books.length > 0);

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final feature = books.first;
    final shelf = books.skip(1).take(6).toList();
    final rest = books.skip(7).toList();
    final author = feature.author.trim();
    final canExploreAuthor =
        !audiobooks && author.isNotEmpty && author != 'Unknown';

    return CustomScrollView(
      key: PageStorageKey('discover-editorial-$audiobooks'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('故事，从这里开始', 'A story starts here', '物語は、ここから'),
                  style: type.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: design.spaceLg),
                _CoverStory(book: feature, audiobooks: audiobooks),
                if (shelf.isNotEmpty)
                  AppSectionHeader(
                    title: context.tr(
                      '下一本，遇见新世界',
                      'Find your next chapter',
                      '次の一冊、新しい世界',
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (shelf.isNotEmpty)
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Cover dimensions are media geometry; text height follows scaling.
                final width = ((constraints.maxWidth - inset * 2) / 2.5).clamp(
                  112.0,
                  160.0,
                );
                final scaler = MediaQuery.textScalerOf(context);
                final textHeight =
                    scaler.scale(16) * 1.3 * 2 + scaler.scale(12) * 1.35 * 3;
                return SizedBox(
                  height: width * 1.35 + textHeight + design.spaceXl,
                  child: ListView.separated(
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    itemCount: shelf.length,
                    separatorBuilder: (_, _) => SizedBox(width: design.spaceLg),
                    itemBuilder: (context, index) => SizedBox(
                      width: width,
                      child: _ShelfBook(
                        key: ValueKey(shelf[index].id),
                        book: shelf[index],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (canExploreAuthor)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(inset, design.spaceXl, inset, 0),
            sliver: SliverToBoxAdapter(
              child: Material(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(design.radiusLarge),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('discover-author-feature'),
                  onTap: () => onExploreAuthor(author),
                  child: Padding(
                    padding: EdgeInsets.all(design.spaceXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('作家专题', 'AUTHOR SPOTLIGHT', '作家特集'),
                          style: type.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: design.spaceMd),
                        Text(author, style: type.headlineMedium),
                        SizedBox(height: design.spaceSm),
                        Text(
                          context.tr(
                            '一本书之外，还有更多故事。',
                            'One voice. More worlds to explore.',
                            '一冊の先に、まだ知らない物語。',
                          ),
                          style: type.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: design.spaceLg),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr(
                                  '探索作品',
                                  'Explore the collection',
                                  '作品を見る',
                                ),
                                style: type.labelLarge,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (rest.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            sliver: SliverToBoxAdapter(
              child: AppSectionHeader(
                title: context.tr('继续发现', 'Keep exploring', 'もっと見つける'),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            sliver: SliverList.builder(
              itemCount: rest.length,
              itemBuilder: (context, index) {
                final book = rest[index];
                return BookListCard(
                  title: book.title,
                  subtitle: book.author,
                  remoteCoverUrl: book.coverUrl,
                  metadata: [
                    BookListCardMeta(
                      icon: Icons.menu_book_outlined,
                      label: book.metadata,
                    ),
                  ],
                  onTap: book.onTap,
                );
              },
            ),
          ),
        ],
        if (onNextPage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(design.spaceXl),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: onNextPage,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(context.tr('浏览更多', 'Browse more', 'もっと見る')),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(
            height:
                design.toolbarHeight * 2 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

class _CoverStory extends StatelessWidget {
  final DiscoverEditorialBook book;
  final bool audiobooks;
  const _CoverStory({required this.book, required this.audiobooks});

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(design.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('discover-cover-story'),
        onTap: book.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: colors.surfaceContainerHighest,
              padding: EdgeInsets.all(design.spaceXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audiobooks
                        ? context.tr(
                            '听见一本好书',
                            'IN FOCUS · AUDIOBOOKS',
                            '声で出会う一冊',
                          )
                        : context.tr('翻开一部经典', 'IN FOCUS · BOOKS', '名作をひらく'),
                    style: type.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: design.spaceLg),
                  Center(
                    child: SizedBox(
                      width: 120,
                      height: 162,
                      child: _EditorialCover(book: book),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(design.spaceXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: type.headlineMedium,
                  ),
                  SizedBox(height: design.spaceSm),
                  Text(
                    book.author,
                    style: type.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (book.description?.trim().isNotEmpty == true) ...[
                    SizedBox(height: design.spaceMd),
                    Text(
                      book.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  SizedBox(height: design.spaceLg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.metadata,
                          style: type.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      SizedBox(width: design.spaceSm),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfBook extends StatelessWidget {
  final DiscoverEditorialBook book;
  const _ShelfBook({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final type = Theme.of(context).textTheme;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: book.onTap,
        borderRadius: BorderRadius.circular(design.radiusSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1 / 1.35,
              child: _EditorialCover(book: book),
            ),
            SizedBox(height: design.spaceSm),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.titleMedium,
            ),
            SizedBox(height: design.spaceXs),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodySmall?.copyWith(color: secondary),
            ),
            SizedBox(height: design.spaceXs),
            Text(
              book.metadata,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.bodySmall?.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorialCover extends StatelessWidget {
  final DiscoverEditorialBook book;
  const _EditorialCover({required this.book});

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final colors = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.all(design.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.menu_book_outlined, color: colors.onSurfaceVariant),
            SizedBox(height: design.spaceMd),
            Expanded(
              child: Text(
                book.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(design.radiusSmall),
        child: book.coverUrl?.isNotEmpty == true
            ? DiskCachedNetworkImage(
                url: book.coverUrl!,
                placeholder: fallback,
                fit: BoxFit.contain,
              )
            : fallback,
      ),
    );
  }
}

/// Stable geometry while the first catalogue page is loading (no shimmer).
class DiscoverEditorialLoading extends StatelessWidget {
  const DiscoverEditorialLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: context.tr('正在加载书籍', 'Loading books', '書籍を読み込み中'),
      child: ListView(
        padding: EdgeInsets.all(
          design.pageInsetFor(MediaQuery.sizeOf(context).width),
        ),
        children: [
          Container(
            height: 360,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(design.radiusLarge),
            ),
          ),
          SizedBox(height: design.spaceXl),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(design.spaceXs),
                    child: Container(
                      height: 156,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(design.radiusSmall),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
