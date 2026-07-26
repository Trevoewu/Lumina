import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/presentation/widgets/podcast_link_text.dart';

void main() {
  test('detects web links without swallowing sentence punctuation', () {
    final segments = linkifyPodcastText(
      'Notes: https://example.com/path?q=one, and '
      '(https://example.org/about).',
    );

    expect(
      segments
          .where((segment) => segment.uri != null)
          .map((segment) => (segment.text, segment.uri.toString())),
      [
        ('https://example.com/path?q=one', 'https://example.com/path?q=one'),
        ('https://example.org/about', 'https://example.org/about'),
      ],
    );
    expect(segments.map((segment) => segment.text).join(), contains(').'));
  });

  testWidgets('renders podcast links as tappable spans', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: PodcastLinkText(
            'Read https://example.com/notes for details.',
            key: const ValueKey('link-text'),
            onOpenUrl: (uri) => opened = uri,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('link-text')),
        matching: find.byType(Text),
      ),
    );
    final rootSpan = text.textSpan! as TextSpan;
    final linkSpan = rootSpan.children!.whereType<TextSpan>().firstWhere(
      (span) => span.recognizer != null,
    );
    expect(linkSpan.text, 'https://example.com/notes');
    expect(linkSpan.style?.decoration, TextDecoration.underline);

    (linkSpan.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    expect(opened, Uri.parse('https://example.com/notes'));
  });
}
