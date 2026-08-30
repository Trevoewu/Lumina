import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/app_localizations.dart';

void main() {
  testWidgets('tr follows the surrounding Localizations locale', (
    tester,
  ) async {
    late String translated;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('zh', 'CN'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            translated = context.tr('中文', 'English', '日本語');
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(translated, '中文');
  });

  testWidgets('tr falls back instead of crashing without a Localizations', (
    tester,
  ) async {
    // A route that outlives the screen whose state builds it keeps calling
    // these methods with a deactivated context, which has no inherited widgets
    // left. In a release build that reads as "no Localizations at all", and a
    // throw there takes the whole app down mid-playback.
    late String translated;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            translated = context.tr('中文', 'English', '日本語');
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      translated,
      TestWidgetsFlutterBinding.instance.platformDispatcher.locale.languageCode
              .startsWith('zh')
          ? '中文'
          : 'English',
    );
  });
}
