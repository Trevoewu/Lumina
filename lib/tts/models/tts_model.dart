typedef TtsModelSelectionReader = Future<String?> Function(String providerId);

enum TtsModelCatalogSource {
  officialApi,
  bundledFallback,
  cachedAfterSyncFailure,
}

class TtsModel {
  final String id;
  final String name;
  final String description;
  final bool recommended;

  const TtsModel({
    required this.id,
    required this.name,
    required this.description,
    this.recommended = false,
  });
}
