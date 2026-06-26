import 'dart:typed_data';

import 'package:edge_tts/edge_tts.dart' as edge;

import '../models/tts_capabilities.dart';
import '../models/tts_chunk.dart';
import '../models/tts_voice.dart';
import '../tts_provider.dart';

/// Edge TTS 保底 Provider（免费、无需 API Key）。
///
/// Edge TTS 是微软 Edge 浏览器"朗读"功能的接口，非官方公开 API，
/// 但稳定且免费，适合作为基础体验保底。
///
/// 能力：presetVoices ✅ | voiceCloning ❌ | voiceDescription ❌
/// 实现：通过 WSS 构造 SSML 请求，返回 MP3 流。
///
/// 注意：Edge TTS 无官方时长返回，需本地解码 MP3 帧估算时长。
class EdgeTtsProvider implements TtsProvider {
  static const String idValue = 'edge';

  EdgeTtsProvider();

  @override
  String get id => idValue;

  @override
  String get displayName => 'Edge TTS（免费保底）';

  @override
  TtsCapabilities get capabilities => const TtsCapabilities(
    presetVoices: true,
    voiceCloning: false,
    voiceDescription: false,
    maxCharsPerCall: 5000,
    streaming: false,
    outputFormats: ['mp3'],
    requiresNetwork: true,
    paid: false,
  );

  /// 常用中文音色子集（Edge TTS 有上百个音色，这里列常用的）。
  static const _presetVoices = <TtsVoice>[
    TtsVoice(
      id: 'edge_preset_xiaoxiao',
      name: '晓晓（女·温柔）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'zh-CN-XiaoxiaoNeural',
      presetDescription: '温柔女声，适合文学朗读',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'edge_preset_yunxi',
      name: '云希（男·沉稳）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'zh-CN-YunxiNeural',
      presetDescription: '沉稳男声，适合叙事',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'edge_preset_yunyang',
      name: '云扬（男·新闻）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'zh-CN-YunyangNeural',
      presetDescription: '专业新闻男声',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'edge_preset_xiaoyi',
      name: '晓伊（女·活泼）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'zh-CN-XiaoyiNeural',
      presetDescription: '活泼女声，适合轻松内容',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'edge_preset_yunjian',
      name: '云健（男·体育）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'zh-CN-YunjianNeural',
      presetDescription: '体育解说男声',
      createdAt: 0,
    ),
  ];

  @override
  Future<bool> validate() async => true; // 无需配置

  @override
  Future<List<TtsVoice>> listPresetVoices() async => _presetVoices;

  @override
  Future<TtsVoice> cloneVoice({
    required Uint8List audioBytes,
    required String format,
    required String name,
    String? samplePath,
  }) {
    throw UnsupportedError('Edge TTS 不支持音色克隆');
  }

  @override
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  }) {
    throw UnsupportedError('Edge TTS 不支持文字描述生成音色');
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

    final ratePercent = ((speed - 1.0) * 100).round().clamp(-50, 100);
    final rateStr = ratePercent >= 0 ? '+$ratePercent%' : '$ratePercent%';

    final communicator = edge.Communicate(
      text: text,
      voice: voice.providerVoiceId,
      rate: rateStr,
    );
    final bytes = await communicator.toBytes();

    return TtsChunk(
      audioBytes: bytes,
      durationMs: _estimateMp3DurationMs(bytes),
      format: 'mp3',
      billedCharacters: null,
      sampleRate: null,
    );
  }

  /// Edge TTS 不返回最终音频时长。这里按 128kbps MP3 估算，
  /// 用于 manifest 初始偏移。实际播放时 just_audio 会以音频本身为准。
  int _estimateMp3DurationMs(Uint8List bytes) {
    const bitrateBitsPerSecond = 128000;
    return ((bytes.length * 8 / bitrateBitsPerSecond) * 1000).round();
  }
}
