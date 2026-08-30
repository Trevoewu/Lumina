import 'package:flutter/widgets.dart';

extension AppLocalizationsContext on BuildContext {
  /// The locale to translate with.
  ///
  /// `Localizations.localeOf` reads an inherited widget, and an element that
  /// has been deactivated — a live route rebuilding from the state of a screen
  /// that is being popped — no longer has any. In a release build that lookup
  /// returns null and the null check inside `localeOf` takes the whole app
  /// down. Translating a label is never worth a crash, so fall back to the
  /// platform's own locale; debug builds still assert on the bad lookup.
  Locale get translationLocale =>
      Localizations.maybeLocaleOf(this) ??
      WidgetsBinding.instance.platformDispatcher.locale;

  bool get usesChinese => translationLocale.languageCode == 'zh';
  bool get usesJapanese => translationLocale.languageCode == 'ja';

  String tr(String chinese, String english, [String? japanese]) {
    if (usesChinese) return chinese;
    if (usesJapanese) return japanese ?? english;
    return english;
  }
}
