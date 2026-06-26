import 'dart:io';

import 'package:lumina/tts/providers/kokoro_local_tts_provider.dart';

Future<void> main() async {
  final provider = KokoroLocalTtsProvider();
  final ready = await provider.validate();
  if (!ready) {
    stderr.writeln('Kokoro provider is not ready');
    exitCode = 2;
    return;
  }

  final voice = (await provider.listPresetVoices()).first;
  if (voice.providerVoiceId != 'af_heart') {
    stderr.writeln(
      'Expected default Kokoro voice af_heart, got ${voice.providerVoiceId}',
    );
    exitCode = 3;
    return;
  }

  final chunk = await provider.synthesize(
    text:
        'Hello, this is Lumina using the local Kokoro English voice by default.',
    voice: voice,
  );
  final file = File('/tmp/lumina_kokoro_provider_test.wav');
  await file.writeAsBytes(chunk.audioBytes);
  stdout.writeln(
    'provider=${provider.id} defaultVoice=${voice.providerVoiceId} bytes=${chunk.audioBytes.length} durationMs=${chunk.durationMs} sampleRate=${chunk.sampleRate} file=${file.path}',
  );
  provider.dispose();
}
