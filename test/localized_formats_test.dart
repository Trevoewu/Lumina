import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/relative_time.dart';
import 'package:lumina/presentation/screens/podcast/podcast_formatters.dart';

/// Runs [read] with a context set to [locale].
Future<String> _inLocale(
  WidgetTester tester,
  Locale locale,
  String Function(BuildContext context) read,
) async {
  late String value;
  await tester.pumpWidget(
    Localizations(
      locale: locale,
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Builder(
        builder: (context) {
          value = read(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return value;
}

void main() {
  const en = Locale('en');
  const zh = Locale('zh');
  const ja = Locale('ja');
  const longEpisode = (95 * 60 + 10) * 1000;
  const shortEpisode = 25 * 60 * 1000;

  testWidgets('episode lengths follow the app language', (tester) async {
    expect(
      await _inLocale(tester, en, (c) => formatPodcastDuration(c, longEpisode)),
      '1h 35m',
    );
    expect(
      await _inLocale(
        tester,
        en,
        (c) => formatPodcastDuration(c, shortEpisode),
      ),
      '25 min',
    );
    expect(
      await _inLocale(tester, zh, (c) => formatPodcastDuration(c, longEpisode)),
      '1小时35分钟',
    );
    expect(
      await _inLocale(tester, ja, (c) => formatPodcastDuration(c, longEpisode)),
      '1時間35分',
    );
    expect(await _inLocale(tester, en, (c) => formatPodcastDuration(c, 0)), '');
  });

  testWidgets('dates read relatively, then as a short local date', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = now.subtract(const Duration(hours: 2));
    final threeDays = now.subtract(const Duration(days: 3));
    final older = DateTime(now.year - 1, 9, 29, 12);

    expect(
      await _inLocale(
        tester,
        en,
        (c) => relativeTimeLabel(c, today.millisecondsSinceEpoch),
      ),
      'Today',
    );
    expect(
      await _inLocale(
        tester,
        zh,
        (c) => relativeTimeLabel(c, threeDays.millisecondsSinceEpoch),
      ),
      '3 天前',
    );
    // Not an ISO timestamp next to "3 days ago".
    expect(
      await _inLocale(
        tester,
        en,
        (c) => relativeTimeLabel(c, older.millisecondsSinceEpoch),
      ),
      'Sep 29, ${now.year - 1}',
    );
    expect(
      await _inLocale(
        tester,
        zh,
        (c) => shortDateLabel(c, DateTime(now.year, 9, 29)),
      ),
      '9月29日',
    );
  });
}
