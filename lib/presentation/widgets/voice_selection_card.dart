import 'package:lumina/presentation/widgets/design_system/app_icon.dart';
import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../tts/models/tts_voice.dart';
import 'design_system/settings_components.dart';

/// Shared voice option used by both TTS settings and per-book voice pickers.
class VoiceSelectionCard extends StatelessWidget {
  final TtsVoice voice;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onPreview;
  final String? subtitle;

  const VoiceSelectionCard({
    super.key,
    required this.voice,
    required this.selected,
    required this.playing,
    required this.onTap,
    this.onPreview,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final note = subtitle ?? voiceLanguageLabel(voice);
    return InkWell(
      key: ValueKey('tts-voice-${voice.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (note != null) ...[
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
            if (onPreview != null) ...[
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
                      child: AppIcon(
                        playing ? AppIcons.stop : AppIcons.play,
                        size: 18,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? voiceLanguageLabel(TtsVoice voice) {
  if (voice.languages.isEmpty) return null;
  return voice.languages.join(' · ').toUpperCase();
}

/// Returns the first voice whose declared language matches the book language.
/// Region variants such as `en-US` and `en-GB` share the same base language.
TtsVoice? voiceMatchingLanguage(Iterable<TtsVoice> voices, String? language) {
  final requested = _languageCodes(language);
  if (requested.isEmpty) return null;
  for (final voice in voices) {
    final supported = voice.languages.expand(_languageCodes).toSet();
    if (supported.any(requested.contains)) return voice;
  }
  return null;
}

Set<String> _languageCodes(String? value) {
  if (value == null) return const {};
  const aliases = <String, String>{
    'chinese': 'zh',
    'mandarin': 'zh',
    'english': 'en',
    'japanese': 'ja',
    'korean': 'ko',
    'french': 'fr',
    'german': 'de',
    'spanish': 'es',
  };
  final result = <String>{};
  for (final raw in value.toLowerCase().split(RegExp(r'[,;/\s]+'))) {
    if (raw.isEmpty) continue;
    final normalized = raw.replaceAll('_', '-');
    final code = aliases[normalized] ?? normalized;
    result.add(code);
    result.add(code.split('-').first);
  }
  return result;
}
