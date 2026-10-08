import 'dart:convert';

import '../../../data/database/app_database.dart';

/// The last few queries the reader actually ran, newest first, kept in the
/// settings table so they survive restarts.
class SearchHistory {
  static const settingKey = 'search.recent_queries';
  static const limit = 8;

  final AppDatabase database;

  const SearchHistory(this.database);

  Future<List<String>> load() async {
    final raw = await database.getSetting(settingKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String && item.trim().isNotEmpty) item,
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Moves [query] to the front, dropping a case-insensitive duplicate.
  Future<List<String>> record(String query) async {
    final term = query.trim();
    if (term.isEmpty) return load();
    final lower = term.toLowerCase();
    final next = [
      term,
      for (final item in await load())
        if (item.toLowerCase() != lower) item,
    ].take(limit).toList(growable: false);
    await database.setSetting(settingKey, jsonEncode(next));
    return next;
  }

  Future<void> clear() => database.setSetting(settingKey, '[]');
}
