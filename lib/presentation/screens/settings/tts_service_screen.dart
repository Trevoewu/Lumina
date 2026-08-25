import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_design_tokens.dart';
import '../../../core/app_localizations.dart';
import '../../../tts/provider_registry.dart';
import '../../../core/service_settings_controllers.dart';
import '../../../tts/models/tts_voice.dart';
import '../../widgets/collapsing_page_scaffold.dart';
import '../../widgets/design_system/settings_components.dart';
import 'tts_provider_editor_sheet.dart';
import 'voice_preview_controller.dart';

/// The "语音合成 (TTS)" pane: the built-in voice providers as selectable
/// cards, the active one expanded to its models and voices, plus the text
/// slice length.
class TtsServiceScreen extends ConsumerStatefulWidget {
  const TtsServiceScreen({super.key});

  @override
  ConsumerState<TtsServiceScreen> createState() => _TtsServiceScreenState();
}

class _TtsServiceScreenState extends ConsumerState<TtsServiceScreen> {
  VoicePreviewController? _preview;

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  VoicePreviewController get _previewController {
    return _preview ??= VoicePreviewController(
      ref.read(providerRegistryProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ttsSettingsControllerProvider);
    final design = context.appDesign;
    final inset = design.pageInsetFor(MediaQuery.sizeOf(context).width);
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(ttsSettingsControllerProvider.notifier);

    return CollapsingPageScaffold(
      title: context.tr('语音合成', 'Voice Synthesis', '音声合成'),
      showBackButton: true,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            SettingsErrorState(error: error, onRetry: controller.reload),
        data: (data) => ListView(
          padding: EdgeInsets.fromLTRB(inset, design.spaceSm, inset, 120),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                context.tr(
                  '模型与音色通过提供商接口获取。密钥只保存在本机钥匙串。',
                  'Models and voices come from the provider\'s API. Keys stay in this device\'s keychain.',
                  'モデルと音声はプロバイダーのAPIから取得します。キーは端末のキーチェーンにのみ保存されます。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),

            SettingsSectionLabel(
              title: context.tr('可用的提供商', 'Available providers', '利用可能なプロバイダー'),
            ),
            for (final card in data.cards) ...[
              _TtsProviderCard(
                card: card,
                onSelect: card.active
                    ? null
                    : () => _activate(controller, card.id),
                onEdit: () =>
                    TtsProviderEditorSheet.show(context, providerId: card.id),
                onPickModel: (id) => controller.selectModel(id),
                onPickVoice: (id) => controller.selectVoice(id),
                onPreview: _playPreview,
                playingVoiceId: _preview?.playingVoiceId,
              ),
              const SizedBox(height: 10),
            ],

            SettingsSectionLabel(
              title: context.tr('分段长度', 'Slice Length', '分割の長さ'),
            ),
            SettingsCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('文本切片', 'Text slice', 'テキストスライス'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        context.tr(
                          '${data.chunkChars} 字',
                          '${data.chunkChars} chars',
                          '${data.chunkChars} 文字',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final chars
                          in TtsSettingsController.supportedChunkChars)
                        SettingsChip(
                          label: context.tr(
                            '$chars 字',
                            '$chars chars',
                            '$chars 文字',
                          ),
                          selected: data.chunkChars == chars,
                          onTap: () => controller.setChunkChars(chars),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _chunkHint(context, data.chunkChars),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activate(
    TtsSettingsController controller,
    String providerId,
  ) async {
    try {
      await controller.selectProvider(providerId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _playPreview(TtsVoice voice) async {
    try {
      await _previewController.toggle(voice);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '无法播放试听片段',
              'Unable to play this preview.',
              '試聴サンプルを再生できません',
            ),
          ),
        ),
      );
    }
  }

  String _chunkHint(BuildContext context, int chars) {
    final segments = (80000 / chars).ceil();
    final tail = chars >= 1000
        ? context.tr(
            '，段落衔接最自然，但单段失败重试成本高。',
            ' — the smoothest transitions, but a failed segment is expensive to retry.',
            '。つなぎが最も自然ですが、失敗時の再試行コストが高くなります。',
          )
        : chars <= 200
        ? context.tr(
            '，失败重试便宜，段间可能有轻微停顿。',
            ' — cheap retries, with slight pauses between segments.',
            '。再試行は安価ですが、区切りでわずかな間が生じます。',
          )
        : context.tr(
            '，多数书籍的推荐值。',
            ' — the recommended value for most books.',
            '。ほとんどの書籍に推奨される値です。',
          );
    return context.tr(
      '一本 8 万字的书约切成 $segments 段$tail',
      'An 80,000-character book becomes about $segments segments$tail',
      '8万文字の本は約$segments段に分割されます$tail',
    );
  }
}

class _TtsProviderCard extends StatelessWidget {
  final TtsProviderCardData card;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final ValueChanged<String> onPickModel;
  final ValueChanged<String> onPickVoice;
  final ValueChanged<TtsVoice> onPreview;
  final String? playingVoiceId;

  const _TtsProviderCard({
    required this.card,
    required this.onSelect,
    required this.onEdit,
    required this.onPickModel,
    required this.onPickVoice,
    required this.onPreview,
    required this.playingVoiceId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(18);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('tts-provider-${card.id}'),
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: card.active ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SettingsRadio(selected: card.active),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  card.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _Tag(label: card.tag),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _meta(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SquareButton(
                      key: ValueKey('tts-edit-${card.id}'),
                      icon: Icons.edit_outlined,
                      onTap: onEdit,
                      semanticLabel: context.tr('编辑', 'Edit', '編集'),
                    ),
                  ],
                ),
                if (card.active) ...[
                  const SizedBox(height: 15),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 14),
                  _SubLabel(label: context.tr('模型', 'Models', 'モデル')),
                  const SizedBox(height: 11),
                  if (card.models.isEmpty)
                    _EmptyHint(
                      text: context.tr(
                        '还没有模型列表，请先在编辑里填入 API Key。',
                        'No models yet — add an API key from the edit button first.',
                        'モデルがありません。編集からAPIキーを入力してください。',
                      ),
                    )
                  else
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final model in card.models)
                          SettingsChip(
                            label: model.name,
                            selected: card.selectedModelId == model.id,
                            onTap: () => onPickModel(model.id),
                          ),
                      ],
                    ),

                  if (card.voices.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: scheme.onSurface.withValues(alpha: 0.06),
                    ),
                    const SizedBox(height: 14),
                    _SubLabel(label: context.tr('音色', 'Voices', '音声')),
                    const SizedBox(height: 11),
                    for (final voice in card.voices)
                      _VoiceRow(
                        voice: voice,
                        selected: card.selectedVoiceId == voice.id,
                        playing: playingVoiceId == voice.id,
                        onTap: () => onPickVoice(voice.id),
                        onPreview: () => onPreview(voice),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _meta(BuildContext context) {
    if (!card.configured) {
      return context.tr('未配置 API Key', 'No API key yet', 'APIキー未設定');
    }
    final parts = <String>[
      card.selectedModelId ?? context.tr('未选择模型', 'No model', 'モデル未選択'),
      context.tr(
        '${card.voices.length} 个音色',
        '${card.voices.length} voices',
        '${card.voices.length} 件の音声',
      ),
    ];
    return parts.join(' · ');
  }
}

class _VoiceRow extends StatelessWidget {
  final TtsVoice voice;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  const _VoiceRow({
    required this.voice,
    required this.selected,
    required this.playing,
    required this.onTap,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('tts-voice-${voice.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            SettingsRadio(selected: selected, size: 19),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_note(context) case final note?) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: context.tr('试听', 'Preview', '試聴'),
              child: Material(
                color: scheme.onSurface.withValues(alpha: 0.06),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('tts-preview-${voice.id}'),
                  onTap: onPreview,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 18,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _note(BuildContext context) {
    final languages = voice.languages;
    if (languages.isNotEmpty) return languages.join(' · ').toUpperCase();
    return null;
  }
}

class _SubLabel extends StatelessWidget {
  final String label;

  const _SubLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontFamily: 'monospace',
        fontSize: 11,
        letterSpacing: 1.3,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const _SquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
