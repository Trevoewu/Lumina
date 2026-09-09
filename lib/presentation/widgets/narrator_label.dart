import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/providers.dart';
import '../../tts/provider_registry.dart';

/// Read-only narration attribution for book and player surfaces.
class NarratorLabel extends ConsumerWidget {
  final String? voiceId;
  final bool compact;

  const NarratorLabel({super.key, required this.voiceId, this.compact = false});

  Future<String?> _loadNarrator(WidgetRef ref) async {
    final provider = ref.read(activeTtsProviderProvider);
    final selectedVoiceId =
        voiceId ??
        await ref
            .read(providerSelectionRepositoryProvider)
            .selectedVoice(provider.id);
    if (selectedVoiceId == null) return null;

    final database = ref.read(appDatabaseProvider);
    final savedVoices = await database.getVoicesByProvider(provider.id);
    for (final voice in savedVoices) {
      if (voice.id == selectedVoiceId ||
          voice.providerVoiceId == selectedVoiceId) {
        return voice.name;
      }
    }
    final presets = await provider.listPresetVoices();
    for (final voice in presets) {
      if (voice.id == selectedVoiceId ||
          voice.providerVoiceId == selectedVoiceId) {
        return voice.name;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: _loadNarrator(ref),
      builder: (context, snapshot) => Text(
        'Read by ${snapshot.data ?? 'Unknown narrator'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.appTextSecondary,
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }
}
