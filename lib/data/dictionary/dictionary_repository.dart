import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/vocabulary_entry.dart';
import '../database/app_database.dart';
import 'openai_compatible_explanation_provider.dart';
import 'vocabulary_com_parser.dart';
import 'vocabulary_com_provider.dart';

class DictionaryLookupResult {
  final String cacheId;
  final VocabularyEntry entry;
  final bool fromCache;
  final DictionaryLookupContext? context;

  const DictionaryLookupResult({
    required this.cacheId,
    required this.entry,
    required this.fromCache,
    this.context,
  });
}

class FavoriteVocabularyEntry {
  final FavoriteWord favorite;
  final DictionaryLookupResult lookup;

  const FavoriteVocabularyEntry({required this.favorite, required this.lookup});
}

class DictionaryRepository {
  static const _language = 'en';
  static const _notFoundLifetime = Duration(days: 7);

  final AppDatabase _database;
  final VocabularyComProvider _provider;
  final OpenAiCompatibleExplanationProvider? explanationProvider;
  final Uuid _uuid;
  final Map<String, Future<DictionaryLookupResult>> _inFlight = {};

  DictionaryRepository(
    this._database, {
    VocabularyComProvider? provider,
    this.explanationProvider,
    Uuid? uuid,
  }) : _provider = provider ?? VocabularyComProvider(),
       _uuid = uuid ?? const Uuid();

  Future<DictionaryLookupResult> lookup(
    String term, {
    DictionaryLookupContext? context,
  }) {
    final normalizedTerm = normalizeDictionaryTerm(term);
    final requestKey =
        'dictionary:$normalizedTerm\n${context?.cacheMaterial ?? ''}';
    final existing = _inFlight[requestKey];
    if (existing != null) return existing;
    final future = _lookup(normalizedTerm, context);
    _inFlight[requestKey] = future;
    return future.whenComplete(() => _inFlight.remove(requestKey));
  }

  Future<DictionaryLookupResult> askAi(
    String term, {
    DictionaryLookupContext? context,
  }) {
    final selectedText = term.trim();
    final normalizedTerm = normalizeDictionaryTerm(selectedText);
    final requestKey = 'ai:$normalizedTerm\n${context?.cacheMaterial ?? ''}';
    final existing = _inFlight[requestKey];
    if (existing != null) return existing;
    final future = _askAi(normalizedTerm, selectedText, context);
    _inFlight[requestKey] = future;
    return future.whenComplete(() => _inFlight.remove(requestKey));
  }

  Future<DictionaryLookupResult> _askAi(
    String normalizedTerm,
    String selectedText,
    DictionaryLookupContext? context,
  ) async {
    if (normalizedTerm.isEmpty) {
      throw const VocabularyParseException('Select text to ask AI.');
    }
    final provider = explanationProvider;
    if (provider == null || !await provider.isConfigured) {
      throw const OpenAiCompatibleConfigurationException(
        'Select an LLM Provider and Model in Settings first.',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final providerId = await _fallbackProviderId(provider, context);
    final cached = await _database.getDictionaryEntry(
      providerId,
      _language,
      normalizedTerm,
    );
    if (cached?.status == 'success') {
      await _database.touchDictionaryEntry(cached!.id, now);
      return DictionaryLookupResult(
        cacheId: cached.id,
        entry: _fromRow(cached),
        fromCache: true,
        context: context,
      );
    }
    return _lookupWithExplanation(
      term: selectedText,
      context: context,
      provider: provider,
      providerId: providerId,
      now: now,
    );
  }

  Future<DictionaryLookupResult> _lookup(
    String normalizedTerm,
    DictionaryLookupContext? context,
  ) async {
    if (normalizedTerm.isEmpty) {
      throw const VocabularyParseException('Enter a word to look up.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = await _database.getDictionaryEntry(
      VocabularyEntry.providerId,
      _language,
      normalizedTerm,
    );
    if (cached != null) {
      if (cached.status == 'success') {
        await _database.touchDictionaryEntry(cached.id, now);
        return DictionaryLookupResult(
          cacheId: cached.id,
          entry: _fromRow(cached),
          fromCache: true,
          context: context,
        );
      }
    }

    final contextProvider = explanationProvider;
    final fallbackConfigured =
        contextProvider != null && await contextProvider.isConfigured;
    final fallbackProviderId = fallbackConfigured
        ? await _fallbackProviderId(contextProvider, context)
        : null;
    if (fallbackProviderId != null) {
      final fallback = await _database.getDictionaryEntry(
        fallbackProviderId,
        _language,
        normalizedTerm,
      );
      if (fallback?.status == 'success') {
        await _database.touchDictionaryEntry(fallback!.id, now);
        return DictionaryLookupResult(
          cacheId: fallback.id,
          entry: _fromRow(fallback),
          fromCache: true,
          context: context,
        );
      }
    }
    if (cached?.status == 'not_found' && (cached?.expiresAt ?? 0) > now) {
      if (fallbackProviderId != null && contextProvider != null) {
        return _lookupWithExplanation(
          term: normalizedTerm,
          context: context,
          provider: contextProvider,
          providerId: fallbackProviderId,
          now: now,
        );
      }
      throw VocabularyNotFoundException(normalizedTerm);
    }

    try {
      final entry = await _provider.lookup(normalizedTerm);
      final row = _rowFromEntry(
        id: cached?.id ?? _uuid.v4(),
        provider: VocabularyEntry.providerId,
        entry: entry,
        now: now,
        accessCount: (cached?.accessCount ?? 0) + 1,
      );
      await _database.upsertDictionaryEntry(row);
      return DictionaryLookupResult(
        cacheId: row.id,
        entry: entry,
        fromCache: false,
        context: context,
      );
    } on VocabularyParseException {
      if (contextProvider == null || fallbackProviderId == null) {
        rethrow;
      }
      return _lookupWithExplanation(
        term: normalizedTerm,
        context: context,
        provider: contextProvider,
        providerId: fallbackProviderId,
        now: now,
      );
    } on VocabularyNotFoundException {
      await _database.upsertDictionaryEntry(
        DictionaryEntry(
          id: cached?.id ?? _uuid.v4(),
          provider: VocabularyEntry.providerId,
          language: _language,
          normalizedTerm: normalizedTerm,
          displayWord: normalizedTerm,
          status: 'not_found',
          sourceUrl: 'https://www.vocabulary.com/dictionary/$normalizedTerm',
          fetchedAt: now,
          expiresAt: now + _notFoundLifetime.inMilliseconds,
          lastAccessedAt: now,
          accessCount: (cached?.accessCount ?? 0) + 1,
        ),
      );
      if (contextProvider != null && fallbackProviderId != null) {
        return _lookupWithExplanation(
          term: normalizedTerm,
          context: context,
          provider: contextProvider,
          providerId: fallbackProviderId,
          now: now,
        );
      }
      rethrow;
    }
  }

  Future<List<DictionaryLookupResult>> recent({int? limit}) async {
    final rows = await _database.getRecentDictionaryEntries(limit: limit);
    return [
      for (final row in rows)
        DictionaryLookupResult(
          cacheId: row.id,
          entry: _fromRow(row),
          fromCache: true,
        ),
    ];
  }

  Future<List<FavoriteVocabularyEntry>> favorites() async {
    final rows = await _database.getFavoriteWordEntries();
    return [
      for (final row in rows)
        FavoriteVocabularyEntry(
          favorite: row.favorite,
          lookup: DictionaryLookupResult(
            cacheId: row.entry.id,
            entry: _fromRow(row.entry),
            fromCache: true,
            context: row.favorite.contextText == null
                ? null
                : DictionaryLookupContext(
                    bookTitle: row.favorite.sourceBookTitle ?? '',
                    chapterTitle: row.favorite.sourceChapterTitle ?? '',
                    sentence: row.favorite.contextText!,
                    bookId: row.favorite.sourceBookId,
                    chapterId: row.favorite.sourceChapterId,
                    paragraphId: row.favorite.sourceParagraphId,
                    lineId: row.favorite.sourceLineId,
                    selectionStart: row.favorite.selectionStart,
                    selectionEnd: row.favorite.selectionEnd,
                    audioStartMs: row.favorite.audioStartMs,
                    audioEndMs: row.favorite.audioEndMs,
                  ),
          ),
        ),
    ];
  }

  Future<bool> isFavorite(String cacheId) async {
    return await _database.getFavoriteForEntry(cacheId) != null;
  }

  Future<bool> toggleFavorite(
    String cacheId, {
    DictionaryLookupContext? context,
  }) async {
    final existing = await _database.getFavoriteForEntry(cacheId);
    if (existing != null) {
      await _database.deleteFavoriteForEntry(cacheId);
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.upsertFavoriteWord(
      FavoriteWord(
        id: _uuid.v4(),
        dictionaryEntryId: cacheId,
        contextText: context?.sentence,
        selectionStart: context?.selectionStart,
        selectionEnd: context?.selectionEnd,
        sourceBookId: context?.bookId,
        sourceBookTitle: context?.bookTitle,
        sourceChapterId: context?.chapterId,
        sourceChapterTitle: context?.chapterTitle,
        sourceParagraphId: context?.paragraphId,
        sourceLineId: context?.lineId,
        audioStartMs: context?.audioStartMs,
        audioEndMs: context?.audioEndMs,
        favoritedAt: now,
        updatedAt: now,
      ),
    );
    return true;
  }

  VocabularyEntry _fromRow(DictionaryEntry row) {
    return VocabularyEntry(
      provider: row.provider.startsWith('openai_compatible:')
          ? 'openai_compatible'
          : row.provider,
      providerLabel: row.provider.startsWith('openai_compatible:')
          ? 'AI context explanation'
          : 'Vocabulary.com',
      word: row.displayWord,
      normalizedTerm: row.normalizedTerm,
      usPhonetic: row.usPhonetic,
      ukPhonetic: row.ukPhonetic,
      definitions: VocabularyEntry.decodeDefinitions(row.definitionsJson),
      otherForms: VocabularyEntry.decodeOtherForms(row.otherFormsJson),
      shortExplanation: row.shortExplanation,
      longExplanation: row.longExplanation,
      sourceUrl: row.sourceUrl,
    );
  }

  DictionaryEntry _rowFromEntry({
    required String id,
    required String provider,
    required VocabularyEntry entry,
    required int now,
    required int accessCount,
  }) {
    return DictionaryEntry(
      id: id,
      provider: provider,
      language: _language,
      normalizedTerm: entry.normalizedTerm,
      displayWord: entry.word,
      status: 'success',
      usPhonetic: entry.usPhonetic,
      ukPhonetic: entry.ukPhonetic,
      definitionsJson: entry.definitionsJson,
      otherFormsJson: entry.otherFormsJson,
      shortExplanation: entry.shortExplanation,
      longExplanation: entry.longExplanation,
      sourceUrl: entry.sourceUrl,
      fetchedAt: now,
      expiresAt: null,
      lastAccessedAt: now,
      accessCount: accessCount,
    );
  }

  Future<String> _fallbackProviderId(
    OpenAiCompatibleExplanationProvider provider,
    DictionaryLookupContext? context,
  ) async {
    final material = [
      await provider.baseUrl,
      await provider.model,
      context?.cacheMaterial ?? 'general-dictionary-explanation',
    ].join('\n');
    final digest = sha256.convert(utf8.encode(material)).toString();
    return 'openai_compatible:${digest.substring(0, 24)}';
  }

  Future<DictionaryLookupResult> _lookupWithExplanation({
    required String term,
    required DictionaryLookupContext? context,
    required OpenAiCompatibleExplanationProvider provider,
    required String providerId,
    required int now,
  }) async {
    final entry = await provider.explain(term: term, context: context);
    final row = _rowFromEntry(
      id: _uuid.v4(),
      provider: providerId,
      entry: entry,
      now: now,
      accessCount: 1,
    );
    await _database.upsertDictionaryEntry(row);
    return DictionaryLookupResult(
      cacheId: row.id,
      entry: entry,
      fromCache: false,
      context: context,
    );
  }
}
