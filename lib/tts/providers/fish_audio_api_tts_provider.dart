import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domain/models/audio_text_timing.dart';
import '../../services/wav_audio_utils.dart';
import '../api_key_store.dart';
import '../models/tts_capabilities.dart';
import '../models/tts_chunk.dart';
import '../models/tts_model.dart';
import '../models/tts_voice.dart';
import '../tts_provider.dart';

typedef TtsSettingReader = Future<String?> Function(String key);
typedef TtsSettingWriter = Future<void> Function(String key, String value);

enum FishAudioGenerationProfile {
  fast(
    value: 'fast',
    label: '快速',
    latency: 'low',
    sampleRate: 24000,
    concurrency: 3,
  ),
  quality(
    value: 'quality',
    label: '高质量',
    latency: 'balanced',
    sampleRate: 44100,
    concurrency: 1,
  );

  final String value;
  final String label;
  final String latency;
  final int sampleRate;
  final int concurrency;

  const FishAudioGenerationProfile({
    required this.value,
    required this.label,
    required this.latency,
    required this.sampleRate,
    required this.concurrency,
  });

  static FishAudioGenerationProfile parse(String? value) {
    for (final profile in values) {
      if (profile.value == value) return profile;
    }
    return fast;
  }
}

/// Fish Audio 云端 API Provider。
///
/// 使用 raw REST API，适配 Flutter/Dart 环境。API Key 存在系统安全存储中。
class FishAudioApiTtsProvider
    implements
        TtsProvider,
        TtsConcurrencyPolicy,
        TtsModelCatalog,
        TtsGenerationConfiguration {
  static const String idValue = 'fish_audio_api';
  static const String defaultModel = 's2-pro';
  static const String _baseUrl = 'https://api.fish.audio';
  static const String _storageKey = 'fish_audio_api_key';
  static const String _defaultVoiceId = 'fish_api_default';
  static const String generationProfileSettingKey =
      'fish_audio_generation_profile';

  final Dio _dio;
  final ApiKeyStore _apiKeyStore;
  final TtsSettingReader? settingReader;
  final TtsSettingWriter? settingWriter;
  final TtsModelSelectionReader? modelSelectionReader;
  FishAudioGenerationProfile? _cachedGenerationProfile;
  List<TtsModel>? _cachedModels;
  TtsModelCatalogSource _modelCatalogSource =
      TtsModelCatalogSource.bundledFallback;

  FishAudioApiTtsProvider({
    Dio? dio,
    ApiKeyStore? apiKeyStore,
    this.settingReader,
    this.settingWriter,
    this.modelSelectionReader,
  }) : _dio = dio ?? Dio(),
       _apiKeyStore = apiKeyStore ?? ApiKeyStore();

  @override
  String get id => idValue;

  @override
  String get displayName => 'Fish Audio API';

  @override
  TtsCapabilities get capabilities => const TtsCapabilities(
    presetVoices: true,
    voiceCloning: true,
    voiceDescription: false,
    maxCharsPerCall: 4000,
    streaming: true,
    outputFormats: ['wav', 'mp3', 'pcm', 'opus'],
    requiresNetwork: true,
    paid: false,
    cloneConstraints: VoiceCloneConstraints(
      allowedFormats: ['mp3', 'm4a', 'wav', 'aac', 'flac'],
      minDurationSeconds: 10,
      maxDurationSeconds: 300,
      maxSizeBytes: 50 * 1024 * 1024,
    ),
  );

  Future<FishAudioGenerationProfile> get generationProfile async {
    final cached = _cachedGenerationProfile;
    if (cached != null) return cached;
    final profile = FishAudioGenerationProfile.parse(
      await settingReader?.call(generationProfileSettingKey),
    );
    _cachedGenerationProfile = profile;
    return profile;
  }

  Future<void> setGenerationProfile(FishAudioGenerationProfile profile) async {
    _cachedGenerationProfile = profile;
    await settingWriter?.call(generationProfileSettingKey, profile.value);
  }

  @override
  Future<int> get generationConcurrency async =>
      (await generationProfile).concurrency;

  Future<String?> get apiKey => _apiKeyStore.read(_storageKey);

  Future<void> setApiKey(String key) =>
      _apiKeyStore.write(_storageKey, key.trim());

  Future<void> clearApiKey() => _apiKeyStore.delete(_storageKey);

  static const List<TtsModel> bundledModels = [
    TtsModel(
      id: 's2.1-pro',
      name: 'Fish Audio S2.1-Pro',
      description: 'S2.1 Pro production model',
      recommended: true,
    ),
    TtsModel(
      id: 's2.1-pro-free',
      name: 'Fish Audio S2.1-Pro Free',
      description: 'Free developer-tier version of S2.1 Pro',
    ),
    TtsModel(
      id: 's2-pro',
      name: 'Fish Audio S2-Pro',
      description: '最新高质量模型，支持 80+ 语言与自然语言情绪控制',
    ),
    TtsModel(
      id: 's1',
      name: 'Fish Audio S1',
      description: '上一代稳定模型，支持 13 种语言与情绪标签',
    ),
  ];

  @override
  TtsModelCatalogSource get modelCatalogSource => _modelCatalogSource;

  @override
  Future<List<TtsModel>> listModels({bool refresh = false}) async {
    if (!refresh) return _cachedModels ?? bundledModels;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/openapi.json',
      );
      final paths = response.data?['paths'] as Map<String, dynamic>?;
      final ttsPath = paths?['/v1/tts'] as Map<String, dynamic>?;
      final post = ttsPath?['post'] as Map<String, dynamic>?;
      final parameters = post?['parameters'] as List<dynamic>? ?? const [];
      final modelParameter = parameters.whereType<Map<String, dynamic>>().where(
        (item) => item['name'] == 'model' && item['in'] == 'header',
      );
      final schema = modelParameter.isEmpty
          ? null
          : modelParameter.first['schema'] as Map<String, dynamic>?;
      final ids = (schema?['enum'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      if (ids.isEmpty) {
        _cachedModels ??= bundledModels;
        _modelCatalogSource = TtsModelCatalogSource.bundledFallback;
      } else {
        _cachedModels = _modelsFromIds(ids, bundledModels);
        _modelCatalogSource = TtsModelCatalogSource.officialApi;
      }
    } catch (_) {
      if (_cachedModels == null) {
        _cachedModels = bundledModels;
        _modelCatalogSource = TtsModelCatalogSource.bundledFallback;
      } else {
        _modelCatalogSource = TtsModelCatalogSource.cachedAfterSyncFailure;
      }
    }
    return _cachedModels!;
  }

  Future<String> get selectedModel async {
    final selected = await modelSelectionReader?.call(id);
    return selected?.trim().isNotEmpty == true
        ? selected!.trim()
        : defaultModel;
  }

  @override
  Future<String> get generationConfigurationFingerprint async =>
      'model:${await selectedModel};profile:${(await generationProfile).value}';

  @override
  Future<bool> validate() async {
    final key = await apiKey;
    if (key == null || key.isEmpty) return false;
    try {
      await _dio.get(
        '$_baseUrl/wallet/self/api-credit',
        options: Options(headers: _headers(key)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<TtsVoice>> listPresetVoices() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaultVoice = TtsVoice(
      id: _defaultVoiceId,
      name: 'Fish Audio Default',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: '',
      presetDescription: '不指定 reference_id，使用 Fish Audio 默认声音',
      createdAt: now,
    );

    final key = await apiKey;
    if (key == null || key.isEmpty) return [defaultVoice];

    try {
      final resp = await _dio.get(
        '$_baseUrl/model',
        queryParameters: {
          'page_size': 50,
          'page_number': 1,
          'self': true,
          'sort_by': 'created_at',
        },
        options: Options(headers: _headers(key)),
      );
      final data = resp.data as Map<String, dynamic>;
      final items = data['items'] as List? ?? const [];
      final voices = items
          .map((item) => _voiceFromModel(item as Map<String, dynamic>))
          .whereType<TtsVoice>()
          .toList();
      return [defaultVoice, ...voices];
    } catch (_) {
      return [defaultVoice];
    }
  }

  @override
  Future<TtsVoice> cloneVoice({
    required Uint8List audioBytes,
    required String format,
    required String name,
    String? samplePath,
  }) async {
    final key = await apiKey;
    if (key == null || key.isEmpty) throw StateError('Fish Audio API Key 未配置');

    final safeFormat = format.replaceFirst('.', '').toLowerCase();
    final formData = FormData.fromMap({
      'type': 'tts',
      'train_mode': 'fast',
      'title': name,
      'visibility': 'private',
      'voices': MultipartFile.fromBytes(
        audioBytes,
        filename: 'voice_sample.$safeFormat',
      ),
      'tags': ['lumina', 'audiobook'],
      'enhance_audio_quality': false,
    });

    final resp = await _dio.post(
      '$_baseUrl/model',
      data: formData,
      options: Options(headers: _headers(key)),
    );
    final modelData = resp.data as Map<String, dynamic>;
    final voice = _voiceFromModel(modelData);
    if (voice == null) {
      throw StateError('Fish Audio 创建音色成功但没有返回模型 id');
    }
    return voice.copyWith(
      name: name,
      samplePath: samplePath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  }) {
    throw UnsupportedError('Fish Audio API Provider 暂不支持把描述生成结果保存为可复用音色');
  }

  @override
  Future<TtsChunk> synthesize({
    required String text,
    required TtsVoice voice,
    double speed = 1.0,
  }) async {
    if (voice.providerId != id) {
      throw ArgumentError(
        '音色 ${voice.name} 属于 ${voice.providerId}，不能用于 $displayName',
      );
    }
    final key = await apiKey;
    if (key == null || key.isEmpty) throw StateError('Fish Audio API Key 未配置');
    final profile = await generationProfile;
    final modelId = await selectedModel;

    final body = <String, dynamic>{
      'text': text,
      if (voice.providerVoiceId.trim().isNotEmpty)
        'reference_id': voice.providerVoiceId.trim(),
      'format': 'wav',
      'sample_rate': profile.sampleRate,
      'latency': profile.latency,
      'chunk_length': 300,
      'min_chunk_length': 50,
      'normalize': true,
      'prosody': {'speed': speed.clamp(0.5, 2.0)},
    };

    FishTimestampSynthesisResult result;
    try {
      result = await _synthesizeWithTimestamps(
        key: key,
        modelId: modelId,
        body: body,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != 404 && statusCode != 405 && statusCode != 422) rethrow;
      result = await _synthesizeWithoutTimestamps(
        key: key,
        modelId: modelId,
        body: body,
      );
    }

    final bytes = result.audioBytes;
    if (bytes.isEmpty) throw StateError('Fish Audio 返回空音频');

    final durationMs = wavDurationMs(bytes);

    return TtsChunk(
      audioBytes: bytes,
      durationMs: durationMs > 0 ? durationMs : result.alignedDurationMs,
      format: 'wav',
      billedCharacters: utf8.encode(text).length,
      sampleRate: _wavSampleRate(bytes),
      timings: result.timings,
    );
  }

  Future<FishTimestampSynthesisResult> _synthesizeWithTimestamps({
    required String key,
    required String modelId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<ResponseBody>(
      '$_baseUrl/v1/tts/stream/with-timestamp',
      data: jsonEncode(body),
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          ..._headers(key),
          'Content-Type': 'application/json',
          'model': modelId,
        },
      ),
    );
    final responseBody = response.data;
    if (responseBody == null) throw StateError('Fish Audio 返回空 SSE 响应');

    final accumulator = FishTimestampSseAccumulator();
    final dataLines = <String>[];
    final lines = responseBody.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          accumulator.addPayload(dataLines.join('\n'));
          dataLines.clear();
        }
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isNotEmpty) {
      accumulator.addPayload(dataLines.join('\n'));
    }
    return accumulator.finish();
  }

  Future<FishTimestampSynthesisResult> _synthesizeWithoutTimestamps({
    required String key,
    required String modelId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<List<int>>(
      '$_baseUrl/v1/tts',
      data: jsonEncode(body),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          ..._headers(key),
          'Content-Type': 'application/json',
          'model': modelId,
        },
      ),
    );
    return FishTimestampSynthesisResult(
      audioBytes: Uint8List.fromList(response.data ?? const []),
      timings: const [],
    );
  }

  Map<String, String> _headers(String apiKey) => {
    'Authorization': 'Bearer $apiKey',
  };

  List<TtsModel> _modelsFromIds(
    List<String> discovered,
    List<TtsModel> bundled,
  ) {
    final metadata = {for (final model in bundled) model.id: model};
    final seen = <String>{};
    final result = <TtsModel>[];
    for (final id in discovered) {
      if (!seen.add(id)) continue;
      result.add(
        metadata[id] ??
            TtsModel(
              id: id,
              name: id,
              description: 'Fish Audio TTS model from the official API schema',
            ),
      );
    }
    return result;
  }

  TtsVoice? _voiceFromModel(Map<String, dynamic> model) {
    if (model['type'] != null && model['type'] != 'tts') return null;
    final modelId = model['_id'] as String? ?? model['id'] as String?;
    if (modelId == null || modelId.isEmpty) return null;
    final title = model['title'] as String? ?? modelId;
    final description = model['description'] as String?;
    final state = model['state'] as String?;
    final coverUrl = _nonEmptyString(model['cover_image']);
    final samples = model['samples'] as List<dynamic>? ?? const [];
    String? previewUrl;
    for (final sample in samples.whereType<Map>()) {
      previewUrl =
          _nonEmptyString(sample['audio']) ??
          _nonEmptyString(sample['audio_url']) ??
          _nonEmptyString(sample['url']);
      if (previewUrl != null) break;
    }
    final languages = _languagesFromModel(model);
    final quality = model['quality'] as Map?;
    final qualityAudios = quality?['audios'] as List<dynamic>? ?? const [];
    final sampleCount = samples.length >= qualityAudios.length
        ? samples.length
        : qualityAudios.length;
    final createdAt = DateTime.tryParse(model['created_at'] as String? ?? '');
    return TtsVoice(
      id: '${idValue}_model_$modelId',
      name: state == null || state == 'trained' ? title : '$title ($state)',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: modelId,
      presetDescription: description ?? 'Fish Audio voice model',
      previewUrl: previewUrl,
      coverUrl: coverUrl,
      languages: languages,
      sampleCount: sampleCount,
      createdAt:
          createdAt?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  String? _nonEmptyString(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  List<String> _languagesFromModel(Map<String, dynamic> model) {
    final explicit = (model['languages'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    if (explicit.isNotEmpty) return explicit;

    final tags = (model['tags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((value) => value.trim().toLowerCase());
    const aliases = <String, String>{
      'american': 'en-US',
      'british': 'en-GB',
      'english': 'en',
      'chinese': 'zh',
      'mandarin': 'zh',
      'japanese': 'ja',
      'korean': 'ko',
      'french': 'fr',
      'german': 'de',
      'spanish': 'es',
    };
    final result = <String>[];
    for (final tag in tags) {
      String? language;
      if (RegExp(r'^[a-z]{2}(-[a-z]{2})?$').hasMatch(tag)) {
        language = tag;
      } else {
        for (final entry in aliases.entries) {
          if (tag.contains(entry.key)) {
            language = entry.value;
            break;
          }
        }
      }
      if (language != null && !result.contains(language)) result.add(language);
    }
    return result;
  }

  int? _wavSampleRate(Uint8List bytes) {
    if (bytes.length < 28) return null;
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;
    return ByteData.sublistView(bytes).getUint32(24, Endian.little);
  }
}

class FishTimestampSynthesisResult {
  final Uint8List audioBytes;
  final List<AudioTextTiming> timings;

  const FishTimestampSynthesisResult({
    required this.audioBytes,
    required this.timings,
  });

  int get alignedDurationMs => timings.isEmpty ? 0 : timings.last.endMs;
}

class FishTimestampSseAccumulator {
  final BytesBuilder _audio = BytesBuilder(copy: false);
  final Map<int, _FishAlignmentSnapshot> _alignments = {};

  void addPayload(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return;
    final event = Map<String, dynamic>.from(decoded);

    final audio = event['audio_base64'] as String?;
    if (audio != null && audio.isNotEmpty) {
      _audio.add(base64Decode(audio));
    }

    final sequence = (event['chunk_seq'] as num?)?.toInt();
    final alignment = event['alignment'];
    if (sequence == null || alignment is! Map) return;
    final alignmentMap = Map<String, dynamic>.from(alignment);
    final rawSegments = alignmentMap['segments'];
    if (rawSegments is! List) return;

    final offsetSeconds =
        (event['chunk_audio_offset_sec'] as num?)?.toDouble() ?? 0;
    final timings = rawSegments
        .whereType<Map>()
        .map((raw) {
          final segment = Map<String, dynamic>.from(raw);
          final startSeconds = (segment['start'] as num?)?.toDouble() ?? 0;
          final endSeconds =
              (segment['end'] as num?)?.toDouble() ?? startSeconds;
          return AudioTextTiming(
            text: segment['text'] as String? ?? '',
            startMs: ((offsetSeconds + startSeconds) * 1000).round(),
            endMs: ((offsetSeconds + endSeconds) * 1000).round(),
          );
        })
        .where((timing) => timing.text.isNotEmpty)
        .toList(growable: false);

    _alignments[sequence] = _FishAlignmentSnapshot(
      sequence: sequence,
      timings: timings,
    );
  }

  FishTimestampSynthesisResult finish() {
    final snapshots = _alignments.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final timings = snapshots
        .expand((snapshot) => snapshot.timings)
        .toList(growable: false);
    return FishTimestampSynthesisResult(
      audioBytes: _audio.takeBytes(),
      timings: timings,
    );
  }
}

class _FishAlignmentSnapshot {
  final int sequence;
  final List<AudioTextTiming> timings;

  const _FishAlignmentSnapshot({required this.sequence, required this.timings});
}
