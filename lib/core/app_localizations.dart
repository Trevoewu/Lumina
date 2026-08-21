import 'package:flutter/widgets.dart';

extension AppLocalizationsContext on BuildContext {
  bool get usesChinese => Localizations.localeOf(this).languageCode == 'zh';
  bool get usesJapanese => Localizations.localeOf(this).languageCode == 'ja';

  String tr(String chinese, String english, [String? japanese]) {
    if (usesChinese) return chinese;
    if (usesJapanese) return japanese ?? english;
    return english;
  }
}
