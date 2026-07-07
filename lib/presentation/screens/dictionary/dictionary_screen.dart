import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../data/dictionary/dictionary_repository.dart';
import '../../../data/dictionary/vocabulary_com_parser.dart';
import '../../../domain/models/vocabulary_entry.dart';
import '../../widgets/collapsing_page_scaffold.dart';

class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({super.key});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  static const _previewLimit = 3;

  final _controller = TextEditingController();
  List<FavoriteVocabularyEntry> _favorites = const [];
  List<DictionaryLookupResult> _recent = const [];

  @override
  void initState() {
    super.initState();
    _reloadCollections();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reloadCollections() async {
    final repository = ref.read(dictionaryRepositoryProvider);
    final values = await Future.wait([
      repository.favorites(),
      repository.recent(limit: _previewLimit),
    ]);
    if (!mounted) return;
    setState(() {
      _favorites = values[0] as List<FavoriteVocabularyEntry>;
      _recent = values[1] as List<DictionaryLookupResult>;
    });
  }

  Future<void> _openLookup([String? query]) async {
    final term = (query ?? _controller.text).trim();
    if (term.isEmpty) return;
    _controller.text = term;
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DictionaryWordScreen(initialQuery: term),
      ),
    );
    if (mounted) {
      _controller.clear();
      await _reloadCollections();
    }
  }

  Future<void> _openResult(DictionaryLookupResult result) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DictionaryWordScreen(initialResult: result),
      ),
    );
    if (mounted) {
      _controller.clear();
      await _reloadCollections();
    }
  }

  Future<void> _openCollection(_DictionaryCollectionKind kind) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DictionaryCollectionScreen(kind: kind),
      ),
    );
    if (mounted) await _reloadCollections();
  }

  @override
  Widget build(BuildContext context) {
    return CollapsingPageScaffold(
      title: context.tr('查词', 'Dictionary'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              key: const ValueKey('dictionary-search-field'),
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _openLookup,
              style: TextStyle(color: context.appTextPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.appSurface,
                hintText: context.tr('输入英文单词或短语', 'Enter an English word'),
                prefixIcon: Icon(Icons.search, color: context.appTextSecondary),
                suffixIcon: IconButton(
                  tooltip: context.tr('查询', 'Look up'),
                  onPressed: _openLookup,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildCollections()),
        ],
      ),
    );
  }

  Widget _buildCollections() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        if (_favorites.isNotEmpty) ...[
          _section(
            context.tr('收藏单词', 'Favorites'),
            onViewAll: () =>
                _openCollection(_DictionaryCollectionKind.favorites),
          ),
          for (final favorite in _favorites.take(_previewLimit))
            _WordTile(
              result: favorite.lookup,
              favorite: true,
              onTap: () => _openResult(favorite.lookup),
            ),
        ],
        if (_recent.isNotEmpty) ...[
          _section(
            context.tr('查询历史', 'History'),
            onViewAll: () => _openCollection(_DictionaryCollectionKind.history),
          ),
          for (final result in _recent)
            _WordTile(result: result, onTap: () => _openResult(result)),
        ],
        if (_favorites.isEmpty && _recent.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Column(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 72,
                  color: context.appSurfaceHighlight,
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('查询你的第一个单词', 'Look up your first word'),
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    '查询结果会永久保存在本地',
                    'Results are saved on this device',
                  ),
                  style: TextStyle(color: context.appTextSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _section(String label, {required VoidCallback onViewAll}) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 0, 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.appTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: Text(context.tr('查看全部', 'View All')),
        ),
      ],
    ),
  );
}

enum _DictionaryCollectionKind { favorites, history }

class _DictionaryCollectionScreen extends ConsumerStatefulWidget {
  final _DictionaryCollectionKind kind;

  const _DictionaryCollectionScreen({required this.kind});

  @override
  ConsumerState<_DictionaryCollectionScreen> createState() =>
      _DictionaryCollectionScreenState();
}

class _DictionaryCollectionScreenState
    extends ConsumerState<_DictionaryCollectionScreen> {
  List<FavoriteVocabularyEntry> _favorites = const [];
  List<DictionaryLookupResult> _history = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repository = ref.read(dictionaryRepositoryProvider);
    if (widget.kind == _DictionaryCollectionKind.favorites) {
      final favorites = await repository.favorites();
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _loading = false;
      });
    } else {
      final history = await repository.recent();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    }
  }

  Future<void> _openResult(DictionaryLookupResult result) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DictionaryWordScreen(initialResult: result),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = widget.kind == _DictionaryCollectionKind.favorites;
    final itemCount = favorites ? _favorites.length : _history.length;
    return CollapsingPageScaffold(
      title: favorites
          ? context.tr('收藏单词', 'Favorites')
          : context.tr('查询历史', 'History'),
      showBackButton: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : itemCount == 0
          ? _buildEmpty(favorites)
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  final result = favorites
                      ? _favorites[index].lookup
                      : _history[index];
                  return _WordTile(
                    result: result,
                    favorite: favorites,
                    onTap: () => _openResult(result),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmpty(bool favorites) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              favorites ? Icons.bookmark_border : Icons.history,
              size: 56,
              color: context.appSurfaceHighlight,
            ),
            const SizedBox(height: 14),
            Text(
              favorites
                  ? context.tr('还没有收藏单词', 'No favorite words yet')
                  : context.tr('还没有查询记录', 'No lookup history yet'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DictionaryWordScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final DictionaryLookupResult? initialResult;
  final DictionaryLookupContext? lookupContext;
  final bool showBackButton;
  final bool askAi;

  const DictionaryWordScreen({
    super.key,
    this.initialQuery,
    this.initialResult,
    this.lookupContext,
    this.showBackButton = false,
    this.askAi = false,
  }) : assert(initialQuery != null || initialResult != null);

  @override
  ConsumerState<DictionaryWordScreen> createState() =>
      _DictionaryWordScreenState();
}

class _DictionaryWordScreenState extends ConsumerState<DictionaryWordScreen> {
  final _controller = TextEditingController();
  final _audioPlayer = AudioPlayer();
  DictionaryLookupResult? _result;
  Object? _error;
  bool _loading = false;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    final result = widget.initialResult;
    if (result != null) {
      _result = result;
      _controller.text = result.entry.word;
      _loadFavorite(result);
      return;
    }
    final initialQuery = widget.initialQuery!.trim();
    _controller.text = initialQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) => _lookup(initialQuery));
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadFavorite(DictionaryLookupResult result) async {
    final favorite = await ref
        .read(dictionaryRepositoryProvider)
        .isFavorite(result.cacheId);
    if (mounted) setState(() => _favorite = favorite);
  }

  Future<void> _lookup([String? query]) async {
    final term = (query ?? _controller.text).trim();
    if (term.isEmpty || _loading) return;
    _controller.text = term;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(dictionaryRepositoryProvider);
      final result = widget.askAi
          ? await repository.askAi(term, context: widget.lookupContext)
          : await repository.lookup(term, context: widget.lookupContext);
      final favorite = await repository.isFavorite(result.cacheId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _favorite = favorite;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _error = error;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final result = _result;
    if (result == null) return;
    final favorite = await ref
        .read(dictionaryRepositoryProvider)
        .toggleFavorite(result.cacheId, context: result.context);
    if (mounted) setState(() => _favorite = favorite);
  }

  Future<void> _playPronunciation({required bool british}) async {
    final word = _result?.entry.word;
    if (word == null) return;
    final uri = Uri.https('dict.youdao.com', '/dictvoice', {
      'audio': word,
      'type': british ? '1' : '2',
    });
    try {
      await _audioPlayer.setUrl(uri.toString());
      await _audioPlayer.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('发音播放失败', 'Pronunciation failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsingPageScaffold(
      title: context.tr('查词', 'Dictionary'),
      showBackButton: widget.showBackButton,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              key: const ValueKey('dictionary-detail-search-field'),
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _lookup,
              style: TextStyle(color: context.appTextPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.appSurface,
                prefixIcon: Icon(Icons.search, color: context.appTextSecondary),
                suffixIcon: IconButton(
                  tooltip: context.tr('查询', 'Look up'),
                  onPressed: _loading ? null : _lookup,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final result = _result;
    if (result != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _DictionaryCard(
            result: result,
            favorite: _favorite,
            onFavorite: _toggleFavorite,
            onPlayUs: () => _playPronunciation(british: false),
            onPlayUk: () => _playPronunciation(british: true),
          ),
        ],
      );
    }
    if (_error != null) return _buildError(_error!);
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildError(Object error) {
    final notFound = error is VocabularyNotFoundException;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              notFound ? Icons.search_off : Icons.cloud_off_outlined,
              size: 64,
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              notFound
                  ? context.tr('没有找到这个单词', 'Word not found')
                  : context.tr('词典暂时不可用', 'Dictionary unavailable'),
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _lookup,
              child: Text(context.tr('重试', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DictionaryCard extends StatelessWidget {
  final DictionaryLookupResult result;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onPlayUs;
  final VoidCallback onPlayUk;

  const _DictionaryCard({
    required this.result,
    required this.favorite,
    required this.onFavorite,
    required this.onPlayUs,
    required this.onPlayUk,
  });

  @override
  Widget build(BuildContext context) {
    final entry = result.entry;
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entry.providerLabel}${result.fromCache ? ' · ${context.tr('本地', 'Cached')}' : ''}',
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                ),
                IconButton(
                  tooltip: favorite
                      ? context.tr('取消收藏', 'Remove favorite')
                      : context.tr('收藏', 'Favorite'),
                  onPressed: onFavorite,
                  icon: Icon(
                    favorite ? Icons.bookmark : Icons.bookmark_border,
                    color: favorite ? accent : context.appTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              entry.word,
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 38,
                height: 1.05,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            _PronunciationRow(
              label: 'US',
              phonetic: entry.usPhonetic,
              onPlay: onPlayUs,
            ),
            _PronunciationRow(
              label: 'UK',
              phonetic: entry.ukPhonetic,
              onPlay: onPlayUk,
            ),
            const SizedBox(height: 14),
            for (final definition in entry.definitions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (definition.partOfSpeech.isNotEmpty)
                        TextSpan(
                          text: '${definition.partOfSpeech}  ',
                          style: TextStyle(color: context.appTextSecondary),
                        ),
                      TextSpan(text: definition.meaning),
                    ],
                  ),
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 17,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (entry.otherForms.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Other forms:  ',
                      style: TextStyle(color: context.appTextSecondary),
                    ),
                    TextSpan(
                      text: entry.otherForms.join(', '),
                      style: TextStyle(color: accent),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 17, height: 1.4),
              ),
            ],
            if (result.context case final lookupContext?) ...[
              const SizedBox(height: 22),
              _BookContext(context: lookupContext),
            ],
            if (entry.shortExplanation != null) ...[
              const SizedBox(height: 22),
              _Explanation(
                title: 'short explanation',
                text: entry.shortExplanation!,
              ),
            ],
            if (entry.longExplanation != null) ...[
              const SizedBox(height: 20),
              _Explanation(
                title: 'long explanation',
                text: entry.longExplanation!,
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(entry.sourceUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: Text(entry.providerLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookContext extends StatelessWidget {
  final DictionaryLookupContext context;

  const _BookContext({required this.context});

  @override
  Widget build(BuildContext buildContext) {
    final accent = Theme.of(buildContext).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: buildContext.appSurfaceHighlight,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.chapterTitle.isEmpty
                ? context.bookTitle
                : '${context.bookTitle} · ${context.chapterTitle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: buildContext.appTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.sentence,
            style: TextStyle(
              color: buildContext.appTextPrimary,
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PronunciationRow extends StatelessWidget {
  final String label;
  final String? phonetic;
  final VoidCallback onPlay;

  const _PronunciationRow({
    required this.label,
    required this.phonetic,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 34,
        child: Text(
          label,
          style: TextStyle(color: context.appTextPrimary, fontSize: 17),
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onPlay,
        icon: const Icon(Icons.volume_up_outlined),
      ),
      if (phonetic != null)
        Expanded(
          child: Text(
            phonetic!,
            style: TextStyle(color: context.appTextSecondary, fontSize: 15),
          ),
        ),
    ],
  );
}

class _Explanation extends StatelessWidget {
  final String title;
  final String text;

  const _Explanation({required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: context.appTextSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        text,
        style: TextStyle(
          color: context.appTextPrimary,
          fontSize: 17,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _WordTile extends StatelessWidget {
  final DictionaryLookupResult result;
  final bool favorite;
  final VoidCallback onTap;

  const _WordTile({
    required this.result,
    required this.onTap,
    this.favorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final entry = result.entry;
    final subtitle =
        entry.definitions.firstOrNull?.meaning ?? entry.shortExplanation ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          onTap: onTap,
          title: Text(
            entry.word,
            style: TextStyle(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.appTextSecondary),
          ),
          trailing: Icon(
            favorite ? Icons.bookmark : Icons.chevron_right,
            color: favorite
                ? Theme.of(context).colorScheme.primary
                : context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}
