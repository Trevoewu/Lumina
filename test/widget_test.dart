import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/data/dictionary/openai_compatible_explanation_provider.dart';
import 'package:lumina/main.dart';
import 'package:lumina/presentation/widgets/narrator_label.dart';
import 'package:lumina/presentation/screens/settings/settings_screen.dart';
import 'package:lumina/presentation/screens/settings/llm_setup_wizard_screen.dart';
import 'package:lumina/presentation/screens/settings/tts_setup_wizard_screen.dart';
import 'package:lumina/presentation/screens/settings/voice_library_screen.dart';
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
      find.byKey(const ValueKey('home-navigation-active-icon')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.home), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(
      find.byKey(const ValueKey('dictionary-navigation-icon')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.menu_book), findsNothing);
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('app text size is relative to system accessibility scaling', (
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
      closeTo(22.1, 0.01),
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
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(bookCard);
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await database.markChapterFinished(
      'book-cache-test',
      'book-cache-test_ch_2',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-overview-hero')), findsOneWidget);
    expect(find.textContaining('25% read'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-section-books')));
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

  testWidgets('TTS setup advances inside one wizard page', (tester) async {
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
    expect(find.byType(NavigationBar), findsOneWidget);
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide,
    );
    expect(tester.getSize(find.byType(NavigationBar)).height, 46);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Me'), findsWidgets);
    expect(find.text('TODAY'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The trimmed settings page fits all three service rows without scrolling.
    await tester.tap(find.byKey(const ValueKey('tts-service-settings')));
    await tester.pumpAndSettle();
    final wizardElement = tester.element(find.byType(TtsSetupWizardScreen));
    await tester.tap(find.text('Fish Audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();

    expect(find.byType(TtsSetupWizardScreen), findsOneWidget);
    expect(
      tester.element(find.byType(TtsSetupWizardScreen)),
      same(wizardElement),
    );
    expect(find.byKey(const ValueKey('wizard-tts-api-key')), findsOneWidget);
    expect(find.text('Where do I get an API key?'), findsOneWidget);

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
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    final settingsScrollable = find.byType(Scrollable).last;
    final logsRow = find.byKey(const ValueKey('logs-settings'));
    await tester.scrollUntilVisible(logsRow, 120, scrollable: settingsScrollable);
    await tester.pumpAndSettle();
    await tester.tap(logsRow);
    await tester.pumpAndSettle();

    expect(find.text('Debug'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    expect(find.byTooltip('Copy Logs'), findsNothing);
    expect(find.byTooltip('Clear Logs'), findsOneWidget);
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
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Settings'));
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
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('简体中文'), findsOneWidget);
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();

    expect(find.text('更多'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('外观细节'), findsOneWidget);

    await tester.tap(languageRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();

    expect(find.text('その他'), findsOneWidget);
    expect(find.text('言語'), findsOneWidget);
    expect(find.text('外観の詳細'), findsOneWidget);

    await tester.drag(settingsScrollable, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ライト'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(await database.getSetting('general_language'), 'japanese');
    expect(await database.getSetting('general_theme_mode'), 'light');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('voice library marks and updates the active voice inline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.upsertVoice(
      const Voice(
        id: 'voice-a',
        name: 'Voice A',
        providerId: 'fish_audio_api',
        type: 'preset',
        providerVoiceId: 'af_heart',
        languagesJson: '["en"]',
        sampleCount: 2,
        createdAt: 1,
      ),
    );
    await database.upsertVoice(
      const Voice(
        id: 'voice-b',
        name: 'Voice B',
        providerId: 'fish_audio_api',
        type: 'preset',
        providerVoiceId: 'af_bella',
        createdAt: 2,
      ),
    );
    await database.setSetting('active_voice_id', 'voice-a');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: VoiceLibraryScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.textContaining('Current voice · preset · af_heart'),
      findsOneWidget,
    );
    expect(find.text('🇺🇸'), findsOneWidget);
    expect(find.text('2 audio samples'), findsOneWidget);
    expect(find.text('0 audio samples'), findsOneWidget);
    expect(find.byIcon(Icons.spatial_audio_off_outlined), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voice B'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Current voice · preset · af_bella'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Set as current voice'), findsOneWidget);
  });

  testWidgets('settings opens LLM provider picker and requires an API key', (
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
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(providerSettings);
    await tester.pumpAndSettle();

    expect(find.byType(LlmSetupWizardScreen), findsOneWidget);
    expect(find.text('DeepSeek'), findsOneWidget);
    expect(find.text('Z.AI'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.text('Z.AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('https://api.z.ai/api/paas/v4'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
  );
}
