enum AiScopeType {
  chapter('chapter'),
  episode('episode');

  final String value;

  const AiScopeType(this.value);
}

class AiContentScope {
  final AiScopeType type;
  final String id;
  final String parentId;
  final String title;
  final String parentTitle;
  final String? language;
  final Object? contentRevision;

  const AiContentScope({
    required this.type,
    required this.id,
    required this.parentId,
    required this.title,
    required this.parentTitle,
    this.language,
    this.contentRevision,
  });

  bool get isPodcast => type == AiScopeType.episode;
}

class AiCitation {
  final String label;
  final int? paragraphIndex;
  final int? positionMs;

  const AiCitation({required this.label, this.paragraphIndex, this.positionMs});
}

List<AiCitation> extractAiCitations(String text) {
  final citations = <AiCitation>[];
  final labels = <String>{};
  final pattern = RegExp(r'\[(P\d+|\d{1,2}:\d{2}(?::\d{2})?)\]');
  for (final match in pattern.allMatches(text)) {
    final label = match.group(1)!;
    if (!labels.add(label)) continue;
    if (label.startsWith('P')) {
      citations.add(
        AiCitation(
          label: label,
          paragraphIndex: int.tryParse(label.substring(1)),
        ),
      );
      continue;
    }
    final parts = label.split(':').map(int.parse).toList(growable: false);
    final seconds = parts.length == 2
        ? parts[0] * 60 + parts[1]
        : parts[0] * 3600 + parts[1] * 60 + parts[2];
    citations.add(AiCitation(label: label, positionMs: seconds * 1000));
  }
  return citations;
}

enum AiAgentUpdateType { status, resetText, textDelta, completed, failed }

class AiAgentUpdate {
  final AiAgentUpdateType type;
  final String? text;
  final String? responseId;

  const AiAgentUpdate._(this.type, {this.text, this.responseId});

  const AiAgentUpdate.status(String text)
    : this._(AiAgentUpdateType.status, text: text);

  const AiAgentUpdate.resetText() : this._(AiAgentUpdateType.resetText);

  const AiAgentUpdate.textDelta(String text)
    : this._(AiAgentUpdateType.textDelta, text: text);

  const AiAgentUpdate.completed(String responseId)
    : this._(AiAgentUpdateType.completed, responseId: responseId);

  const AiAgentUpdate.failed(String text)
    : this._(AiAgentUpdateType.failed, text: text);
}

class AiAssistantConfigurationException implements Exception {
  final String message;

  const AiAssistantConfigurationException(this.message);

  @override
  String toString() => message;
}
