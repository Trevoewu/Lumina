import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/book_list_card.dart';
import '../../widgets/design_system/app_icon.dart';
import '../../widgets/podcast_artwork.dart';
import '../podcast/podcast_episode_screen.dart';
import '../podcast/podcast_formatters.dart';

/// The Library's Saved shelf: books and episodes saved with the heart in
/// the player, newest first.
class SavedShelfView extends ConsumerStatefulWidget {
  final int reloadToken;
  final ScrollController scrollController;
  final ValueChanged<Book> onOpenBook;

  /// Called after an item is removed, so the other shelves reload too.
  final VoidCallback onChanged;

  const SavedShelfView({
    super.key,
    required this.reloadToken,
    required this.scrollController,
    required this.onOpenBook,
    required this.onChanged,
  });

  @override
  ConsumerState<SavedShelfView> createState() => _SavedShelfViewState();
}

class _SavedShelfViewState extends ConsumerState<SavedShelfView> {
  late Future<List<_SavedEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _load();
  }

  @override
  void didUpdateWidget(covariant SavedShelfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _entries = _load();
  }

  /// Saved rows whose book or episode has since been deleted are skipped.
  Future<List<_SavedEntry>> _load() async {
    final database = ref.read(appDatabaseProvider);
    final saved = await database.getSavedItems();
    final books = {
      for (final book in await database.getAllBooks()) book.id: book,
    };
    final episodes = {
      for (final episode in await database.getPodcastEpisodesByIds([
        for (final item in saved)
          if (item.kind == 'episode') item.itemId,
      ]))
        episode.id: episode,
    };
    final shows = {
      for (final show in await database.getAllPodcastShows()) show.id: show,
    };
    return [
      for (final item in saved)
        if (item.kind == 'book' && books[item.itemId] != null)
          _SavedEntry.book(books[item.itemId]!)
        else if (item.kind == 'episode' && episodes[item.itemId] != null)
          _SavedEntry.episode(
            episodes[item.itemId]!,
            shows[episodes[item.itemId]!.showId],
          ),
    ];
  }

  Future<void> _unsave(_SavedEntry entry) async {
    await ref
        .read(appDatabaseProvider)
        .setSaved(entry.kind, entry.itemId, false);
    if (!mounted) return;
    setState(() {
      _entries = _load();
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);

    return FutureBuilder<List<_SavedEntry>>(
      future: _entries,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return _EmptySaved(scrollController: widget.scrollController);
        }
        return ListView.separated(
          key: const ValueKey('saved-shelf-list'),
          controller: widget.scrollController,
          primary: false,
          padding: EdgeInsets.fromLTRB(
            inset,
            design.spaceMd,
            inset,
            MediaQuery.paddingOf(context).bottom + design.spaceLg,
          ),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final remove = _UnsaveButton(onPressed: () => _unsave(entry));
            if (entry.book case final book?) {
              return Row(
                key: ValueKey('saved-book-${book.id}'),
                children: [
                  Expanded(
                    child: BookListCard(
                      title: book.title,
                      subtitle:
                          book.author ??
                          context.tr('未知作者', 'Unknown author', '著者不明'),
                      localCoverPath: book.coverPath,
                      onTap: () => widget.onOpenBook(book),
                    ),
                  ),
                  remove,
                ],
              );
            }
            final episode = entry.episode!;
            return _SavedEpisodeRow(
              key: ValueKey('saved-episode-${episode.id}'),
              episode: episode,
              show: entry.show,
              trailing: remove,
              onTap: () async {
                await openPodcastEpisodePlayer(context, episodeId: episode.id);
                if (!mounted) return;
                setState(() {
                  _entries = _load();
                });
              },
            );
          },
        );
      },
    );
  }
}

class _SavedEntry {
  final Book? book;
  final PodcastEpisode? episode;
  final PodcastShow? show;

  const _SavedEntry.book(Book this.book) : episode = null, show = null;

  const _SavedEntry.episode(PodcastEpisode this.episode, this.show)
    : book = null;

  String get kind => book != null ? 'book' : 'episode';

  String get itemId => book?.id ?? episode!.id;
}

class _SavedEpisodeRow extends StatelessWidget {
  final PodcastEpisode episode;
  final PodcastShow? show;
  final Widget trailing;
  final VoidCallback onTap;

  const _SavedEpisodeRow({
    super.key,
    required this.episode,
    required this.show,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      ?show?.title,
      if (episode.durationMs > 0)
        formatPodcastDuration(context, episode.durationMs),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            PodcastArtwork(
              imageUrl: episode.imageUrl ?? show?.imageUrl,
              size: 64,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// A filled heart: tapping it takes the item off the Saved shelf.
class _UnsaveButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _UnsaveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: context.tr('取消收藏', 'Remove from Saved', '保存を解除'),
      onPressed: onPressed,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.favorite, size: 19, color: accent),
          AppIcon(AppIcons.favourite, color: accent),
        ],
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  final ScrollController scrollController;

  const _EmptySaved({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        controller: scrollController,
        primary: false,
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 120),
        child: Column(
          children: [
            AppIcon(
              AppIcons.favourite,
              size: 96,
              color: context.appSurfaceHighlight,
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('还没有收藏', 'Nothing saved yet', 'まだ保存したものはありません'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                '在播放器里点爱心，书和单集就会出现在这里。',
                'Tap the heart in the player to keep a book or episode here.',
                'プレーヤーでハートをタップすると、本やエピソードがここに保存されます。',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
