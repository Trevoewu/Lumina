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

  test('stops links before Chinese prose after a closing parenthesis', () {
    const text =
        '小宇宙 (https://www.xiaoyuzhoufm.com/podcast/626b46ea)、'
        'Apple Podcast (https://podcasts.apple.com/cn/podcast/id1634356920)、'
        'Spotify';
    final segments = linkifyPodcastText(text);

    expect(
      segments
          .where((segment) => segment.uri != null)
          .map((segment) => segment.uri.toString()),
      [
        'https://www.xiaoyuzhoufm.com/podcast/626b46ea',
        'https://podcasts.apple.com/cn/podcast/id1634356920',
      ],
    );
    expect(segments.map((segment) => segment.text).join(), text);
    expect(
      segments
          .where((segment) => segment.uri != null)
          .map((segment) => segment.text),
      everyElement(isNot(contains('Apple'))),
    );
  });

  test('detects chapter timestamps and converts them to seek positions', () {
    final segments = linkifyPodcastText(
      'OUTLINE:00:02:11 机器人 00:36:33 草蛇灰线 53:56 尾声',
    );

    expect(
      segments
          .where((segment) => segment.seekPosition != null)
          .map((segment) => (segment.text, segment.seekPosition)),
      [
        ('00:02:11', const Duration(minutes: 2, seconds: 11)),
        ('00:36:33', const Duration(minutes: 36, seconds: 33)),
        ('53:56', const Duration(minutes: 53, seconds: 56)),
      ],
    );
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

  testWidgets('renders timestamps as tappable seek spans', (tester) async {
    Duration? sought;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: PodcastLinkText(
            'Outline 00:36:33 discussion',
            key: const ValueKey('timestamp-text'),
            onSeekTimestamp: (position) => sought = position,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('timestamp-text')),
        matching: find.byType(Text),
      ),
    );
    final timestampSpan = (text.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .firstWhere((span) => span.text == '00:36:33');
    expect(timestampSpan.style?.decoration, TextDecoration.underline);

    (timestampSpan.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    expect(sought, const Duration(minutes: 36, seconds: 33));
  });
}
