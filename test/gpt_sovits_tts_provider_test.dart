import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/tts/models/tts_voice.dart';
import 'package:lumina/tts/providers/gpt_sovits_tts_provider.dart';

Uint8List _makeWavBytes({int sampleRate = 32000, int samples = 3200}) {
  // 16-bit mono PCM WAV
  final byteRate = sampleRate * 2;
  final dataSize = samples * 2;
  final totalSize = 36 + dataSize;
  final b = ByteData(44 + dataSize);

  b.setUint8(0, 0x52); // R
  b.setUint8(1, 0x49); // I
  b.setUint8(2, 0x46); // F
  b.setUint8(3, 0x46); // F
  b.setUint32(4, totalSize, Endian.little);
  b.setUint8(8, 0x57); // W
  b.setUint8(9, 0x41); // A
  b.setUint8(10, 0x56); // V
  b.setUint8(11, 0x45); // E

  // fmt
  b.setUint8(12, 0x66); // f
  b.setUint8(13, 0x6D); // m
  b.setUint8(14, 0x74); // t
  b.setUint8(15, 0x20); // ' '
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // Mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, byteRate, Endian.little);
  b.setUint16(32, 2, Endian.little); // block align
  b.setUint16(34, 16, Endian.little); // bits per sample

  // data
  b.setUint8(36, 0x64); // d
  b.setUint8(37, 0x61); // a
  b.setUint8(38, 0x74); // t
  b.setUint8(39, 0x61); // a
  b.setUint32(40, dataSize, Endian.little);

  return b.buffer.asUint8List();
}

void main() {
  group('GptSovitsTtsProvider', () {
    test('default configuration and endpoint settings', () async {
      final settings = <String, String>{};
      final provider = GptSovitsTtsProvider(
        settingReader: (k) async => settings[k],
        settingWriter: (k, v) async => settings[k] = v,
      );

      expect(provider.id, 'gpt_sovits');
      expect(provider.displayName, contains('本地模型'));
      expect(provider.capabilities.requiresNetwork, isFalse);
      expect(await provider.endpoint, 'http://172.26.19.56:9880');

      await provider.setEndpoint('http://192.168.1.100:9880/');
      expect(await provider.endpoint, 'http://192.168.1.100:9880');
      expect(settings[GptSovitsTtsProvider.endpointSettingKey], 'http://192.168.1.100:9880');

      await provider.clearEndpoint();
      expect(await provider.endpoint, 'http://172.26.19.56:9880');
    });

    test('exposes Vertin models and preset voices', () async {
      final provider = GptSovitsTtsProvider();

      final models = await provider.listModels();
      expect(models, isNotEmpty);
      expect(models.first.id, 'vertin_v2_e15');

      final voices = await provider.listPresetVoices();
      expect(voices.length, 2);
      expect(voices.map((v) => v.id), containsAll(['vertin_storm', 'vertin_gentle']));
    });

    test('validates server connectivity using /openapi.json', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path.endsWith('/openapi.json')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'openapi': '3.1.0'},
                ),
              );
            }
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(requestOptions: options, statusCode: 404),
              ),
            );
          },
        ),
      );

      final provider = GptSovitsTtsProvider(dio: dio);
      expect(await provider.validate(), isTrue);
    });

    test('synthesizes speech and returns TtsChunk with parsed duration', () async {
      final dio = Dio();
      Map<String, dynamic>? capturedBody;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path.endsWith('/tts')) {
              capturedBody = options.data as Map<String, dynamic>;
              final wavBytes = _makeWavBytes(sampleRate: 32000, samples: 32000); // 1.0s
              return handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: wavBytes.toList(),
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final provider = GptSovitsTtsProvider(dio: dio);
      final voice = (await provider.listPresetVoices()).first;

      final chunk = await provider.synthesize(
        text: 'Hello, Timekeeper.',
        voice: voice,
        speed: 1.1,
      );

      expect(chunk.format, 'wav');
      expect(chunk.sampleRate, 32000);
      expect(chunk.durationMs, closeTo(1000, 50));
      expect(chunk.audioBytes.length, greaterThan(44));

      expect(capturedBody, isNotNull);
      expect(capturedBody!['text'], 'Hello, Timekeeper.');
      expect(capturedBody!['text_lang'], 'en');
      expect(capturedBody!['prompt_text'], "No, it is not. It's the storm.");
      expect(capturedBody!['speed_factor'], 1.1);
      expect(capturedBody!['media_type'], 'wav');
    });

    test('rejects voices from other providers', () async {
      final provider = GptSovitsTtsProvider();
      const otherVoice = TtsVoice(
        id: 'other',
        name: 'Other',
        providerId: 'fish_audio_api',
        type: VoiceType.preset,
        providerVoiceId: 'voice_123',
        createdAt: 0,
      );

      expect(
        () => provider.synthesize(text: 'test', voice: otherVoice),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('voice preview synthesizes English for Vertin', () async {
      final provider = GptSovitsTtsProvider();
      final voices = await provider.listPresetVoices();
      final stormVoice = voices.firstWhere((v) => v.id == 'vertin_storm');
      final gentleVoice = voices.firstWhere((v) => v.id == 'vertin_gentle');

      expect(stormVoice.languages, ['en']);
      expect(gentleVoice.languages, ['en']);
    });

    test('live integration test against local/remote server', () async {
      final provider = GptSovitsTtsProvider();
      final isOnline = await provider.validate();
      if (!isOnline) {
        // Skip if server is unreachable
        return;
      }
      final voices = await provider.listPresetVoices();
      final chunk = await provider.synthesize(
        text: 'Hello Timekeeper, Vertin voice is now integrated into the app.',
        voice: voices.first,
      );
      expect(chunk.format, 'wav');
      expect(chunk.durationMs, greaterThan(1000));
      expect(chunk.audioBytes.length, greaterThan(10000));
    });
  });
}
