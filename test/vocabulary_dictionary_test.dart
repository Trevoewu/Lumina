import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/dictionary/dictionary_repository.dart';
import 'package:lumina/data/dictionary/openai_compatible_explanation_provider.dart';
import 'package:lumina/data/dictionary/vocabulary_com_parser.dart';
import 'package:lumina/data/dictionary/vocabulary_com_provider.dart';
import 'package:lumina/domain/models/vocabulary_entry.dart';
import 'package:lumina/services/reading_level_estimator.dart';
import 'package:lumina/tts/api_key_store.dart';

const _fixture = '''
<div class="definitionsContainer">
  <div class="word-area">
    <h1 id="hdr-word-area">jingoistic</h1>
    <div class="ipa-section">
      <div class="ipa-with-audio">
        <span class="span-replace-h3">/ˌdʒɪŋgoʊˈɪstɪk/</span>
      </div>
    </div>
    <p class="word-forms">Other forms: <b>jingoistically</b></p>
    <p class="short">A short explanation.</p>
    <p class="long">A much longer explanation.</p>
  </div>
  <div class="word-definitions">
    <ol>
      <li class="sense">
        <div class="definition">
          <div class="pos-icon">adjective</div>
          fanatically patriotic
        </div>
      </li>
    </ol>
  </div>
</div>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses the Vocabulary.com fields used by the dictionary card', () {
    final entry = const VocabularyComParser().parse(
      _fixture,
      requestedTerm: 'Jingoistic',
    );

    expect(entry.word, 'jingoistic');
    expect(entry.normalizedTerm, 'jingoistic');
    expect(entry.usPhonetic, '/ˌdʒɪŋgoʊˈɪstɪk/');
    expect(entry.definitions.single.partOfSpeech, 'adjective');
    expect(entry.definitions.single.meaning, 'fanatically patriotic');
    expect(entry.otherForms, ['jingoistically']);
    expect(entry.shortExplanation, 'A short explanation.');
    expect(entry.longExplanation, 'A much longer explanation.');
  });

  test('successful lookups are permanently served from the database', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final provider = _FakeProvider();
    final repository = DictionaryRepository(database, provider: provider);
    addTearDown(database.close);

    final first = await repository.lookup('Jingoistic');
    final second = await repository.lookup(' jingoistic ');

    expect(provider.calls, 1);
    expect(first.fromCache, isFalse);
    expect(second.fromCache, isTrue);
    expect(second.cacheId, first.cacheId);
    expect(second.entry.definitions.single.meaning, 'fanatically patriotic');
  });

  test(
    'localized dictionary lookups use AI and keep language-specific caches',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vocabularyProvider = _FakeProvider();
      final explanationProvider = _FakeExplanationProvider();
      final chineseRepository = DictionaryRepository(
        database,
        provider: vocabularyProvider,
        explanationProvider: explanationProvider,
        outputLanguageCode: 'zh',
      );
      final japaneseRepository = DictionaryRepository(
        database,
        provider: vocabularyProvider,
        explanationProvider: explanationProvider,
        outputLanguageCode: 'ja',
      );
      addTearDown(database.close);

      final chinese = await chineseRepository.lookup('jingoistic');
      final chineseCached = await chineseRepository.lookup('jingoistic');
      final japanese = await japaneseRepository.lookup('jingoistic');

      expect(vocabularyProvider.calls, 0);
      expect(explanationProvider.outputLanguages, ['zh', 'ja']);
      expect(chinese.fromCache, isFalse);
      expect(chineseCached.fromCache, isTrue);
      expect(japanese.fromCache, isFalse);
      expect(chinese.cacheId, isNot(japanese.cacheId));
      expect(chinese.entry.providerLabel, 'AI 上下文解释');
      expect(japanese.entry.providerLabel, 'AIによる文脈説明');
      expect(await chineseRepository.recent(), hasLength(1));
      expect(await japaneseRepository.recent(), hasLength(1));
    },
  );

  test('successful lookups store CEFR-J word level metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DictionaryRepository(
      database,
      provider: _LevelProvider(),
    );
    addTearDown(database.close);

    final result = await repository.lookup('abandon');
    final cached = await database.getDictionaryEntry(
      VocabularyEntry.providerId,
      'en',
      'abandon',
    );

    expect(result.entry.readingLevelSystem, cefrJReadingLevelSystem);
    expect(result.entry.readingLevelCode, 'B1');
    expect(result.entry.readingLevelSource, cefrJVocabularyProfileSource);
    expect(cached?.readingLevelCode, 'B1');
  });

  test('favorites do not remove the cached dictionary entry', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DictionaryRepository(
      database,
      provider: _FakeProvider(),
    );
    addTearDown(database.close);

    const context = DictionaryLookupContext(
      bookTitle: 'Born a Crime',
      chapterTitle: 'Chapter 1',
      sentence: 'A jingoistic speech.',
      bookId: 'book-1',
      chapterId: 'chapter-1',
      paragraphId: 'paragraph-1',
      lineId: 'line-1',
      selectionStart: 2,
      selectionEnd: 12,
      audioStartMs: 12000,
      audioEndMs: 14000,
    );
    final lookup = await repository.lookup('jingoistic', context: context);
    expect(
      await repository.toggleFavorite(lookup.cacheId, context: context),
      isTrue,
    );
    final favorites = await repository.favorites();
    expect(favorites, hasLength(1));
    expect(favorites.single.lookup.context?.bookId, 'book-1');
    expect(favorites.single.lookup.context?.audioStartMs, 12000);

    expect(await repository.toggleFavorite(lookup.cacheId), isFalse);
    expect(await repository.favorites(), isEmpty);
    expect((await repository.lookup('jingoistic')).fromCache, isTrue);
  });

  test('parser failure falls back to a cached context explanation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final vocabularyProvider = _FailingParserProvider();
    final explanationProvider = _FakeExplanationProvider();
    final repository = DictionaryRepository(
      database,
      provider: vocabularyProvider,
      explanationProvider: explanationProvider,
    );
    addTearDown(database.close);
    const context = DictionaryLookupContext(
      bookTitle: 'Born a Crime',
      chapterTitle: 'The Mulberry Tree',
      sentence: 'We sat beneath the old mulberry tree.',
    );

    final first = await repository.lookup('mulberry', context: context);
    final second = await repository.lookup('mulberry', context: context);

    expect(first.entry.provider, 'openai_compatible');
    expect(first.context?.sentence, context.sentence);
    expect(first.fromCache, isFalse);
    expect(second.fromCache, isTrue);
    expect(vocabularyProvider.calls, 1);
    expect(explanationProvider.calls, 1);
    expect(explanationProvider.lastContext?.bookTitle, 'Born a Crime');
    expect(explanationProvider.lastContext?.chapterTitle, 'The Mulberry Tree');
  });

  test(
    'not found falls back to the selected model without book context',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vocabularyProvider = _NotFoundProvider();
      final explanationProvider = _FakeExplanationProvider();
      final repository = DictionaryRepository(
        database,
        provider: vocabularyProvider,
        explanationProvider: explanationProvider,
      );
      addTearDown(database.close);

      final first = await repository.lookup('mind-bender');
      final second = await repository.lookup('mind-bender');

      expect(first.entry.provider, 'openai_compatible');
      expect(first.context, isNull);
      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(vocabularyProvider.calls, 1);
      expect(explanationProvider.calls, 1);
      expect(explanationProvider.lastContext, isNull);
    },
  );

  test('a cached not-found entry uses a model configured later', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final initialRepository = DictionaryRepository(
      database,
      provider: _NotFoundProvider(),
    );
    await expectLater(
      initialRepository.lookup('mind-bender'),
      throwsA(isA<VocabularyNotFoundException>()),
    );

    final explanationProvider = _FakeExplanationProvider();
    final configuredRepository = DictionaryRepository(
      database,
      provider: _NotFoundProvider(),
      explanationProvider: explanationProvider,
    );
    final result = await configuredRepository.lookup('mind-bender');

    expect(result.entry.provider, 'openai_compatible');
    expect(explanationProvider.calls, 1);
  });

  test(
    'Ask AI bypasses Vocabulary.com and caches the contextual result',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final vocabularyProvider = _FakeProvider();
      final explanationProvider = _FakeExplanationProvider();
      final repository = DictionaryRepository(
        database,
        provider: vocabularyProvider,
        explanationProvider: explanationProvider,
      );
      addTearDown(database.close);
      const context = DictionaryLookupContext(
        bookTitle: 'Born a Crime',
        chapterTitle: 'Chapter 1',
        sentence: 'The whole experience was a real Mind-Bender.',
      );

      final first = await repository.askAi('Mind-Bender', context: context);
      final second = await repository.askAi('Mind-Bender', context: context);

      expect(vocabularyProvider.calls, 0);
      expect(explanationProvider.calls, 1);
      expect(explanationProvider.lastTerm, 'Mind-Bender');
      expect(explanationProvider.lastContext?.sentence, context.sentence);
      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
    },
  );

  test(
    'LLM providers keep separate keys and aggregate remote models',
    () async {
      final settings = <String, String>{};
      final keyStore = _MemoryApiKeyStore();
      final requestedHosts = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedHosts.add(options.uri.host);
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'object': 'list',
                  'data': [
                    {
                      'id': options.uri.host.contains('deepseek')
                          ? 'deepseek-v4-flash'
                          : 'glm-5.1',
                      'object': 'model',
                      'owned_by': options.uri.host,
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final service = OpenAiCompatibleExplanationProvider(
        dio: dio,
        apiKeyStore: keyStore,
        settingReader: (key) async => settings[key],
        settingWriter: (key, value) async => settings[key] = value,
      );

      final deepSeek = await service.addProvider(
        kind: LlmProviderKind.deepSeek,
        apiKey: 'deepseek-key',
      );
      final zai = await service.addProvider(
        kind: LlmProviderKind.zai,
        apiKey: 'zai-key',
      );
      final groups = await service.fetchAllModels();

      expect(groups, hasLength(2));
      expect(groups[0].models.single.id, 'deepseek-v4-flash');
      expect(groups[1].models.single.id, 'glm-5.1');
      expect(requestedHosts, containsAll(['api.deepseek.com', 'api.z.ai']));
      expect(await service.apiKeyFor(deepSeek.id), 'deepseek-key');
      expect(await service.apiKeyFor(zai.id), 'zai-key');

      await service.selectModel(providerId: zai.id, model: 'glm-5.1');
      expect((await service.activeProvider)?.id, zai.id);
      expect(await service.baseUrl, 'https://api.z.ai/api/paas/v4');
      expect(await service.model, 'glm-5.1');
    },
  );

  test('AI explanation prompt requests every value in Japanese', () async {
    final settings = <String, String>{};
    final keyStore = _MemoryApiKeyStore();
    Map<String, dynamic>? requestData;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestData = (options.data as Map).cast<String, dynamic>();
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'part_of_speech': '名詞',
                        'context_meaning': '文脈上の意味',
                        'short_explanation': '短い説明',
                        'long_explanation': '詳しい説明',
                      }),
                    },
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    final service = OpenAiCompatibleExplanationProvider(
      dio: dio,
      apiKeyStore: keyStore,
      settingReader: (key) async => settings[key],
      settingWriter: (key, value) async => settings[key] = value,
    );
    final provider = await service.addProvider(
      kind: LlmProviderKind.deepSeek,
      apiKey: 'deepseek-key',
    );
    await service.selectModel(
      providerId: provider.id,
      model: 'deepseek-v4-flash',
    );

    final entry = await service.explain(
      term: 'context',
      outputLanguageCode: 'ja',
    );

    final messages = requestData!['messages'] as List<dynamic>;
    final systemPrompt =
        (messages.first as Map<String, dynamic>)['content'] as String;
    expect(systemPrompt, contains('Write every value in Japanese'));
    expect(entry.definitions.single.meaning, '文脈上の意味');
    expect(entry.shortExplanation, '短い説明');
  });

  test(
    'OpenAI provider starts with the Responses-capable default model',
    () async {
      final settings = <String, String>{};
      final service = OpenAiCompatibleExplanationProvider(
        apiKeyStore: _MemoryApiKeyStore(),
        settingReader: (key) async => settings[key],
        settingWriter: (key, value) async => settings[key] = value,
      );

      final provider = await service.addProvider(
        kind: LlmProviderKind.openAi,
        apiKey: 'openai-key',
      );

      expect(provider.baseUrl, 'https://api.openai.com/v1');
      expect((await service.activeProvider)?.id, provider.id);
      expect(
        await service.model,
        OpenAiCompatibleExplanationProvider.openAiDefaultModel,
      );
    },
  );

  test('missing LLM active id does not guess a replacement provider', () async {
    final settings = <String, String>{};
    final service = OpenAiCompatibleExplanationProvider(
      apiKeyStore: _MemoryApiKeyStore(),
      settingReader: (key) async => settings[key],
      settingWriter: (key, value) async => settings[key] = value,
    );
    final first = await service.addProvider(
      kind: LlmProviderKind.deepSeek,
      apiKey: 'deepseek-key',
    );
    await service.addProvider(kind: LlmProviderKind.zai, apiKey: 'zai-key');
    settings[OpenAiCompatibleExplanationProvider.activeProviderSettingKey] =
        'removed-provider';

    expect(first.id, isNotEmpty);
    expect(await service.activeProvider, isNull);
    expect(
      settings[OpenAiCompatibleExplanationProvider.activeProviderSettingKey],
      'removed-provider',
    );
  });

  test('removing the active LLM provider clears its global model', () async {
    final settings = <String, String>{};
    final service = OpenAiCompatibleExplanationProvider(
      apiKeyStore: _MemoryApiKeyStore(),
      settingReader: (key) async => settings[key],
      settingWriter: (key, value) async => settings[key] = value,
    );
    final first = await service.addProvider(
      kind: LlmProviderKind.deepSeek,
      apiKey: 'deepseek-key',
    );
    expect((await service.activeProvider)?.id, first.id);
    expect(await service.model, isEmpty);

    final second = await service.addProvider(
      kind: LlmProviderKind.zai,
      apiKey: 'zai-key',
    );
    await service.selectModel(providerId: second.id, model: 'glm-5.1');
    await service.removeProvider(second.id);

    expect((await service.activeProvider)?.id, first.id);
    expect(await service.model, isEmpty);
    expect(
      settings[OpenAiCompatibleExplanationProvider.activeProviderSettingKey],
      first.id,
    );
  });

  test(
    'legacy single LLM configuration migrates without losing its key',
    () async {
      final settings = <String, String>{
        OpenAiCompatibleExplanationProvider.baseUrlSettingKey:
            'https://api.deepseek.com',
        OpenAiCompatibleExplanationProvider.modelSettingKey: 'deepseek-v4-pro',
      };
      final keyStore = _MemoryApiKeyStore()
        ..values[OpenAiCompatibleExplanationProvider.apiKeyStorageKey] =
            'legacy-key';
      final service = OpenAiCompatibleExplanationProvider(
        apiKeyStore: keyStore,
        settingReader: (key) async => settings[key],
        settingWriter: (key, value) async => settings[key] = value,
      );

      final providers = await service.configurations;

      expect(providers, hasLength(1));
      expect(providers.single.kind, LlmProviderKind.deepSeek);
      expect(await service.apiKeyFor(providers.single.id), 'legacy-key');
      expect(await service.model, 'deepseek-v4-pro');
    },
  );
}

class _FakeProvider extends VocabularyComProvider {
  int calls = 0;

  _FakeProvider() : super(dio: Dio());

  @override
  Future<VocabularyEntry> lookup(String term) async {
    calls++;
    return const VocabularyComParser().parse(_fixture, requestedTerm: term);
  }
}

class _LevelProvider extends VocabularyComProvider {
  _LevelProvider() : super(dio: Dio());

  @override
  Future<VocabularyEntry> lookup(String term) async {
    return VocabularyEntry(
      word: term,
      normalizedTerm: normalizeDictionaryTerm(term),
      definitions: const [
        VocabularyDefinition(partOfSpeech: 'verb', meaning: 'to leave behind'),
      ],
      otherForms: const [],
      sourceUrl: 'https://example.com/$term',
    );
  }
}

class _FailingParserProvider extends VocabularyComProvider {
  int calls = 0;

  _FailingParserProvider() : super(dio: Dio());

  @override
  Future<VocabularyEntry> lookup(String term) async {
    calls++;
    throw const VocabularyParseException('upstream markup changed');
  }
}

class _NotFoundProvider extends VocabularyComProvider {
  int calls = 0;

  _NotFoundProvider() : super(dio: Dio());

  @override
  Future<VocabularyEntry> lookup(String term) async {
    calls++;
    throw VocabularyNotFoundException(term);
  }
}

class _FakeExplanationProvider extends OpenAiCompatibleExplanationProvider {
  int calls = 0;
  String? lastTerm;
  DictionaryLookupContext? lastContext;
  final List<String> outputLanguages = [];

  _FakeExplanationProvider()
    : super(settingReader: (_) async => null, settingWriter: (_, _) async {});

  @override
  Future<bool> get isConfigured async => true;

  @override
  Future<String> get baseUrl async => 'https://api.deepseek.com';

  @override
  Future<String> get model async => 'deepseek-v4-flash';

  @override
  Future<VocabularyEntry> explain({
    required String term,
    DictionaryLookupContext? context,
    String outputLanguageCode = 'en',
  }) async {
    calls++;
    lastTerm = term;
    lastContext = context;
    outputLanguages.add(outputLanguageCode);
    return VocabularyEntry(
      provider: 'openai_compatible',
      providerLabel: 'deepseek-v4-flash',
      word: term,
      normalizedTerm: normalizeDictionaryTerm(term),
      definitions: const [
        VocabularyDefinition(
          partOfSpeech: 'noun',
          meaning: 'a tree referenced in this scene',
        ),
      ],
      otherForms: const [],
      shortExplanation: 'The sentence refers to a mulberry tree.',
      longExplanation: 'It identifies the specific tree in the scene.',
      sourceUrl: 'https://api.deepseek.com',
    );
  }
}

class _MemoryApiKeyStore extends ApiKeyStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
