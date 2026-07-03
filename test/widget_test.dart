import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/main.dart';
import 'package:lumina/presentation/screens/settings/voice_library_screen.dart';
import 'package:lumina/presentation/widgets/mini_player.dart';

void main() {
  testWidgets('app does not reserve mini player space without media', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('book menu exposes whole-book caching', (tester) async {
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
        chapterCount: 0,
        paragraphCount: 0,
        currentChapterId: null,
        currentParagraphIndex: 0,
        playbackOffsetMs: 0,
        voiceId: null,
        importedAt: 1,
        lastReadAt: 0,
        kind: 'book',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('Cache Entire Book'), findsOneWidget);

    await tester.tap(find.text('Cache Entire Book'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to cache'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('app opens Fish generation profiles without overflow', (
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
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your Library'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Me'), findsWidgets);
    expect(find.text('Listening activity'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('tts-provider-selector')));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    await tester.tap(find.text('Fish Audio API').last);
    await tester.pumpAndSettle();

    final apiDetails = find.byKey(
      const ValueKey('provider-details-fish_audio_api'),
    );
    await Scrollable.ensureVisible(
      tester.element(apiDetails),
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(apiDetails, findsOneWidget);
    await tester.tap(apiDetails);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('生成模式'), findsOneWidget);
    expect(find.text('快速'), findsOneWidget);
    expect(find.text('高质量'), findsOneWidget);
    await tester.tap(find.text('高质量'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('单请求生成 · 44.1 kHz · 平衡质量'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 400));

    await tester.scrollUntilVisible(
      find.text('Logs'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Copy Logs'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('简体中文'), findsOneWidget);
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();

    expect(find.text('通用'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(await database.getSetting('general_language'), 'zhHans');
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
        providerId: 'kokoro_local',
        type: 'preset',
        providerVoiceId: 'af_heart',
        createdAt: 1,
      ),
    );
    await database.upsertVoice(
      const Voice(
        id: 'voice-b',
        name: 'Voice B',
        providerId: 'kokoro_local',
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

    expect(find.textContaining('当前音色 · preset · af_heart'), findsOneWidget);
    await tester.tap(find.text('Voice B'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('当前音色 · preset · af_bella'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('已设为当前音色'), findsOneWidget);
  });
}
