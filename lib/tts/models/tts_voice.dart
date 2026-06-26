/// 音色类型。
enum VoiceType {
  /// Provider 内置的预置音色。
  preset,

  /// 通过上传音频样本克隆得到的音色。
  clone,

  /// 通过文字描述生成的音色。
  description,
}

/// 统一音色模型。
///
/// 关键约束：音色**绑定 Provider**。通过 A Provider 克隆的音色，
/// 不能给 B Provider 使用。切换 Provider 时，音色选择器只显示
/// 该 Provider 的 preset + 该 Provider 下克隆/生成的音色。
class TtsVoice {
  /// 本地唯一 id（由 app 生成，用于数据库主键）。
  final String id;

  /// 用户可读名称。
  final String name;

  /// 来源 Provider 的 id（如 'minimax'、'edge'）。
  final String providerId;

  /// 音色类型。
  final VoiceType type;

  /// Provider 内部的 voice_id（用于 API 调用）。
  /// preset: Provider 系统音色 id；
  /// clone: 克隆返回的 voice_id；
  /// description: 文生音色返回的 voice_id。
  final String providerVoiceId;

  /// 克隆音色：本地样本文件路径。
  final String? samplePath;

  /// 描述音色：用户输入的描述文本。
  final String? description;

  /// 预置音色：Provider 返回的描述。
  final String? presetDescription;

  /// 试听音频 URL（若有）。
  final String? previewUrl;

  /// 创建时间（毫秒）。
  final int createdAt;

  const TtsVoice({
    required this.id,
    required this.name,
    required this.providerId,
    required this.type,
    required this.providerVoiceId,
    this.samplePath,
    this.description,
    this.presetDescription,
    this.previewUrl,
    required this.createdAt,
  });

  TtsVoice copyWith({
    String? id,
    String? name,
    String? providerId,
    VoiceType? type,
    String? providerVoiceId,
    String? samplePath,
    String? description,
    String? presetDescription,
    String? previewUrl,
    int? createdAt,
  }) {
    return TtsVoice(
      id: id ?? this.id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      type: type ?? this.type,
      providerVoiceId: providerVoiceId ?? this.providerVoiceId,
      samplePath: samplePath ?? this.samplePath,
      description: description ?? this.description,
      presetDescription: presetDescription ?? this.presetDescription,
      previewUrl: previewUrl ?? this.previewUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider_id': providerId,
      'type': type.name,
      'provider_voice_id': providerVoiceId,
      'sample_path': samplePath,
      'description': description,
      'preset_description': presetDescription,
      'preview_url': previewUrl,
      'created_at': createdAt,
    };
  }

  factory TtsVoice.fromMap(Map<String, dynamic> map) {
    return TtsVoice(
      id: map['id'] as String,
      name: map['name'] as String,
      providerId: map['provider_id'] as String,
      type: VoiceType.values.byName(map['type'] as String),
      providerVoiceId: map['provider_voice_id'] as String,
      samplePath: map['sample_path'] as String?,
      description: map['description'] as String?,
      presetDescription: map['preset_description'] as String?,
      previewUrl: map['preview_url'] as String?,
      createdAt: map['created_at'] as int,
    );
  }
}
