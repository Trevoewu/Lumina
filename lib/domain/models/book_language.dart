String? normalizeBookLanguage(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? inferLanguageFromTitle(String title) {
  final value = title.trim();
  if (value.isEmpty) return null;

  if (RegExp(r'[\u3040-\u30ff]').hasMatch(value)) return 'ja';
  if (RegExp(r'[\uac00-\ud7af]').hasMatch(value)) return 'ko';
  if (RegExp(r'[\u4e00-\u9fff]').hasMatch(value)) return 'zh';
  if (RegExp(r'[\u0400-\u04ff]').hasMatch(value)) return 'ru';
  if (RegExp(r'[\u0370-\u03ff]').hasMatch(value)) return 'el';
  if (RegExp(r'[\u0600-\u06ff]').hasMatch(value)) return 'ar';
  if (RegExp(r'[\u0900-\u097f]').hasMatch(value)) return 'hi';
  if (RegExp(r'[A-Za-z]').hasMatch(value)) return 'en';

  return null;
}
