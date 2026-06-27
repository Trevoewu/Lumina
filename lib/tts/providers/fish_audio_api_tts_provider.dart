import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api_key_store.dart';
import '../models/tts_capabilities.dart';
import '../models/tts_chunk.dart';
import '../models/tts_voice.dart';
import '../tts_provider.dart';

/// Fish Audio 云端 API Provider。
///
/// 使用 raw REST API，适配 Flutter/Dart 环境。TTS 模型固定为
/// s2.1-pro-free，便于开发和测试；API Key 存在系统安全存储中。
class FishAudioApiTtsProvider implements TtsProvider {
  static const String idValue = 'fish_audio_api';
  static const String model = 's2.1-pro-free';
  static const String _baseUrl = 'https://api.fish.audio';
  static const String _storageKey = 'fish_audio_api_key';
  static const String _defaultVoiceId = 'fish_api_default';

  final Dio _dio;
  final ApiKeyStore _apiKeyStore;

  FishAudioApiTtsProvider({Dio? dio, ApiKeyStore? apiKeyStore})
    : _dio = dio ?? Dio(),
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
    maxCharsPerCall: 9000,
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

  Future<String?> get apiKey => _apiKeyStore.read(_storageKey);

  Future<void> setApiKey(String key) =>
      _apiKeyStore.write(_storageKey, key.trim());

  Future<void> clearApiKey() => _apiKeyStore.delete(_storageKey);

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

    final body = <String, dynamic>{
      'text': text,
      if (voice.providerVoiceId.trim().isNotEmpty)
        'reference_id': voice.providerVoiceId.trim(),
      'format': 'wav',
      'sample_rate': 44100,
      'latency': 'balanced',
      'chunk_length': 300,
      'min_chunk_length': 50,
      'normalize': true,
      'prosody': {'speed': speed.clamp(0.5, 2.0)},
    };

    final resp = await _dio.post<List<int>>(
      '$_baseUrl/v1/tts',
      data: jsonEncode(body),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          ..._headers(key),
          'Content-Type': 'application/json',
          'model': model,
        },
      ),
    );
    final bytes = Uint8List.fromList(resp.data ?? const []);
    if (bytes.isEmpty) throw StateError('Fish Audio 返回空音频');

    return TtsChunk(
      audioBytes: bytes,
      durationMs: _wavDurationMs(bytes),
      format: 'wav',
      billedCharacters: utf8.encode(text).length,
      sampleRate: _wavSampleRate(bytes),
    );
  }

  Map<String, String> _headers(String apiKey) => {
    'Authorization': 'Bearer $apiKey',
  };

  TtsVoice? _voiceFromModel(Map<String, dynamic> model) {
    final modelId = model['_id'] as String? ?? model['id'] as String?;
    if (modelId == null || modelId.isEmpty) return null;
    final title = model['title'] as String? ?? modelId;
    final description = model['description'] as String?;
    final state = model['state'] as String?;
    return TtsVoice(
      id: '${idValue}_model_$modelId',
      name: state == null || state == 'trained' ? title : '$title ($state)',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: modelId,
      presetDescription: description ?? 'Fish Audio voice model',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  int? _wavSampleRate(Uint8List bytes) {
    if (bytes.length < 28) return null;
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return null;
    return ByteData.sublistView(bytes).getUint32(24, Endian.little);
  }

  int _wavDurationMs(Uint8List bytes) {
    if (bytes.length < 44) return 0;
    final data = ByteData.sublistView(bytes);
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return 0;
    if (String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') return 0;

    final byteRate = data.getUint32(28, Endian.little);
    if (byteRate <= 0) return 0;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      if (chunkId == 'data') {
        return ((chunkSize / byteRate) * 1000).round();
      }
      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset += 1;
    }
    return 0;
  }
}
