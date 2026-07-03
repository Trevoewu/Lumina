import 'package:flutter/widgets.dart';

extension AppLocalizationsContext on BuildContext {
  bool get usesChinese => Localizations.localeOf(this).languageCode == 'zh';

  String tr(String chinese, String english) => usesChinese ? chinese : english;
}
