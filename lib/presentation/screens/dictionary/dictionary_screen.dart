import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/relative_time.dart';
import '../../../data/dictionary/dictionary_repository.dart';
import '../../../data/dictionary/vocabulary_com_parser.dart';
import '../../../domain/models/vocabulary_entry.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/app_search_field.dart';
import '../../widgets/design_system/editorial_type.dart';
import '../../widgets/dictionary_entry_content.dart';
import '../../widgets/word_list_card.dart';

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
  List<DictionaryLookupResult> _suggestions = const [];
  Set<String> _favoriteIds = const {};
  String _query = '';

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
    final favorites = values[0] as List<FavoriteVocabularyEntry>;
    setState(() {
      _favorites = favorites;
      _recent = values[1] as List<DictionaryLookupResult>;
      _favoriteIds = {
        for (final favorite in favorites) favorite.lookup.cacheId,
      };
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _loadSuggestions(value);
  }

  Future<void> _loadSuggestions(String value) async {
    final term = value.trim();
    if (term.isEmpty) {
      if (mounted) setState(() => _suggestions = const []);
      return;
    }
    final matches = await ref.read(dictionaryRepositoryProvider).suggest(term);
    // Drop results for a term the user has already typed past.
    if (!mounted || _controller.text.trim() != term) return;
    setState(() => _suggestions = matches);
  }

  Future<void> _toggleFavorite(DictionaryLookupResult result) async {
    await ref
        .read(dictionaryRepositoryProvider)
        .toggleFavorite(result.cacheId, context: result.context);
    await _reloadCollections();
  }

  Future<void> _openLookup([String? query]) async {
    final term = (query ?? _controller.text).trim();
    if (term.isEmpty) return;
    _controller.text = term;
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DictionaryWordScreen(initialQuery: term, showBackButton: true),
      ),
    );
    if (mounted) {
      _resetSearch();
      await _reloadCollections();
    }
  }

  Future<void> _openResult(DictionaryLookupResult result) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DictionaryWordScreen(initialResult: result, showBackButton: true),
      ),
    );
    if (mounted) {
      _resetSearch();
      await _reloadCollections();
    }
  }

  void _resetSearch() {
    _controller.clear();
    setState(() {
      _query = '';
      _suggestions = const [];
    });
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
    final design = context.appDesign;
    final listGutter = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final gutter = listGutter + 6;
    final searching = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const PageStorageKey('dictionary-home-list'),
          padding: EdgeInsets.only(
            top: 20,
            bottom: MediaQuery.paddingOf(context).bottom + 20,
          ),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('词典', 'Dictionary', '辞書'),
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.tr(
                      '查词、生词本，与你听过的段落相连',
                      'Look words up, keep them tied to what you heard',
                      '単語を調べ、聴いた内容と一緒に保存',
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appTextPrimary.withValues(alpha: 0.42),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
              child: AppSearchField(
                fieldKey: const ValueKey('dictionary-search-field'),
                controller: _controller,
                onChanged: _onQueryChanged,
                onSubmitted: _openLookup,
                onSearch: _openLookup,
                hintText: context.tr(
                  '输入一个英文单词',
                  'Enter an English word',
                  '英単語を入力',
                ),
              ),
            ),
            if (searching)
              ..._buildResults(gutter, listGutter)
            else
              ..._buildBrowse(gutter, listGutter),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults(double gutter, double listGutter) {
    final term = _query.trim();
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(gutter, 26, gutter, 8),
        child: Text(
          context.tr('匹配结果', 'MATCHES', '一致'),
          style: kickerTextStyle(context),
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: listGutter),
        child: Column(
          children: [
            for (final result in _suggestions)
              _SuggestionRow(
                key: ValueKey('dictionary-suggestion-${result.cacheId}'),
                result: result,
                onTap: () => _openResult(result),
              ),
            // Nothing cached yet for this prefix: offer the online lookup
            // rather than leaving the section empty.
            if (_suggestions.every((result) => result.entry.word != term))
              _SuggestionRow(
                key: const ValueKey('dictionary-suggestion-lookup'),
                lookupTerm: term,
                onTap: () => _openLookup(term),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildBrowse(double gutter, double listGutter) {
    if (_favorites.isEmpty && _recent.isEmpty) return [_buildEmpty()];

    final favorites = _favorites.take(_previewLimit).toList(growable: false);
    return [
      if (favorites.isNotEmpty) ...[
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 30, gutter, 0),
          child: _SectionHeaderRow(
            label: context.tr(
              '生词本 · ${_favorites.length}',
              'SAVED · ${_favorites.length}',
              'お気に入り · ${_favorites.length}',
            ),
            onSeeAll: () =>
                _openCollection(_DictionaryCollectionKind.favorites),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(listGutter, 12, listGutter, 0),
          child: Column(
            children: [
              for (final favorite in favorites)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FavoriteWordCard(
                    result: favorite.lookup,
                    onTap: () => _openResult(favorite.lookup),
                    onToggleFavorite: () => _toggleFavorite(favorite.lookup),
                  ),
                ),
            ],
          ),
        ),
      ],
      if (favorites.isNotEmpty && _recent.isNotEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(listGutter, 18, listGutter, 0),
          child: const _HairlineDivider(),
        ),
      if (_recent.isNotEmpty) ...[
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 0),
          child: _SectionHeaderRow(
            label: context.tr('最近查过', 'RECENT', '最近の検索'),
            onSeeAll: () => _openCollection(_DictionaryCollectionKind.history),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
          child: Column(
            children: [
              for (final result in _recent)
                _HistoryRow(
                  key: ValueKey('dictionary-history-${result.cacheId}'),
                  result: result,
                  favorite: _favoriteIds.contains(result.cacheId),
                  onTap: () => _openResult(result),
                  onToggleFavorite: () => _toggleFavorite(result),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildEmpty() {
    final design = context.appDesign;
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        children: [
          AppIcon(
            AppIcons.bookOpen01,
            size: 72,
            color: context.appTextPrimary.withValues(alpha: 0.10),
          ),
          SizedBox(height: design.spaceXl),
          Text(
            context.tr('查询你的第一个单词', 'Look up your first word', '最初の単語を調べる'),
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
              '検索結果はこの端末に保存されます',
            ),
            style: TextStyle(
              color: context.appTextPrimary.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
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
        builder: (_) =>
            DictionaryWordScreen(initialResult: result, showBackButton: true),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = widget.kind == _DictionaryCollectionKind.favorites;
    final itemCount = favorites ? _favorites.length : _history.length;
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return CollapsingPageScaffold(
      title: favorites
          ? context.tr('收藏单词', 'Favorites', 'お気に入り')
          : context.tr('查询历史', 'History', '履歴'),
      showBackButton: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : itemCount == 0
          ? _buildEmpty(favorites)
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  final result = favorites
                      ? _favorites[index].lookup
                      : _history[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: design.spaceMd),
                    child: WordListCard(
                      entry: result.entry,
                      favorite: favorites,
                      contextLabel: result.context?.bookTitle,
                      onTap: () => _openResult(result),
                    ),
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
            AppIcon(
              favorites ? AppIcons.bookmark02 : AppIcons.clockArrowDown,
              size: 56,
              color: context.appSurfaceHighlight,
            ),
            const SizedBox(height: 14),
            Text(
              favorites
                  ? context.tr(
                      '还没有收藏单词',
                      'No favorite words yet',
                      'お気に入りの単語はありません',
                    )
                  : context.tr(
                      '还没有查询记录',
                      'No lookup history yet',
                      '検索履歴はありません',
                    ),
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
  /// The heading scrolls out of view around here; past it the top bar takes
  /// over as the word's label.
  static const _stickyThreshold = 74.0;

  final _audioPlayer = AudioPlayer();
  final _scrollController = ScrollController();
  DictionaryLookupResult? _result;
  Object? _error;
  String _term = '';
  bool _loading = false;
  bool _favorite = false;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final result = widget.initialResult;
    if (result != null) {
      _result = result;
      _term = result.entry.word;
      _loadFavorite(result);
      return;
    }
    _term = widget.initialQuery!.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lookup(_term));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > _stickyThreshold;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  Future<void> _loadFavorite(DictionaryLookupResult result) async {
    final favorite = await ref
        .read(dictionaryRepositoryProvider)
        .isFavorite(result.cacheId);
    if (mounted) setState(() => _favorite = favorite);
  }

  Future<void> _lookup([String? query]) async {
    final term = (query ?? _term).trim();
    if (term.isEmpty || _loading) return;
    _term = term;
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
        SnackBar(
          content: Text(
            context.tr('发音播放失败', 'Pronunciation failed', '発音の再生に失敗しました'),
          ),
        ),
      );
    }
  }

  Future<void> _playContext() async {
    final lookupContext = _result?.context;
    final paragraphId = lookupContext?.paragraphId;
    final audioStartMs = lookupContext?.audioStartMs;
    if (paragraphId == null || audioStartMs == null) return;
    final handler = await ref.read(luminaAudioHandlerProvider.future);
    await handler.playFromParagraphOffset(
      paragraphId,
      Duration(milliseconds: audioStartMs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final design = context.appDesign;
    final gutter = design.pageInsetFor(MediaQuery.sizeOf(context).width) + 6;
    final ink = context.appTextPrimary;
    final word = _result?.entry.word ?? widget.initialQuery?.trim() ?? '';

    return Scaffold(
      key: const ValueKey('dictionary-word-screen'),
      backgroundColor: context.appBackground,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            _buildContent(gutter),
            // Top bar: transparent over the big word, then a translucent bar
            // with the word centered once that heading scrolls away.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _scrolled
                        ? context.appBackground.withValues(alpha: 0.92)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: _scrolled
                            ? ink.withValues(alpha: 0.06)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (widget.showBackButton)
                        const AppBackButton(
                          key: ValueKey('dictionary-word-back'),
                        )
                      else
                        const SizedBox(width: 44),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _scrolled ? 1 : 0,
                          child: Text(
                            word,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                      ),
                      if (_result != null)
                        GestureDetector(
                          key: const ValueKey('dictionary-word-favorite'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleFavorite,
                          child: Tooltip(
                            message: _favorite
                                ? context.tr(
                                    '取消收藏',
                                    'Remove favorite',
                                    'お気に入りから削除',
                                  )
                                : context.tr('收藏', 'Save word', '単語を保存'),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: AppIcon(
                                _favorite
                                    ? AppIcons.bookmark01
                                    : AppIcons.bookmark02,
                                size: 20,
                                color: _favorite
                                    ? ink
                                    : ink.withValues(alpha: 0.28),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(double gutter) {
    final result = _result;
    if (result != null) {
      return ListView(
        key: const PageStorageKey('dictionary-word-list'),
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(gutter, 56, gutter, 140),
        children: [
          DictionaryEntryContent(
            result: result,
            favorite: _favorite,
            onFavorite: _toggleFavorite,
            onPlayUs: () => _playPronunciation(british: false),
            onPlayUk: () => _playPronunciation(british: true),
            onPlayContext:
                result.context?.paragraphId != null &&
                    result.context?.audioStartMs != null
                ? _playContext
                : null,
            showFavoriteAction: false,
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
            AppIcon(
              notFound ? AppIcons.searchRemove : AppIcons.cloudOff,
              size: 64,
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              notFound
                  ? context.tr('没有找到这个单词', 'Word not found', '単語が見つかりません')
                  : context.tr(
                      '词典暂时不可用',
                      'Dictionary unavailable',
                      '辞書を利用できません',
                    ),
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
              child: Text(context.tr('重试', 'Retry', '再試行')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String label;
  final VoidCallback onSeeAll;

  const _SectionHeaderRow({required this.label, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: kickerTextStyle(context))),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSeeAll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('全部', 'All', 'すべて'),
                style: TextStyle(
                  fontSize: 13,
                  color: ink.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: 2),
              AppIcon(
                AppIcons.arrowRight01,
                size: 16,
                color: ink.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoriteWordCard extends StatelessWidget {
  final DictionaryLookupResult result;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _FavoriteWordCard({
    required this.result,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final entry = result.entry;
    final definition = entry.definitions.firstOrNull;
    final meaning = definition?.meaning ?? entry.shortExplanation ?? '';
    final phonetic = entry.usPhonetic ?? entry.ukPhonetic;
    final partOfSpeech = definition?.partOfSpeech.trim() ?? '';
    final cefr = _cefrLabel(entry);
    final source = result.context?.bookTitle;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 9,
                            children: [
                              Text(
                                entry.word,
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.21,
                                  color: ink,
                                ),
                              ),
                              if (phonetic != null &&
                                  phonetic.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    phonetic,
                                    style: technicalTextStyle(
                                      context,
                                      size: 13,
                                      alpha: 0.45,
                                      weight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (meaning.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              meaning,
                              style: TextStyle(
                                fontSize: 15.5,
                                height: 1.55,
                                color: ink.withValues(alpha: 0.62),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _BookmarkButton(favorite: true, onTap: onToggleFavorite),
                  ],
                ),
                if (partOfSpeech.isNotEmpty || cefr != null || source != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 13),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        if (partOfSpeech.isNotEmpty)
                          _MetaChip(label: partOfSpeech),
                        if (cefr != null) _MetaChip(label: cefr),
                        if (source != null && source.isNotEmpty)
                          _MetaChip(label: source, icon: AppIcons.bookOpen01),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final DictionaryLookupResult result;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _HistoryRow({
    super.key,
    required this.result,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final entry = result.entry;
    final gloss =
        entry.definitions.firstOrNull?.meaning ?? entry.shortExplanation ?? '';
    final phonetic = entry.usPhonetic ?? entry.ukPhonetic;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ink.withValues(alpha: 0.06))),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            entry.word,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                        if (phonetic != null && phonetic.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              phonetic,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: technicalTextStyle(
                                context,
                                size: 12,
                                alpha: 0.35,
                                weight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (gloss.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        gloss,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: ink.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                relativeTimeLabel(context, result.lastAccessedAt),
                style: technicalTextStyle(
                  context,
                  size: 12,
                  alpha: 0.35,
                  weight: FontWeight.w400,
                ),
              ),
              _BookmarkButton(favorite: favorite, onTap: onToggleFavorite),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final DictionaryLookupResult? result;
  final String? lookupTerm;
  final VoidCallback onTap;

  const _SuggestionRow({
    super.key,
    this.result,
    this.lookupTerm,
    required this.onTap,
  }) : assert(result != null || lookupTerm != null);

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;
    final entry = result?.entry;
    final word = entry?.word ?? lookupTerm!;
    final gloss = entry == null
        ? context.tr('在词典中查询', 'Look this word up', 'この単語を調べる')
        : entry.definitions.firstOrNull?.meaning ??
              entry.shortExplanation ??
              '';
    final phonetic = entry?.usPhonetic ?? entry?.ukPhonetic;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
        child: Row(
          children: [
            AppIcon(
              entry == null ? AppIcons.compass : AppIcons.search01,
              size: 17,
              color: ink.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  if (gloss.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      gloss,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: ink.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (phonetic != null && phonetic.trim().isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                phonetic,
                style: technicalTextStyle(
                  context,
                  size: 12,
                  alpha: 0.35,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  final bool favorite;
  final VoidCallback onTap;

  const _BookmarkButton({required this.favorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: AppIcon(
          favorite ? AppIcons.bookmark01 : AppIcons.bookmark02,
          size: 19,
          color: favorite ? ink : ink.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final AppIconData? icon;

  const _MetaChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final ink = context.appTextPrimary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 13, color: ink.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: technicalTextStyle(context, size: 12.5, alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) {
    final line = context.appTextPrimary.withValues(alpha: 0.09);

    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, line, line, Colors.transparent],
          stops: const [0, 0.12, 0.88, 1],
        ),
      ),
    );
  }
}

String? _cefrLabel(VocabularyEntry entry) {
  final code = entry.readingLevelCode?.trim().toUpperCase();
  return switch (code) {
    'A1' || 'A2' || 'B1' || 'B2' => 'CEFR $code',
    _ => null,
  };
}
