import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../services/wav_audio_utils.dart';
import '../models/tts_capabilities.dart';
import '../models/tts_chunk.dart';
import '../models/tts_model.dart';
import '../models/tts_voice.dart';
import '../tts_provider.dart';
import 'fish_audio_api_tts_provider.dart'
    show TtsSettingReader, TtsSettingWriter;

/// GPT-SoVITS TTS Provider
///
/// 对接自建或本地部署的 GPT-SoVITS HTTP API（基于 api_v2.py）：
/// - 推理接口: POST /tts
/// - 探针校验: GET /openapi.json
/// - 默认搭载 Reverse: 1999 维尔汀 (Vertin) 英配微调模型
class GptSovitsTtsProvider
    implements TtsProvider, TtsModelCatalog, TtsGenerationConfiguration {
  static const String idValue = 'gpt_sovits';
  static const String defaultModel = 'vertin_v2_e15';
  static const String defaultEndpoint = 'http://172.26.19.56:9880';
  static const String endpointSettingKey = 'gpt_sovits_endpoint';

  final Dio _dio;
  final TtsSettingReader? settingReader;
  final TtsSettingWriter? settingWriter;
  final TtsModelSelectionReader? modelSelectionReader;
  String? _cachedEndpoint;

  GptSovitsTtsProvider({
    Dio? dio,
    this.settingReader,
    this.settingWriter,
    this.modelSelectionReader,
  }) : _dio = dio ?? Dio();

  @override
  String get id => idValue;

  @override
  String get displayName => 'GPT-SoVITS 本地模型 (Vertin)';

  @override
  TtsCapabilities get capabilities => const TtsCapabilities(
    presetVoices: true,
    voiceCloning: false,
    voiceDescription: false,
    maxCharsPerCall: 250,
    streaming: false,
    outputFormats: ['wav'],
    requiresNetwork: false,
    paid: false,
  );

  /// 读取服务地址（若未配置则使用默认值）
  Future<String> get endpoint async {
    final cached = _cachedEndpoint;
    if (cached != null) return cached;
    final stored = await settingReader?.call(endpointSettingKey);
    final clean = stored?.trim();
    final value = (clean != null && clean.isNotEmpty) ? clean : defaultEndpoint;
    _cachedEndpoint = value;
    return value;
  }

  /// 设置服务地址
  Future<void> setEndpoint(String url) async {
    final clean = url.trim();
    final normalized = clean.endsWith('/')
        ? clean.substring(0, clean.length - 1)
        : clean;
    _cachedEndpoint = normalized.isEmpty ? defaultEndpoint : normalized;
    await settingWriter?.call(endpointSettingKey, _cachedEndpoint!);
  }

  /// 重置服务地址
  Future<void> clearEndpoint() async {
    _cachedEndpoint = defaultEndpoint;
    await settingWriter?.call(endpointSettingKey, '');
  }

  static const List<TtsModel> bundledModels = [
    TtsModel(
      id: 'vertin_v2_e15',
      name: '维尔汀 (Epoch 15 原声)',
      description: '微调 15 轮，原声音色特征最明显',
      recommended: true,
    ),
    TtsModel(
      id: 'vertin_v2_e10',
      name: '维尔汀 (Epoch 10 柔和)',
      description: '微调 10 轮，语气更自然松弛、泛化性好',
    ),
  ];

  @override
  TtsModelCatalogSource get modelCatalogSource =>
      TtsModelCatalogSource.bundledFallback;

  @override
  Future<List<TtsModel>> listModels({bool refresh = false}) async {
    return bundledModels;
  }

  Future<String> get selectedModel async {
    final selected = await modelSelectionReader?.call(id);
    return (selected != null && selected.trim().isNotEmpty)
        ? selected.trim()
        : defaultModel;
  }

  @override
  Future<String> get generationConfigurationFingerprint async =>
      'model:${await selectedModel};endpoint:${await endpoint}';

  static const List<TtsVoice> presetVoices = [
    TtsVoice(
      id: 'vertin_storm',
      name: '维尔汀 (The Storm)',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: '/mnt/data/users/wuxiaolong/vertin-sovit/ref_the_storm.wav',
      presetDescription: '参考："No, it is not. It\'s the storm." (英配，沉稳冷静)',
      languages: ['en'],
      createdAt: 1710000000000,
    ),
    TtsVoice(
      id: 'vertin_gentle',
      name: '维尔汀 (Gentle / Reader)',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: '/mnt/data/users/wuxiaolong/vertin-sovit/ref_help_you.wav',
      presetDescription:
          '参考："You are a careful reader. I\'ll help you out, don\'t worry." (英配，温和关切)',
      languages: ['en'],
      createdAt: 1710000000000,
    ),
  ];

  @override
  Future<bool> validate() async {
    try {
      final base = await endpoint;
      final uri = Uri.parse('$base/openapi.json');
      final resp = await _dio.getUri(
        uri,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 3),
        ),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<TtsVoice>> listPresetVoices() async {
    return presetVoices;
  }

  @override
  Future<TtsVoice> cloneVoice({
    required Uint8List audioBytes,
    required String format,
    required String name,
    String? samplePath,
  }) {
    throw UnsupportedError('GPT-SoVITS Provider 暂不支持在线即时克隆');
  }

  @override
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  }) {
    throw UnsupportedError('GPT-SoVITS Provider 暂不支持描述生成音色');
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

    final base = await endpoint;
    final uri = Uri.parse('$base/tts');

    // 针对音色自动配置参考音频与参考文本
    final String refAudioPath;
    final String promptText;
    final String promptLang = 'en';

    if (voice.id == 'vertin_gentle' ||
        voice.providerVoiceId.contains('ref_help_you') ||
        voice.providerVoiceId.contains('help_you')) {
      refAudioPath = voice.providerVoiceId.isNotEmpty
          ? voice.providerVoiceId
          : '/mnt/data/users/wuxiaolong/vertin-sovit/ref_help_you.wav';
      promptText =
          "You are a careful reader. I'll help you out, don't worry.";
    } else {
      refAudioPath = voice.providerVoiceId.isNotEmpty
          ? voice.providerVoiceId
          : '/mnt/data/users/wuxiaolong/vertin-sovit/ref_the_storm.wav';
      promptText = "No, it is not. It's the storm.";
    }

    final modelId = await selectedModel;
    await _ensureModelWeights(base, modelId);

    // 语言判断：若包含汉字则走 zh，否则走 en
    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    final textLang = hasChinese ? 'zh' : 'en';

    // 句子级切分方式：英文用 cut4（句号切分），中文用 cut3，避免逗号切分导致语流破碎一顿一顿
    final splitMethod = textLang == 'en' ? 'cut4' : 'cut3';

    final requestBody = <String, dynamic>{
      'text': text,
      'text_lang': textLang,
      'ref_audio_path': refAudioPath,
      'prompt_text': promptText,
      'prompt_lang': promptLang,
      'text_split_method': splitMethod,
      'top_k': 8,
      'top_p': 0.85,
      'temperature': 0.75,
      'fragment_interval': 0.25,
      'speed_factor': speed.clamp(0.5, 2.0),
      'media_type': 'wav',
    };

    try {
      final response = await _dio.postUri<List<int>>(
        uri,
        data: requestBody,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      final rawBytes = response.data;
      if (rawBytes == null || rawBytes.isEmpty) {
        throw const GptSovitsProviderException('GPT-SoVITS 返回了空音频响应');
      }

      final audioBytes = Uint8List.fromList(rawBytes);
      final cleanWav = sanitizeWavHeader(audioBytes);
      final durationMs = wavDurationMs(cleanWav);

      return TtsChunk(
        audioBytes: cleanWav,
        durationMs: durationMs,
        format: 'wav',
        sampleRate: 32000,
      );
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      final isTimeout =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      throw GptSovitsProviderException(
        'GPT-SoVITS 合成失败: $message',
        statusCode: e.response?.statusCode,
        retryable: isTimeout,
      );
    } catch (e) {
      if (e is GptSovitsProviderException) rethrow;
      throw GptSovitsProviderException('GPT-SoVITS 合成异常: $e');
    }
  }

  String? _currentLoadedModel;

  static const Map<String, String> _modelWeightsMap = {
    'vertin_v2_e15':
        '/mnt/data/users/wuxiaolong/vertin-sovit/GPT-SoVITS/GPT_weights_v2/vertin-e15.ckpt',
    'vertin_v2_e10':
        '/mnt/data/users/wuxiaolong/vertin-sovit/GPT-SoVITS/GPT_weights_v2/vertin-e10.ckpt',
  };

  Future<void> _ensureModelWeights(String base, String modelId) async {
    if (_currentLoadedModel == modelId) return;
    final path = _modelWeightsMap[modelId];
    if (path == null) return;
    try {
      final uri = Uri.parse('$base/set_gpt_weights').replace(
        queryParameters: {'weights_path': path},
      );
      final resp = await _dio.getUri(
        uri,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      if (resp.statusCode == 200) {
        _currentLoadedModel = modelId;
      }
    } catch (_) {
      // 切换失败时保持现状，降级使用当前加载的模型
    }
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      return (data['Exception'] ?? data['message'] ?? data['detail'] ?? error.message)
          .toString();
    }
    if (data is List<int>) {
      try {
        final decoded = utf8.decode(data);
        final map = jsonDecode(decoded) as Map?;
        if (map != null) {
          return (map['Exception'] ?? map['message'] ?? map['detail'] ?? decoded)
              .toString();
        }
        return decoded;
      } catch (_) {}
    }
    return error.message ?? '未知网络错误';
  }
}

class GptSovitsProviderException implements TtsProviderException {
  final String message;
  final int? statusCode;
  final bool retryable;

  const GptSovitsProviderException(
    this.message, {
    this.statusCode,
    this.retryable = false,
  });

  @override
  bool get isRetryable => retryable;

  @override
  bool get shouldStopGeneration => !retryable;

  @override
  String toString() => 'GptSovitsProviderException: $message';
}
