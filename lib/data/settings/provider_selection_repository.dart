import 'dart:convert';

typedef SelectionSettingReader = Future<String?> Function(String key);
typedef SelectionSettingWriter =
    Future<void> Function(String key, String value);

enum SelectionMigrationStatus {
  migrated,
  alreadyMigrated,
  noLegacySelection,
  setupRequired,
}

class ProviderSelectionMigrationResult {
  final SelectionMigrationStatus ttsVoice;
  final SelectionMigrationStatus llmModel;

  const ProviderSelectionMigrationResult({
    required this.ttsVoice,
    required this.llmModel,
  });
}

/// Owns Provider-scoped Voice and Model selections during the settings
/// migration. Legacy global keys are mirrored until every runtime consumer has
/// moved to this repository.
class ProviderSelectionRepository {
  static const schemaVersionKey = 'service_settings_schema_version';
  static const currentSchemaVersion = '1';
  static const ttsVoiceMapKey = 'tts_selected_voice_by_provider_v1';
  static const ttsModelMapKey = 'tts_selected_model_by_provider_v1';
  static const llmModelMapKey = 'llm_selected_model_by_provider_v1';

  static const legacyTtsVoiceKey = 'active_voice_id';
  static const legacyLlmModelKey = 'openai_compatible_dictionary_model';

  final SelectionSettingReader _read;
  final SelectionSettingWriter _write;

  const ProviderSelectionRepository({
    required SelectionSettingReader settingReader,
    required SelectionSettingWriter settingWriter,
  }) : _read = settingReader,
       _write = settingWriter;

  Future<String?> selectedVoice(String providerId) =>
      _selectionFor(ttsVoiceMapKey, providerId, legacyKey: legacyTtsVoiceKey);

  Future<String?> selectedTtsModel(String providerId) =>
      _selectionFor(ttsModelMapKey, providerId);

  Future<String?> selectedLlmModel(String providerId) =>
      _selectionFor(llmModelMapKey, providerId, legacyKey: legacyLlmModelKey);

  Future<void> setSelectedVoice(String providerId, String? voiceId) async {
    final normalized = _normalize(voiceId);
    await _setSelection(ttsVoiceMapKey, providerId, normalized);
    await _write(legacyTtsVoiceKey, normalized ?? '');
  }

  Future<void> setSelectedTtsModel(String providerId, String? modelId) =>
      _setSelection(ttsModelMapKey, providerId, _normalize(modelId));

  Future<void> setSelectedLlmModel(String providerId, String? modelId) async {
    final normalized = _normalize(modelId);
    await _setSelection(llmModelMapKey, providerId, normalized);
    await _write(legacyLlmModelKey, normalized ?? '');
  }

  Future<ProviderSelectionMigrationResult> migrateLegacySelections({
    required String? activeTtsProviderId,
    required String? activeLlmProviderId,
    required Future<bool> Function(String providerId, String voiceId)
    voiceBelongsToProvider,
    required Future<bool> Function(String providerId) llmProviderExists,
  }) async {
    final ttsResult = await migrateLegacyTtsVoice(
      activeTtsProviderId: _normalize(activeTtsProviderId),
      voiceBelongsToProvider: voiceBelongsToProvider,
    );
    final llmResult = await migrateLegacyLlmModel(
      activeLlmProviderId: _normalize(activeLlmProviderId),
      llmProviderExists: llmProviderExists,
    );
    await _write(schemaVersionKey, currentSchemaVersion);
    return ProviderSelectionMigrationResult(
      ttsVoice: ttsResult,
      llmModel: llmResult,
    );
  }

  Future<SelectionMigrationStatus> migrateLegacyTtsVoice({
    required String? activeTtsProviderId,
    required Future<bool> Function(String providerId, String voiceId)
    voiceBelongsToProvider,
  }) async {
    if (await _read(ttsVoiceMapKey) != null) {
      await _finalizeSchemaVersionIfReady();
      return SelectionMigrationStatus.alreadyMigrated;
    }
    final legacyVoiceId = _normalize(await _read(legacyTtsVoiceKey));
    if (legacyVoiceId == null) {
      await _writeMap(ttsVoiceMapKey, const {});
      await _finalizeSchemaVersionIfReady();
      return SelectionMigrationStatus.noLegacySelection;
    }
    if (activeTtsProviderId == null ||
        !await voiceBelongsToProvider(activeTtsProviderId, legacyVoiceId)) {
      await _writeMap(ttsVoiceMapKey, const {});
      await _finalizeSchemaVersionIfReady();
      return SelectionMigrationStatus.setupRequired;
    }
    await _writeMap(ttsVoiceMapKey, {activeTtsProviderId: legacyVoiceId});
    await _finalizeSchemaVersionIfReady();
    return SelectionMigrationStatus.migrated;
  }

  Future<SelectionMigrationStatus> migrateLegacyLlmModel({
    required String? activeLlmProviderId,
    required Future<bool> Function(String providerId) llmProviderExists,
  }) async {
    if (await _read(llmModelMapKey) != null) {
      await _finalizeSchemaVersionIfReady();
      return SelectionMigrationStatus.alreadyMigrated;
    }
    final legacyModelId = _normalize(await _read(legacyLlmModelKey));
    if (legacyModelId == null) {
      await _writeMap(llmModelMapKey, const {});
      await _finalizeSchemaVersionIfReady();
      return SelectionMigrationStatus.noLegacySelection;
    }
    if (activeLlmProviderId == null ||
        !await llmProviderExists(activeLlmProviderId)) {
      await _writeMap(llmModelMapKey, const {});
      await _finalizeSchemaVersionIfReady();
      return SelectionMigrationStatus.setupRequired;
    }
    await _writeMap(llmModelMapKey, {activeLlmProviderId: legacyModelId});
    await _finalizeSchemaVersionIfReady();
    return SelectionMigrationStatus.migrated;
  }

  Future<String?> _selectionFor(
    String key,
    String providerId, {
    String? legacyKey,
  }) async {
    final stored = await _read(key);
    if (stored == null && legacyKey != null) {
      return _normalize(await _read(legacyKey));
    }
    final selections = await _readMap(key);
    return _normalize(selections[providerId]);
  }

  Future<void> _setSelection(
    String key,
    String providerId,
    String? selectionId,
  ) async {
    final normalizedProviderId = _normalize(providerId);
    if (normalizedProviderId == null) {
      throw ArgumentError.value(providerId, 'providerId', 'must not be empty');
    }
    final selections = await _readMap(key);
    if (selectionId == null) {
      selections.remove(normalizedProviderId);
    } else {
      selections[normalizedProviderId] = selectionId;
    }
    await _writeMap(key, selections);
  }

  Future<Map<String, String>> _readMap(String key) async {
    final stored = await _read(key);
    if (stored == null || stored.trim().isEmpty) return {};
    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$key must contain a JSON object.');
    }
    return {
      for (final entry in decoded.entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
  }

  Future<void> _writeMap(String key, Map<String, String> value) =>
      _write(key, jsonEncode(value));

  Future<void> _finalizeSchemaVersionIfReady() async {
    if (await _read(ttsVoiceMapKey) != null &&
        await _read(llmModelMapKey) != null) {
      await _write(schemaVersionKey, currentSchemaVersion);
    }
  }

  String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
