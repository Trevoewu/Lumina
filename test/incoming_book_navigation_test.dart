import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/main.dart';
import 'package:lumina/services/book_import_service.dart';
import 'package:lumina/services/incoming_book_import_controller.dart';

class _TestIncomingBookImportController extends IncomingBookImportController {
  @override
  IncomingBookImportState build() => const IncomingBookImportState();

  void succeed(Book book) {
    state = IncomingBookImportState(
      phase: IncomingBookImportPhase.succeeded,
      eventId: state.eventId + 1,
      fileName: 'shared.epub',
      result: BookImportResult(
        book: book,
        chapterCount: book.chapterCount,
        paragraphCount: book.paragraphCount,
      ),
    );
  }
}

void main() {
  testWidgets('a shared EPUB refreshes the library and opens book details', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        incomingBookImportControllerProvider.overrideWith(
          _TestIncomingBookImportController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LuminaApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final book = Book(
      id: 'shared-book',
      title: 'Shared Book',
      author: 'Author',
      format: 'epub',
      sourcePath: '/tmp/shared.epub',
      chapterCount: 1,
      paragraphCount: 1,
      currentParagraphIndex: 0,
      playbackOffsetMs: 0,
      importedAt: 1,
      lastReadAt: 0,
      isRead: false,
      kind: 'book',
      rightsStatus: 'user_uploaded',
    );
    await database.upsertBook(book);

    final controller = container.read(
      incomingBookImportControllerProvider.notifier,
    );
    (controller as _TestIncomingBookImportController).succeed(book);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Shared Book'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Shared Book'), findsWidgets);
  });
}
