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
      final citationSpan = _findTextSpan(tester, 'P1');
      expect(citationSpan, isNotNull);
      expect(citationSpan!.recognizer, isA<TapGestureRecognizer>());
      (citationSpan.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(tappedCitation?.label, 'P1');
      expect(find.byKey(const ValueKey('ai-summary-toggle')), findsOneWidget);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/ai_summary_expanded_390.png'),
      );

      await tester.tap(find.byKey(const ValueKey('ai-summary-toggle')));
      await tester.pumpAndSettle();
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
