import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/tts_capabilities.dart';
import '../models/tts_chunk.dart';
import '../models/tts_voice.dart';
import '../tts_provider.dart';

/// MiniMax TTS Provider。
///
/// 对接 MiniMax 开放平台：
/// - 同步语音合成 T2A V2: POST /v1/t2a_v2
/// - 音色快速复刻:        POST /v1/voice_clone
/// - 音色设计（文生音色）: POST /v1/voice_design
/// - 查询可用音色:        POST /v1/get_voice
/// - 文件上传:            POST /v1/files/upload （用于复刻音频）
///
/// 能力：presetVoices ✅ | voiceCloning ✅ | voiceDescription ✅
/// 计费：按字符计费（paid = true）。
class MinimaxTtsProvider implements TtsProvider {
  static const String idValue = 'minimax';

  static const String _baseUrl = 'https://api.minimaxi.com';
  static const String _storageKey = 'minimax_api_key';

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  MinimaxTtsProvider({Dio? dio, FlutterSecureStorage? storage})
    : _dio = dio ?? Dio(),
      _secureStorage = storage ?? const FlutterSecureStorage();

  @override
  String get id => idValue;

  @override
  String get displayName => 'MiniMax 语音合成';

  @override
  TtsCapabilities get capabilities => const TtsCapabilities(
    presetVoices: true,
    voiceCloning: true,
    voiceDescription: true,
    maxCharsPerCall: 10000,
    streaming: true,
    outputFormats: ['mp3', 'pcm', 'flac', 'wav'],
    requiresNetwork: true,
    paid: true,
    cloneConstraints: VoiceCloneConstraints(
      allowedFormats: ['mp3', 'm4a', 'wav'],
      minDurationSeconds: 10,
      maxDurationSeconds: 300,
      maxSizeBytes: 20 * 1024 * 1024,
    ),
    maxDescriptionLength: 500,
  );

  // ── 配置 ──

  Future<String?> get apiKey => _secureStorage.read(key: _storageKey);

  Future<void> setApiKey(String key) =>
      _secureStorage.write(key: _storageKey, value: key);

  Future<void> clearApiKey() => _secureStorage.delete(key: _storageKey);

  @override
  Future<bool> validate() async {
    final key = await apiKey;
    if (key == null || key.isEmpty) return false;
    try {
      // 用 get_voice 接口探活
      await _post('/v1/get_voice', {'voice_type': 'system'}, key);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── 音色 ──

  @override
  Future<List<TtsVoice>> listPresetVoices() async {
    final key = await apiKey;
    if (key == null) return [];

    final resp = await _post('/v1/get_voice', {'voice_type': 'all'}, key);
    final data = resp['system_voice'] as List? ?? [];

    final now = DateTime.now().millisecondsSinceEpoch;
    return data.map((v) {
      final m = v as Map<String, dynamic>;
      final vid = m['voice_id'] as String;
      final descs = m['description'] as List? ?? [];
      return TtsVoice(
        id: '${idValue}_preset_$vid',
        name: m['voice_name'] as String? ?? vid,
        providerId: idValue,
        type: VoiceType.preset,
        providerVoiceId: vid,
        presetDescription: descs.isNotEmpty ? descs.join('\n') : null,
        createdAt: now,
      );
    }).toList();
  }

  @override
  Future<TtsVoice> cloneVoice({
    required Uint8List audioBytes,
    required String format,
    required String name,
    String? samplePath,
  }) async {
    final key = await apiKey;
    if (key == null) throw StateError('MiniMax API Key 未配置');

    // 1. 上传音频文件
    final fileId = await _uploadFile(
      audioBytes,
      format,
      'voice_clone_sample.$format',
      key,
    );

    // 2. 调用复刻接口
    final voiceId = 'clone_${DateTime.now().millisecondsSinceEpoch}';
    final body = <String, dynamic>{
      'file_id': fileId,
      'voice_id': voiceId,
      'need_noise_reduction': true,
      'need_volume_normalization': true,
    };

    final resp = await _post('/v1/voice_clone', body, key);
    _checkStatus(resp, context: '音色复刻');

    final demoAudio = resp['demo_audio'] as String?;

    return TtsVoice(
      id: '${idValue}_clone_$voiceId',
      name: name,
      providerId: idValue,
      type: VoiceType.clone,
      providerVoiceId: voiceId,
      samplePath: samplePath,
      previewUrl: demoAudio,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  }) async {
    final key = await apiKey;
    if (key == null) throw StateError('MiniMax API Key 未配置');

    final body = {
      'prompt': description,
      'preview_text': '这是一段试听文本，用于展示生成音色的效果。',
    };

    final resp = await _post('/v1/voice_design', body, key);
    _checkStatus(resp, context: '音色设计');

    final voiceId = resp['voice_id'] as String;
    final trialAudio = resp['trial_audio'] as String?;

    return TtsVoice(
      id: '${idValue}_desc_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      providerId: idValue,
      type: VoiceType.description,
      providerVoiceId: voiceId,
      description: description,
      previewUrl: trialAudio,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── 合成 ──

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
    if (key == null) throw StateError('MiniMax API Key 未配置');

    final body = {
      'model': 'speech-2.8-hd',
      'text': text,
      'stream': false,
      'voice_setting': {
        'voice_id': voice.providerVoiceId,
        'speed': speed.clamp(0.5, 2.0),
        'vol': 1.0,
        'pitch': 0,
      },
      'audio_setting': {
        'sample_rate': 32000,
        'bitrate': 128000,
        'format': 'mp3',
        'channel': 1,
      },
      'language_boost': 'auto',
      'output_format': 'hex',
    };

    final resp = await _post('/v1/t2a_v2', body, key);
    _checkStatus(resp, context: '语音合成');

    final data = resp['data'] as Map<String, dynamic>?;
    if (data == null) throw StateError('MiniMax 返回 data 为空');

    final audioHex = data['audio'] as String;
    final audioBytes = _hexDecode(audioHex);

    final extra = resp['extra_info'] as Map<String, dynamic>?;

    return TtsChunk(
      audioBytes: audioBytes,
      durationMs: (extra?['audio_length'] as num?)?.toInt() ?? 0,
      format: (extra?['audio_format'] as String?) ?? 'mp3',
      billedCharacters: (extra?['usage_characters'] as num?)?.toInt(),
      sampleRate: (extra?['audio_sample_rate'] as num?)?.toInt(),
    );
  }

  // ── 内部工具 ──

  Future<int> _uploadFile(
    Uint8List bytes,
    String format,
    String filename,
    String apiKey,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'purpose': 'voice_clone',
    });
    final resp = await _dio.post(
      '$_baseUrl/v1/files/upload',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );
    final data = resp.data['file'] as Map<String, dynamic>;
    return (data['file_id'] as num).toInt();
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
    String apiKey,
  ) async {
    final resp = await _dio.post(
      '$_baseUrl$path',
      data: jsonEncode(body),
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );
    return resp.data as Map<String, dynamic>;
  }

  void _checkStatus(Map<String, dynamic> resp, {required String context}) {
    final base = resp['base_resp'] as Map<String, dynamic>?;
    final code = base?['status_code'] as int? ?? -1;
    if (code != 0) {
      final msg = base?['status_msg'] as String? ?? '未知错误';
      throw MinimaxApiException(code: code, message: msg, context: context);
    }
  }

  Uint8List _hexDecode(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}

/// MiniMax API 错误。
class MinimaxApiException implements Exception {
  final int code;
  final String message;
  final String context;

  const MinimaxApiException({
    required this.code,
    required this.message,
    required this.context,
  });

  @override
  String toString() => 'MiniMax $context 失败 [$code]: $message';
}
