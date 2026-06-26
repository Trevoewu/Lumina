import 'dart:io';

import 'package:lumina/tts/providers/edge_tts_provider.dart';

Future<void> main() async {
  final provider = EdgeTtsProvider();
  final voices = await provider.listPresetVoices();
  final chunk = await provider.synthesize(
    text: 'Lumina 语音合成测试。',
    voice: voices.first,
  );
  final file = File('/tmp/lumina_edge_tts_test.mp3');
  await file.writeAsBytes(chunk.audioBytes);
  stdout.writeln(
    'bytes=${chunk.audioBytes.length} durationMs=${chunk.durationMs} file=${file.path}',
  );
}
