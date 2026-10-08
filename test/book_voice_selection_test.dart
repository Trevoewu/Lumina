import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/album/album_screen.dart';
import 'package:lumina/services/manifest_store.dart';
import 'package:lumina/tts/models/tts_capabilities.dart';
import 'package:lumina/tts/models/tts_chunk.dart';
import 'package:lumina/tts/models/tts_voice.dart';
import 'package:lumina/tts/provider_registry.dart';
import 'package:lumina/tts/tts_provider.dart';

void main() {
  testWidgets('audiobook chapter rows expose swipe actions', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('chapter_swipe_test_');
    final manifestStore = ManifestStore(documentsDirectory: () async => temp);
    addTearDown(database.close);
    addTearDown(() => temp.deleteSync(recursive: true));

    const book = Book(
      id: 'swipe-book',
      title: 'Swipe Book',
      format: 'epub',
      sourcePath: '/tmp/missing-swipe-book.epub',
      chapterCount: 1,
      paragraphCount: 0,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 0,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    const chapter = Chapter(
      id: 'swipe-chapter',
      bookId: 'swipe-book',
      chapterIndex: 0,
      title: 'Swipe Chapter',
      textOffset: 0,
      isHidden: false,
    );
    await database.upsertBook(book);
    await database.insertChapters(const [chapter]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
          activeTtsProviderProvider.overrideWithValue(_LanguageVoiceProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const AlbumScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var row = find.byKey(const ValueKey('book-chapter-swipe-swipe-chapter'));
    await tester.drag(row, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.text('Mark as read')),
    );
    await tester.pumpAndSettle();
    expect(
      (await database.getChapterPlaybackProgress(chapter.id))?.isFinished,
      isTrue,
    );

    row = find.byKey(const ValueKey('book-chapter-swipe-swipe-chapter'));
    await tester.drag(row, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.text('Mark as unread')),
    );
    await tester.pumpAndSettle();
    final unread = await database.getChapterPlaybackProgress(chapter.id);
    expect(unread?.isFinished, isFalse);
    expect(unread?.positionMs, 0);

    row = find.byKey(const ValueKey('book-chapter-swipe-swipe-chapter'));
    await tester.drag(row, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.text('Delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete chapter?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    row = find.byKey(const ValueKey('book-chapter-swipe-swipe-chapter'));
    await tester.drag(row, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.text('Hide')));
    await tester.pumpAndSettle();
    expect(await database.getChapters(book.id), isEmpty);
    expect(row, findsNothing);
  });

  testWidgets('book still saves a voice matching its language', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final temp = Directory.systemTemp.createTempSync('book_voice_test_');
    final manifestStore = ManifestStore(documentsDirectory: () async => temp);
    addTearDown(database.close);
    addTearDown(() => temp.deleteSync(recursive: true));

    const book = Book(
      id: 'voice-book',
      title: 'Language Book',
      language: 'zh-CN',
      format: 'epub',
      sourcePath: '/tmp/missing-voice-book.epub',
      chapterCount: 1,
      paragraphCount: 0,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 0,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    await database.upsertBook(book);
    await database.insertChapters(const [
      Chapter(
        id: 'voice-chapter',
        bookId: 'voice-book',
        chapterIndex: 0,
        title: 'Chapter',
        textOffset: 0,
        isHidden: false,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          manifestStoreProvider.overrideWithValue(manifestStore),
          activeTtsProviderProvider.overrideWithValue(_LanguageVoiceProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const AlbumScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The page no longer shows a picker, but playback and caching still get
    // a voice that matches the book's language.
    expect(find.byKey(const ValueKey('book-voice-selector')), findsNothing);
    // One play button, as on a podcast page; reading is a per-chapter action.
    expect(find.byKey(const ValueKey('book-play-button')), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('book-start-reading-button')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('book-listen-button')), findsNothing);
    expect((await database.getBook(book.id))?.voiceId, 'zh-voice');
  });
}

class _LanguageVoiceProvider implements TtsProvider {
  @override
  String get id => 'language-test';

  @override
  String get displayName => 'Language Test';

  @override
  TtsCapabilities get capabilities => const TtsCapabilities(
    presetVoices: true,
    voiceCloning: false,
    voiceDescription: false,
    maxCharsPerCall: 1000,
  );

  @override
  Future<bool> validate() async => true;

  @override
  Future<List<TtsVoice>> listPresetVoices() async => const [
    TtsVoice(
      id: 'en-voice',
      name: 'English Voice',
      providerId: 'language-test',
      type: VoiceType.preset,
      providerVoiceId: 'en-voice',
      languages: ['en-US'],
      createdAt: 1,
    ),
    TtsVoice(
      id: 'zh-voice',
      name: 'Chinese Voice',
      providerId: 'language-test',
      type: VoiceType.preset,
      providerVoiceId: 'zh-voice',
      languages: ['zh'],
      createdAt: 1,
    ),
  ];

  @override
  Future<TtsVoice> cloneVoice({
    required Uint8List audioBytes,
    required String format,
    required String name,
    String? samplePath,
  }) => throw UnsupportedError('cloneVoice');

  @override
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  }) => throw UnsupportedError('createVoiceFromDescription');

  @override
  Future<TtsChunk> synthesize({
    required String text,
    required TtsVoice voice,
    double speed = 1,
  }) => throw UnsupportedError('synthesize');
}
