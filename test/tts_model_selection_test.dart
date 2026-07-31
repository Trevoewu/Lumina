import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/tts_service_screen.dart';
import 'package:lumina/presentation/screens/settings/tts_setup_wizard_screen.dart';
import 'package:lumina/tts/models/tts_model.dart';
import 'package:lumina/tts/models/tts_voice.dart';
import 'package:lumina/tts/provider_registry.dart';
import 'package:lumina/tts/providers/fish_audio_api_tts_provider.dart';
import 'package:lumina/tts/providers/minimax_tts_provider.dart';

void main() {
  test('cloud providers use their provider-scoped selected model', () async {
    final fish = FishAudioApiTtsProvider(
      modelSelectionReader: (_) async => 's1',
    );
    final minimax = MinimaxTtsProvider(
      modelSelectionReader: (_) async => 'speech-2.8-turbo',
    );

    expect(await fish.selectedModel, 's1');
    expect(await minimax.selectedModel, 'speech-2.8-turbo');
    expect(
      FishAudioApiTtsProvider.bundledModels.map((model) => model.id),
      containsAll(['s2.1-pro', 's2.1-pro-free', 's2-pro', 's1']),
    );
    expect(
      MinimaxTtsProvider.bundledModels.map((model) => model.id),
      containsAll(['speech-2.8-hd', 'speech-2.8-turbo', 'speech-2.6-hd']),
    );
  });

  test(
    'Fish discovers TTS model updates from the official OpenAPI enum',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'paths': {
                  '/v1/tts': {
                    'post': {
                      'parameters': [
                        {
                          'name': 'model',
                          'in': 'header',
                          'schema': {
                            'enum': ['s2.1-pro', 's3-preview'],
                          },
                        },
                      ],
                    },
                  },
                },
              },
            ),
          ),
        ),
      );
      final provider = FishAudioApiTtsProvider(dio: dio);

      final models = await provider.listModels(refresh: true);

      expect(models.map((model) => model.id), ['s2.1-pro', 's3-preview']);
      expect(provider.modelCatalogSource, TtsModelCatalogSource.officialApi);
    },
  );

  test(
    'MiniMax falls back to its official TTS catalog when models API returns only LLMs',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'object': 'list',
                'data': [
                  {'id': 'MiniMax-M3'},
                ],
              },
            ),
          ),
        ),
      );
      final provider = _ConfiguredModelMinimaxProvider(dio: dio);

      final models = await provider.listModels(refresh: true);

      expect(models, MinimaxTtsProvider.bundledModels);
      expect(
        provider.modelCatalogSource,
        TtsModelCatalogSource.bundledFallback,
      );
    },
  );

  test(
    'MiniMax includes new speech models returned by its official API',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'object': 'list',
                'data': [
                  {'id': 'MiniMax-M3'},
                  {'id': 'speech-2.8-hd'},
                  {'id': 'speech-3-preview'},
                ],
              },
            ),
          ),
        ),
      );
      final provider = _ConfiguredModelMinimaxProvider(dio: dio);

      final models = await provider.listModels(refresh: true);

      expect(models.map((model) => model.id), [
        'speech-2.8-hd',
        'speech-3-preview',
      ]);
      expect(provider.modelCatalogSource, TtsModelCatalogSource.officialApi);
    },
  );

  testWidgets('guided setup syncs and saves a provider-scoped TTS model', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final registry = ProviderRegistry()..register(_GuidedModelProvider());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          providerRegistryProvider.overrideWithValue(registry),
          ttsProviderConfigurationStatusProvider.overrideWith(
            (ref) async => const {'fish_audio_api': true, 'minimax': false},
          ),
        ],
        child: const MaterialApp(home: _ModelSetupLauncher()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-model-setup')));
    await tester.pumpAndSettle();

    expect(find.text('Choose Voice Model'), findsOneWidget);
    expect(find.text('Narration Pro'), findsOneWidget);
    expect(find.text('Narration Fast'), findsOneWidget);

    await tester.ensureVisible(find.text('Narration Fast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Narration Fast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();

    expect(find.text('Model selected'), findsOneWidget);
    expect(
      await database.getSetting('tts_selected_model_by_provider_v1'),
      '{"fish_audio_api":"narration-fast"}',
    );
  });

  testWidgets('single-page TTS wizard animates from model to voice', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final registry = ProviderRegistry()..register(_GuidedModelProvider());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          providerRegistryProvider.overrideWithValue(registry),
          ttsProviderConfigurationStatusProvider.overrideWith(
            (ref) async => const {'fish_audio_api': true, 'minimax': false},
          ),
        ],
        child: const MaterialApp(home: _SinglePageTtsLauncher()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-single-page-tts')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final wizardElement = tester.element(find.byType(TtsSetupWizardScreen));

    await tester.ensureVisible(find.text('Narration Fast'));
    await tester.tap(find.text('Narration Fast'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SlideTransition), findsWidgets);
    expect(
      tester.element(find.byType(TtsSetupWizardScreen)),
      same(wizardElement),
    );
    await tester.pumpAndSettle();
    expect(find.text('Narrator One'), findsOneWidget);

    await tester.tap(find.text('Narrator One'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();

    expect(find.text('Setup complete'), findsOneWidget);
    expect(
      await database.getSetting('tts_selected_model_by_provider_v1'),
      '{"fish_audio_api":"narration-fast"}',
    );
  });
}

class _ModelSetupLauncher extends StatefulWidget {
  const _ModelSetupLauncher();

  @override
  State<_ModelSetupLauncher> createState() => _ModelSetupLauncherState();
}

class _ModelSetupLauncherState extends State<_ModelSetupLauncher> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _selected
          ? const Text('Model selected')
          : FilledButton(
              key: const ValueKey('start-model-setup'),
              onPressed: () async {
                final selected = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const TtsModelPickerScreen(
                      providerId: FishAudioApiTtsProvider.idValue,
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

class _GuidedModelProvider extends FishAudioApiTtsProvider {
  @override
  Future<String?> get apiKey async => 'test-key';

  @override
  Future<bool> validate() async => true;

  @override
  Future<List<TtsModel>> listModels({bool refresh = false}) async => const [
    TtsModel(
      id: 'narration-pro',
      name: 'Narration Pro',
      description: 'Detailed long-form narration',
      recommended: true,
    ),
    TtsModel(
      id: 'narration-fast',
      name: 'Narration Fast',
      description: 'Low-latency narration',
    ),
  ];

  @override
  Future<List<TtsVoice>> listPresetVoices() async => const [
    TtsVoice(
      id: 'narrator-one',
      name: 'Narrator One',
      providerId: FishAudioApiTtsProvider.idValue,
      type: VoiceType.preset,
      providerVoiceId: 'narrator-one',
      createdAt: 1,
    ),
  ];
}

class _SinglePageTtsLauncher extends StatefulWidget {
  const _SinglePageTtsLauncher();

  @override
  State<_SinglePageTtsLauncher> createState() => _SinglePageTtsLauncherState();
}

class _SinglePageTtsLauncherState extends State<_SinglePageTtsLauncher> {
  bool _complete = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _complete
          ? const Text('Setup complete')
          : FilledButton(
              key: const ValueKey('start-single-page-tts'),
              onPressed: () async {
                final complete = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const TtsSetupWizardScreen(),
                  ),
                );
                if (mounted && complete == true) {
                  setState(() => _complete = true);
                }
              },
              child: const Text('Start'),
            ),
    ),
  );
}

class _ConfiguredModelMinimaxProvider extends MinimaxTtsProvider {
  _ConfiguredModelMinimaxProvider({required super.dio});

  @override
  Future<String?> get apiKey async => 'test-key';
}
