import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_colors.dart';
import '../../core/app_design_tokens.dart';
import '../../core/app_localizations.dart';
import '../../core/providers.dart';
import '../../data/dictionary/dictionary_repository.dart';
import '../../data/dictionary/vocabulary_com_parser.dart';
import '../../domain/models/vocabulary_entry.dart';
import 'design_system/app_search_field.dart';
import 'dictionary_entry_content.dart';

Future<void> showDictionaryLookupSheet(
  BuildContext context, {
  required String initialQuery,
  DictionaryLookupContext? lookupContext,
  bool askAi = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DictionaryLookupSheet(
      initialQuery: initialQuery,
      lookupContext: lookupContext,
      askAi: askAi,
    ),
  );
}

class _DictionaryLookupSheet extends ConsumerStatefulWidget {
  final String initialQuery;
  final DictionaryLookupContext? lookupContext;
  final bool askAi;

  const _DictionaryLookupSheet({
    required this.initialQuery,
    this.lookupContext,
    required this.askAi,
  });

  @override
  ConsumerState<_DictionaryLookupSheet> createState() =>
      _DictionaryLookupSheetState();
}

class _DictionaryLookupSheetState
    extends ConsumerState<_DictionaryLookupSheet> {
  final _audioPlayer = AudioPlayer();
  late final TextEditingController _controller;
  DictionaryLookupResult? _result;
  Object? _error;
  bool _loading = false;
  bool _favorite = false;
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup([String? query]) async {
    final term = (query ?? _controller.text).trim();
    if (term.isEmpty || _loading) return;
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
        _searchExpanded = false;
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
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.62, 0.94],
      builder: (context, scrollController) {
        return CustomScrollView(
          key: const ValueKey('dictionary-lookup-sheet'),
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                inset,
                design.spaceSm,
                inset,
                design.spaceXl,
              ),
              sliver: SliverList.list(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _searchExpanded
                        ? Row(
                            key: const ValueKey('dictionary-sheet-search-mode'),
                            children: [
                              Expanded(
                                child: AppSearchField(
                                  fieldKey: const ValueKey(
                                    'dictionary-sheet-search-field',
                                  ),
                                  controller: _controller,
                                  hintText: context.tr(
                                    '输入英文单词或短语',
                                    'Enter an English word',
                                    '英単語を入力',
                                  ),
                                  onSubmitted: _lookup,
                                  onSearch: _lookup,
                                  loading: _loading,
                                  autofocus: true,
                                ),
                              ),
                              SizedBox(width: design.spaceSm),
                              IconButton(
                                tooltip: context.tr(
                                  '收起搜索',
                                  'Hide search',
                                  '検索を隠す',
                                ),
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  setState(() => _searchExpanded = false);
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('dictionary-sheet-actions'),
                            children: [
                              IconButton(
                                tooltip: context.tr(
                                  '搜索其他单词',
                                  'Search another word',
                                  '別の単語を検索',
                                ),
                                onPressed: () =>
                                    setState(() => _searchExpanded = true),
                                icon: const Icon(Icons.search),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).closeButtonTooltip,
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(height: design.spaceSm),
                  if (_result case final result?)
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
                    )
                  else if (_error != null)
                    _SheetError(error: _error!, retry: _lookup)
                  else
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SheetError extends StatelessWidget {
  final Object error;
  final VoidCallback retry;

  const _SheetError({required this.error, required this.retry});

  @override
  Widget build(BuildContext context) {
    final notFound = error is VocabularyNotFoundException;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appDesign.spaceXxl),
      child: Column(
        children: [
          Icon(
            notFound ? Icons.search_off : Icons.cloud_off_outlined,
            size: 48,
            color: context.appTextSecondary,
          ),
          SizedBox(height: context.appDesign.spaceMd),
          Text(
            notFound
                ? context.tr('没有找到这个单词', 'Word not found', '単語が見つかりません')
                : context.tr('词典暂时不可用', 'Dictionary unavailable', '辞書を利用できません'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: context.appDesign.spaceSm),
          TextButton(
            onPressed: retry,
            child: Text(context.tr('重试', 'Retry', '再試行')),
          ),
        ],
      ),
    );
  }
}
