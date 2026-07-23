import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

String? normalizeBookIntroduction(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final text = (html_parser.parseFragment(raw).text ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.isEmpty ? null : text;
}

String? bookIntroductionFromMetadataJson(String? metadataJson) {
  final rawJson = metadataJson?.trim();
  if (rawJson == null || rawJson.isEmpty) return null;
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) return null;
    final metadata = Map<String, dynamic>.from(decoded);
    final raw = metadata['raw'];
    final rawMetadata = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    for (final candidate in [
      metadata['description'],
      metadata['summary'],
      rawMetadata['description'],
      rawMetadata['summary'],
      rawMetadata['summaries'],
    ]) {
      if (candidate is String) {
        final normalized = normalizeBookIntroduction(candidate);
        if (normalized != null) return normalized;
      } else if (candidate is List) {
        for (final entry in candidate.whereType<String>()) {
          final normalized = normalizeBookIntroduction(entry);
          if (normalized != null) return normalized;
        }
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

String metadataJsonWithBookIntroduction(
  String? metadataJson,
  String introduction,
) {
  final metadata = <String, dynamic>{};
  final rawJson = metadataJson?.trim();
  if (rawJson != null && rawJson.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map) metadata.addAll(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // Preserve a usable metadata record even when legacy JSON is malformed.
    }
  }
  metadata['description'] = normalizeBookIntroduction(introduction);
  return jsonEncode(metadata);
}
