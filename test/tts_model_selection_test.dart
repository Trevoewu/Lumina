import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/tts/models/tts_model.dart';
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

  test('Fish maps voice card metadata from the model API', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {
              'total': 1,
              'items': [
                {
                  '_id': 'voice-123',
                  'type': 'tts',
                  'title': 'Trevor Noah',
                  'state': 'trained',
                  'description': 'Clear and thoughtful delivery',
                  'cover_image': 'https://cdn.example.com/cover.jpg',
                  'created_at': '2026-07-05T12:00:00Z',
                  'tags': ['American English', 'narration'],
                  'samples': [
                    {'audio': 'https://cdn.example.com/sample.mp3'},
                  ],
                  'quality': {
                    'audios': [
                      {'filename': 'first.wav'},
                      {'filename': 'second.wav'},
                    ],
                  },
                },
              ],
            },
          ),
        ),
      ),
    );
    final provider = _ConfiguredFishVoiceProvider(dio);

    final voices = await provider.listPresetVoices();
    final voice = voices.singleWhere(
      (item) => item.providerVoiceId == 'voice-123',
    );

    expect(voice.name, 'Trevor Noah');
    expect(voice.presetDescription, 'Clear and thoughtful delivery');
    expect(voice.coverUrl, 'https://cdn.example.com/cover.jpg');
    expect(voice.previewUrl, 'https://cdn.example.com/sample.mp3');
    expect(voice.languages, ['en-US']);
    expect(voice.sampleCount, 2);
    expect(
      DateTime.fromMillisecondsSinceEpoch(voice.createdAt, isUtc: true),
      DateTime.parse('2026-07-05T12:00:00Z'),
    );
  });

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

}

class _ConfiguredFishVoiceProvider extends FishAudioApiTtsProvider {
  _ConfiguredFishVoiceProvider(Dio dio) : super(dio: dio);

  @override
  Future<String?> get apiKey async => 'test-key';
}

class _ConfiguredModelMinimaxProvider extends MinimaxTtsProvider {
  _ConfiguredModelMinimaxProvider({required super.dio});

  @override
  Future<String?> get apiKey async => 'test-key';
}
