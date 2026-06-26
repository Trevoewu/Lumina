import 'dart:typed_data';

import 'models/tts_capabilities.dart';
import 'models/tts_chunk.dart';
import 'models/tts_voice.dart';

/// TTS Provider 抽象层。
///
/// 每个 Provider 实现此接口。能力通过 [capabilities] 声明，
/// UI 根据能力动态显隐入口。不支持的方法应抛出 [UnsupportedError]。
abstract class TtsProvider {
  /// Provider 唯一标识（如 'minimax', 'edge'）。
  String get id;

  /// 用户可读名称（如 'MiniMax 语音合成'）。
  String get displayName;

  /// 该 Provider 的能力声明。
  TtsCapabilities get capabilities;

  /// 校验配置是否有效（如 API Key 是否已设置）。
  /// 返回 true 表示已就绪，false 表示未配置。
  Future<bool> validate();

  /// 获取预置音色列表。
  /// 仅当 [capabilities.presetVoices] 为 true 时有效。
  Future<List<TtsVoice>> listPresetVoices();

  /// 上传音频样本克隆音色。
  /// 仅当 [capabilities.voiceCloning] 为 true 时有效。
  ///
  /// [audioBytes] 音频字节；[format] 文件扩展名（mp3/m4a/wav）；
  /// [name] 用户命名；[samplePath] 本地样本路径（用于重克隆）。
  Future<TtsVoice> cloneVoice({
    required Uint8List audioBytes,
    required String format,
    required String name,
    String? samplePath,
  });

  /// 通过文字描述生成音色。
  /// 仅当 [capabilities.voiceDescription] 为 true 时有效。
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  });

  /// 合成文本为音频。
  ///
  /// [text] 待合成文本（已按单次上限切分后的）；
  /// [voice] 使用音色（providerId 必须等于本 Provider 的 id）；
  /// [speed] 语速倍率（0.5–2.0，默认 1.0）。
  Future<TtsChunk> synthesize({
    required String text,
    required TtsVoice voice,
    double speed,
  });
}
