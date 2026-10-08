import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:lumina/presentation/widgets/app_back_button.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/dictionary/openai_compatible_explanation_provider.dart';
import 'package:lumina/main.dart';
import 'package:lumina/presentation/widgets/narrator_label.dart';
import 'package:lumina/presentation/screens/settings/settings_screen.dart';
import 'package:lumina/presentation/screens/settings/provider_editor_sheet.dart';
import 'package:lumina/presentation/screens/settings/tts_provider_editor_sheet.dart';
import 'package:lumina/presentation/screens/settings/tts_service_screen.dart';
import 'package:lumina/tts/models/tts_voice.dart';
import 'package:lumina/tts/models/tts_model.dart';
import 'package:lumina/presentation/widgets/mini_player.dart';
import 'package:lumina/presentation/widgets/book_list_card.dart';

void main() {
  testWidgets('narrator label shows the selected voice', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertVoice(
      const Voice(
        id: 'voice-a',
        name: 'Voice A',
        providerId: 'fish_audio_api',
        type: 'preset',
        providerVoiceId: 'af_heart',
        createdAt: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: NarratorLabel(voiceId: 'voice-a'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Read by Voice A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app does not reserve mini player space without media', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          ttsSettingsControllerProvider.overrideWith(_WidgetTtsController.new),
          ttsProviderConfigurationStatusProvider.overrideWith(
            (ref) async => const {'fish_audio_api': false, 'minimax': false},
          ),
        ],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('app-content-layer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-content-mini-player-inset')),
      findsNothing,
    );
    expect(find.byType(MiniPlayer), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CNIcon &&
            widget.imageAsset?.assetPath == 'assets/ui_icons/home@3x.png',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.home), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    for (final name in ['home', 'library', 'dictionary', 'search']) {
      final icon = find.byWidgetPredicate(
        (widget) => widget is CNIcon &&
            widget.imageAsset?.assetPath == 'assets/ui_icons/$name@3x.png',
      );
      expect(tester.getSize(icon), const Size(25, 25));
    }
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CNIcon &&
            widget.imageAsset?.assetPath ==
                'assets/ui_icons/dictionary@3x.png',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.menu_book), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.icon == AppIcons.bookOpen01,
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    // CNTabBar leaves a 200ms Future.delayed running past dispose; pump past
    // it so the binding does not report a pending timer.
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('app text size preserves system accessibility scaling without reader font scale leakage', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.setSetting('appearance_font_scale', '1.30');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final contentContext = tester.element(
      find.byKey(const ValueKey('app-content-layer')),
    );
    expect(
      MediaQuery.textScalerOf(contentContext).scale(10),
      closeTo(17.0, 0.01),
    );
  });

  testWidgets('book menus expose actions and refresh finished progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertBook(
      Book(
        id: 'book-cache-test',
        title: 'Cache Test',
        author: 'Author',
        format: 'epub',
        sourcePath: '/tmp/cache-test.epub',
        coverPath: null,
        chapterCount: 4,
        paragraphCount: 100,
        currentChapterId: null,
        currentParagraphIndex: 0,
        playbackOffsetMs: 0,
        voiceId: null,
        importedAt: 1,
        lastReadAt: 0,
        isRead: false,
        kind: 'book',
        rightsStatus: 'user_uploaded',
      ),
    );
    await database.insertChapters([
      const Chapter(
        id: 'book-cache-test_ch_2',
        bookId: 'book-cache-test',
        chapterIndex: 2,
        title: 'Chapter 3',
        textOffset: 0,
        isHidden: false,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    var bookCard = find.byKey(const ValueKey('home-overview-hero'));
    expect(bookCard, findsOneWidget);
    expect(find.textContaining('0% read'), findsOneWidget);
    await tester.longPress(bookCard);
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsOneWidget);
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(find.textContaining('100% read'), findsOneWidget);

    await tester.longPress(bookCard);
    await tester.pumpAndSettle();
    expect(find.text('Mark as unread'), findsOneWidget);
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0% read'), findsOneWidget);

    await tester.longPress(bookCard);
    await tester.pumpAndSettle();
    expect(find.text('Cache Entire Book'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.icon == AppIcons.cancel01,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(bookCard);
    await tester.pumpAndSettle();
    expect(find.byType(AppBackButton), findsOneWidget);
    await database.markChapterFinished(
      'book-cache-test',
      'book-cache-test_ch_2',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-overview-hero')), findsOneWidget);
    expect(find.textContaining('25% read'), findsOneWidget);

    // Books live on the Library tab now.
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    bookCard = find.byType(BookListCard);
    expect(
      find.descendant(of: bookCard, matching: find.byIcon(Icons.more_horiz)),
      findsNothing,
    );
    await tester.longPress(bookCard);
    await tester.pumpAndSettle();
    expect(find.text('Cache Entire Book'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('the voice pane lists providers and edits keys in a sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          ttsSettingsControllerProvider.overrideWith(_WidgetTtsController.new),
          ttsProviderConfigurationStatusProvider.overrideWith(
            (ref) async => const {'fish_audio_api': false, 'minimax': false},
          ),
        ],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Home'), findsWidgets);
    expect(find.byType(CNTabBar), findsOneWidget);
    final navigationBar = tester.widget<CNTabBar>(find.byType(CNTabBar));
    // Home, Library, Dictionary and Search; Settings opens from Home.
    expect(navigationBar.items, hasLength(4));
    expect(navigationBar.currentIndex, 0);

    await tester.tap(find.byKey(const ValueKey('home-settings-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The trimmed settings page fits all three service rows without scrolling.
    await tester.tap(find.byKey(const ValueKey('tts-service-settings')));
    await tester.pumpAndSettle();

    // Both built-in providers are listed as cards.
    expect(
      find.byKey(const ValueKey('tts-provider-fish_audio_api')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tts-provider-minimax')), findsOneWidget);

    // Credentials live in a sheet behind the edit button.
    await tester.tap(find.byKey(const ValueKey('tts-edit-fish_audio_api')));
    await tester.pumpAndSettle();
    expect(find.byType(TtsProviderEditorSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('tts-api-key')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-tts-provider')), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('settings opens logs as a full page', (tester) async {
    tester.view.physicalSize = const Size(430, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('home-settings-action')));
    await tester.pumpAndSettle();

    final settingsScrollable = find.byType(Scrollable).last;
    final logsRow = find.byKey(const ValueKey('logs-settings'));
    await tester.scrollUntilVisible(
      logsRow,
      120,
      scrollable: settingsScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(logsRow);
    await tester.pumpAndSettle();

    // Subsystem filter chips over the console, with export and clear below.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('ASR'), findsWidgets);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('TTS'), findsWidgets);
    expect(find.byKey(const ValueKey('export-logs')), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-logs')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('general settings switch language and theme', (tester) async {
    tester.view.physicalSize = const Size(430, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('home-settings-action')));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);

    final settingsScrollable = find.byType(Scrollable).last;
    final languageRow = find.byKey(const ValueKey('language-selector'));
    await tester.scrollUntilVisible(
      languageRow,
      120,
      scrollable: settingsScrollable,
    );
    await tester.pumpAndSettle();
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    await tester.tap(languageRow);
    await tester.pumpAndSettle();
    expect(find.text('UI Language'), findsOneWidget);
    expect(find.text('AI Service Language'), findsOneWidget);
    final uiLanguageRow = find.byKey(const ValueKey('ui-language-selector'));
    await tester.tap(uiLanguageRow);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('简体中文'), findsOneWidget);
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();

    expect(find.text('界面'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('AI 服务语言'), findsOneWidget);

    await tester.tap(uiLanguageRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();

    expect(find.text('インターフェース'), findsOneWidget);
    expect(find.text('言語'), findsOneWidget);
    expect(find.text('AIサービス言語'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ai-language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ライト'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(await database.getSetting('general_language'), 'japanese');
    expect(await database.getSetting('ai_service_language'), 'english');
    expect(await database.getSetting('general_theme_mode'), 'light');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('the active provider card selects a voice inline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _VoiceCardTtsController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsSettingsControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: TtsServiceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Both voices show on the active provider card, each with a preview.
    expect(find.byKey(const ValueKey('tts-voice-voice-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('tts-voice-voice-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('tts-preview-voice-a')), findsOneWidget);
    // The inactive provider stays collapsed.
    expect(find.byKey(const ValueKey('tts-voice-voice-m')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tts-voice-voice-b')));
    await tester.pumpAndSettle();
    expect(controller.selectedVoiceIds, ['voice-b']);

    // Model chips belong to the active card too.
    await tester.tap(find.text('Speech 1.6'));
    await tester.pumpAndSettle();
    expect(controller.selectedModelIds, ['speech-1.6']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings opens the AI provider sheet and requires an API key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.setSetting(
      OpenAiCompatibleExplanationProvider.providerConfigurationsSettingKey,
      '[]',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final providerSettings = find.byKey(
      const ValueKey('llm-provider-settings'),
    );
    await tester.ensureVisible(providerSettings);
    await tester.pumpAndSettle();
    await tester.tap(providerSettings);
    await tester.pumpAndSettle();

    // Nothing is configured yet, so the pane is just the add button.
    expect(find.byKey(const ValueKey('add-llm-provider')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-llm-provider')));
    await tester.pumpAndSettle();

    expect(find.byType(LlmProviderEditorSheet), findsOneWidget);
    expect(find.text('DeepSeek'), findsWidgets);
    expect(find.text('Z.AI'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);

    // Fetching without a key must not attempt a request.
    await tester.tap(find.byKey(const ValueKey('fetch-provider-models')));
    await tester.pumpAndSettle();
    expect(find.textContaining('missing API key'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _VoiceCardTtsController extends TtsSettingsController {
  final selectedVoiceIds = <String>[];
  final selectedModelIds = <String>[];

  static const _voices = <TtsVoice>[
    TtsVoice(
      id: 'voice-a',
      name: 'Voice A',
      providerId: 'fish_audio_api',
      type: VoiceType.preset,
      providerVoiceId: 'af_heart',
      languages: ['en'],
      createdAt: 1,
    ),
    TtsVoice(
      id: 'voice-b',
      name: 'Voice B',
      providerId: 'fish_audio_api',
      type: VoiceType.preset,
      providerVoiceId: 'af_bella',
      createdAt: 2,
    ),
  ];

  TtsSettingsState _state(String voiceId) => TtsSettingsState(
    providerId: 'fish_audio_api',
    providerName: 'Fish Audio API',
    modelId: 'speech-1.5',
    modelName: 'Speech 1.5',
    voiceId: voiceId,
    voiceName: voiceId,
    readiness: ServiceReadiness.ready,
    providers: const [],
    voices: _voices,
    cards: [
      TtsProviderCardData(
        id: 'fish_audio_api',
        name: 'Fish Audio API',
        tag: 'Cloud service',
        active: true,
        configured: true,
        selectedModelId: 'speech-1.5',
        selectedVoiceId: voiceId,
        models: const [
          TtsModel(id: 'speech-1.5', name: 'Speech 1.5', description: ''),
          TtsModel(id: 'speech-1.6', name: 'Speech 1.6', description: ''),
        ],
        voices: _voices,
      ),
      const TtsProviderCardData(
        id: 'minimax',
        name: 'MiniMax',
        tag: 'Cloud service',
        active: false,
        configured: false,
      ),
    ],
  );

  @override
  Future<TtsSettingsState> build() async => _state('voice-a');

  @override
  Future<void> selectVoice(String voiceId) async {
    selectedVoiceIds.add(voiceId);
    state = AsyncData(_state(voiceId));
  }

  @override
  Future<void> selectModel(String modelId) async {
    selectedModelIds.add(modelId);
  }
}

class _WidgetTtsController extends TtsSettingsController {
  @override
  Future<TtsSettingsState> build() async => const TtsSettingsState(
    providerId: 'fish_audio_api',
    providerName: 'Fish Audio API',
    voiceId: null,
    voiceName: null,
    readiness: ServiceReadiness.setupRequired,
    providers: [
      ProviderOptionViewData(
        id: 'fish_audio_api',
        name: 'Fish Audio API',
        subtitle: 'Cloud service',
        readiness: ServiceReadiness.setupRequired,
        active: true,
        editable: true,
        removable: false,
      ),
      ProviderOptionViewData(
        id: 'minimax',
        name: 'MiniMax 语音合成',
        subtitle: 'Cloud service',
        readiness: ServiceReadiness.setupRequired,
        active: false,
        editable: true,
        removable: false,
      ),
    ],
    voices: [],
    cards: [
      TtsProviderCardData(
        id: 'fish_audio_api',
        name: 'Fish Audio API',
        tag: 'Cloud service',
        active: true,
        configured: false,
      ),
      TtsProviderCardData(
        id: 'minimax',
        name: 'MiniMax 语音合成',
        tag: 'Cloud service',
        active: false,
        configured: false,
      ),
    ],
  );

  /// The real lookup goes through the platform keychain, which is not
  /// available under `flutter test`.
  @override
  Future<String?> apiKeyFor(String providerId) async => null;
}
