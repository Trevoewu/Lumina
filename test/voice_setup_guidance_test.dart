import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/voice_library_screen.dart';
import 'package:lumina/tts/models/tts_voice.dart';
import 'package:lumina/tts/provider_registry.dart';
import 'package:lumina/tts/providers/fish_audio_api_tts_provider.dart';

void main() {
  testWidgets('guided setup syncs cloud voices and requires a selection', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final registry = ProviderRegistry()..register(_GuidedFishAudioProvider());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          providerRegistryProvider.overrideWithValue(registry),
        ],
        child: const MaterialApp(home: _VoiceSetupLauncher()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-voice-setup')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a Reading Voice'), findsOneWidget);
    expect(
      find.textContaining('Available voices are synced from the cloud'),
      findsOneWidget,
    );
    expect(find.text('Narrator One'), findsOneWidget);
    expect(find.text('Narrator Two'), findsOneWidget);
    expect(await database.getVoicesByProvider('fish_audio_api'), hasLength(2));

    await tester.tap(find.text('Narrator Two'));
    await tester.pumpAndSettle();

    expect(find.text('Voice selected'), findsOneWidget);
    expect(await database.getSetting('active_voice_id'), 'guided-voice-2');
  });
}

class _VoiceSetupLauncher extends StatefulWidget {
  const _VoiceSetupLauncher();

  @override
  State<_VoiceSetupLauncher> createState() => _VoiceSetupLauncherState();
}

class _VoiceSetupLauncherState extends State<_VoiceSetupLauncher> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _selected
          ? const Text('Voice selected')
          : FilledButton(
              key: const ValueKey('start-voice-setup'),
              onPressed: () async {
                final selected = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const VoiceLibraryScreen(
                      guidedSelection: true,
                      syncOnOpen: true,
                    ),
                  ),
                );
                if (mounted && selected == true) {
                  setState(() => _selected = true);
                }
              },
              child: const Text('Start'),
            ),
    ),
  );
}

class _GuidedFishAudioProvider extends FishAudioApiTtsProvider {
  @override
  Future<List<TtsVoice>> listPresetVoices() async => const [
    TtsVoice(
      id: 'guided-voice-1',
      name: 'Narrator One',
      providerId: FishAudioApiTtsProvider.idValue,
      type: VoiceType.preset,
      providerVoiceId: 'narrator-one',
      createdAt: 1,
    ),
    TtsVoice(
      id: 'guided-voice-2',
      name: 'Narrator Two',
      providerId: FishAudioApiTtsProvider.idValue,
      type: VoiceType.preset,
      providerVoiceId: 'narrator-two',
      createdAt: 2,
    ),
  ];
}
