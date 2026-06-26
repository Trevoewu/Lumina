/// 每个 TTS Provider 声明自己支持的能力。
/// UI 层根据这些标志动态显示/隐藏"克隆音色""描述生成""试听"等入口，
/// 而非 if/else 硬编码 Provider 名。
class TtsCapabilities {
  /// 是否有内置预置音色库（preset voices）。
  final bool presetVoices;

  /// 是否支持上传音频样本克隆音色。
  final bool voiceCloning;

  /// 是否支持通过文字描述生成音色（voice design / text-to-voice）。
  final bool voiceDescription;

  /// 单次合成请求的文本字符上限。
  final int maxCharsPerCall;

  /// 是否支持流式合成输出。
  final bool streaming;

  /// 支持的输出音频格式。
  final List<String> outputFormats;

  /// 是否需要网络连接。
  final bool requiresNetwork;

  /// 是否按量计费（用于成本预估与告警）。
  final bool paid;

  /// 克隆音频样本的约束（若支持克隆）。
  final VoiceCloneConstraints? cloneConstraints;

  /// 音色描述的字符上限（若支持描述生成）。
  final int? maxDescriptionLength;

  const TtsCapabilities({
    required this.presetVoices,
    required this.voiceCloning,
    required this.voiceDescription,
    required this.maxCharsPerCall,
    this.streaming = false,
    this.outputFormats = const ['mp3'],
    this.requiresNetwork = true,
    this.paid = true,
    this.cloneConstraints,
    this.maxDescriptionLength,
  });
}

/// 克隆音频样本的格式与大小约束。
class VoiceCloneConstraints {
  final List<String> allowedFormats; // ['mp3', 'm4a', 'wav']
  final int minDurationSeconds;
  final int maxDurationSeconds;
  final int maxSizeBytes;

  const VoiceCloneConstraints({
    this.allowedFormats = const ['mp3', 'm4a', 'wav'],
    this.minDurationSeconds = 10,
    this.maxDurationSeconds = 300,
    this.maxSizeBytes = 20 * 1024 * 1024, // 20 MB
  });
}
