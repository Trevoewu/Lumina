import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/ai/ai_assistant_service.dart';
import 'package:lumina/ai/ai_models.dart';
import 'package:lumina/ai/ai_thread_repository.dart';
import 'package:lumina/ai/transcript_tool.dart';
import 'package:lumina/core/app_colors.dart';
import 'package:lumina/core/app_preferences.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/widgets/ai_summary_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'summary collapses, renders markdown, and exposes inline citations',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.insertParagraphs(const [
        Paragraph(
          id: 'paragraph-summary',
          chapterId: 'chapter-summary',
          bookId: 'book-summary',
          paragraphIndex: 0,
          content: 'A grounded fact from the current chapter.',
        ),
      ]);
      const scope = AiContentScope(
        type: AiScopeType.chapter,
        id: 'chapter-summary',
        parentId: 'book-summary',
        title: 'Chapter',
        parentTitle: 'Book',
      );
      final repository = AiThreadRepository(database);
      final transcriptTools = _CountingTranscriptTools(database);
      final assistantService = AiAssistantService(
        transcriptTools: transcriptTools,
        threads: repository,
        configurationLoader: () async => const AiServiceConfiguration(
          baseUrl: 'https://example.invalid',
          apiKey: 'test-key',
          modelId: 'test-model',
        ),
      );
      final snapshot = await AiTranscriptTools(database).load(scope);
      var thread = await repository.ensure(
        snapshot: snapshot,
        modelId: 'deepseek-v4-flash',
      );
      thread = await repository.resetForSummary(thread, 'deepseek-v4-flash');
      await repository.saveAssistantMessage(
        thread: thread,
        content:
            '**Summary**\n\nA grounded fact. [P1]\n\n'
            '**Key points**\n\n- First point. [P1]',
        responseId: 'summary-response',
        modelId: 'deepseek-v4-flash',
        isSummary: true,
      );

      AiCitation? tappedCitation;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            aiAssistantServiceProvider.overrideWithValue(assistantService),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AiSummaryPanel(
                  scope: scope,
                  onCitationTap: (citation) async {
                    tappedCitation = citation;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        transcriptTools.loadCount,
        0,
        reason: 'Mounting the player card must not read the whole chapter.',
      );
      expect(
        find.byKey(const ValueKey('ai-summary-collapsed-preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ai-summary-expand-toggle')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('ai-summary-toggle')), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/ai_summary_collapsed_390.png'),
      );

      await tester.tap(find.byKey(const ValueKey('ai-summary-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('**Summary**'), findsNothing);
      expect(find.textContaining('Summary', findRichText: true), findsWidgets);
      expect(
        find.byKey(const ValueKey('app-content-sheet-close')),
        findsOneWidget,
      );
      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('goldens/ai_summary_expanded_390.png'),
      );
      final citationSpan = _findTextSpan(tester, 'P1');
      expect(citationSpan, isNotNull);
      expect(citationSpan!.recognizer, isA<TapGestureRecognizer>());
      (citationSpan.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pumpAndSettle();
      expect(tappedCitation?.label, 'P1');
      expect(
        find.byKey(const ValueKey('app-content-sheet-close')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('ai-summary-collapsed-preview')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ai-summary-follow-up')), findsNothing);
      expect(find.text('Read summary'), findsNothing);
      expect(find.text('Ask'), findsNothing);
    },
  );

  testWidgets('conversation sheet keeps the package chatbot presentation', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const scope = AiContentScope(
      type: AiScopeType.chapter,
      id: 'chapter-chat',
      parentId: 'book-chat',
      title: 'Chapter',
      parentTitle: 'Book',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const AiConversationSheet(scope: scope),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(chat_ui.Chat), findsOneWidget);
    expect(find.byType(chat_ui.ChatAnimatedList), findsOneWidget);
    final composer = tester.widget<chat_ui.Composer>(
      find.byKey(const ValueKey('ai-follow-up-input')),
    );
    expect(composer.textColor, AppColors.textPrimary);
    expect(composer.keyboardAppearance, Brightness.dark);
  });

  testWidgets('AI setup is requested only after transcript is available', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const scope = AiContentScope(
      type: AiScopeType.episode,
      id: 'episode-setup',
      parentId: 'show-setup',
      title: 'Episode',
      parentTitle: 'Show',
    );
    var aiSetupRequests = 0;
    var transcriptRequests = 0;

    Widget app({required bool transcriptAvailable}) => ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: AiSummaryPanel(
            scope: scope,
            transcriptAvailable: transcriptAvailable,
            aiServiceReady: false,
            onAiServiceRequired: () => aiSetupRequests++,
            onTranscriptRequired: () => transcriptRequests++,
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(transcriptAvailable: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-summary-transcribe')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-service-required')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ai-summary-transcribe')));
    expect(transcriptRequests, 1);

    await tester.pumpWidget(app(transcriptAvailable: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-service-required')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ai-summary-configure-service')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('ai-summary-configure-service')),
    );
    expect(aiSetupRequests, 1);
  });

  testWidgets('summary generation uses AI language instead of UI locale', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.setSetting('general_language', 'zhHans');
    await database.setSetting('ai_service_language', 'japanese');
    final assistantService = _LanguageCapturingAiAssistantService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          aiAssistantServiceProvider.overrideWithValue(assistantService),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          theme: AppTheme.darkTheme(),
          home: const Scaffold(
            body: AiSummaryPanel(
              scope: AiContentScope(
                type: AiScopeType.chapter,
                id: 'chapter-language',
                parentId: 'book-language',
                title: 'Chapter',
                parentTitle: 'Book',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiSummaryPanel)),
    );
    await container.read(appPreferencesProvider.notifier).load();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ai-summary-generate')));
    await tester.pumpAndSettle();

    expect(assistantService.summaryLanguageCode, 'ja');
  });

  testWidgets('summary markdown follows the light theme text color', (
    tester,
  ) async {
    final theme = AppTheme.lightTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: AiAnswerText(text: 'Readable summary body.'),
        ),
      ),
    );
    await tester.pump();

    final bodySpan = _findTextSpan(tester, 'Readable summary body.');
    expect(bodySpan, isNotNull);
    expect(bodySpan!.style?.color, theme.colorScheme.onSurface);
  });
}

TextSpan? _findTextSpan(WidgetTester tester, String text) {
  TextSpan? result;
  bool visit(InlineSpan root) {
    if (root is TextSpan && root.text == text) {
      result = root;
      return true;
    }
    root.visitChildren((span) {
      if (span is TextSpan && span.text == text) result = span;
      return result == null;
    });
    return result != null;
  }

  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    if (visit(richText.text)) return result;
  }
  for (final selectable in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  )) {
    final span = selectable.textSpan;
    if (span != null && visit(span)) return result;
  }
  return null;
}

class _CountingTranscriptTools extends AiTranscriptTools {
  int loadCount = 0;

  _CountingTranscriptTools(super.database);

  @override
  Future<AiTranscriptSnapshot> load(AiContentScope scope) {
    loadCount++;
    return super.load(scope);
  }
}

class _LanguageCapturingAiAssistantService extends AiAssistantService {
  String? summaryLanguageCode;

  _LanguageCapturingAiAssistantService(AppDatabase database)
    : super(
        transcriptTools: AiTranscriptTools(database),
        threads: AiThreadRepository(database),
        configurationLoader: () async => const AiServiceConfiguration(
          baseUrl: 'https://example.invalid',
          apiKey: 'test-key',
          modelId: 'test-model',
        ),
      );

  @override
  Stream<AiAgentUpdate> summarize(
    AiContentScope scope, {
    required String languageCode,
  }) {
    summaryLanguageCode = languageCode;
    return Stream<AiAgentUpdate>.fromIterable(const [
      AiAgentUpdate.resetText(),
      AiAgentUpdate.textDelta('Generated summary.'),
      AiAgentUpdate.completed('response-language'),
    ]);
  }
}
