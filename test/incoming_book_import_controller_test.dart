import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/incoming_book_import_controller.dart';
import 'package:share_handler/share_handler.dart';

void main() {
  test('keeps only unique EPUB attachments, case-insensitively', () {
    final media = SharedMedia(
      attachments: [
        SharedAttachment(
          path: '/private/tmp/My Book.EPUB',
          type: SharedAttachmentType.file,
        ),
        SharedAttachment(
          path: '/private/tmp/My Book.EPUB',
          type: SharedAttachmentType.file,
        ),
        SharedAttachment(
          path: '/private/tmp/notes.txt',
          type: SharedAttachmentType.file,
        ),
      ],
    );

    expect(IncomingBookImportController.epubPaths(media), [
      '/private/tmp/My Book.EPUB',
    ]);
  });

  test('returns no paths when a share has no EPUB attachment', () {
    final media = SharedMedia(content: 'https://example.com/book.epub');

    expect(IncomingBookImportController.epubPaths(media), isEmpty);
  });
}
