import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/app_log_service.dart';
import '../../../tts/models/tts_voice.dart';
import '../../../tts/provider_registry.dart';

/// Plays a short sample of a voice, preferring a provider-supplied preview
/// clip and falling back to synthesising one line.
class VoicePreviewController {
  final ProviderRegistry registry;
  final AudioPlayer _player = AudioPlayer();
  final List<File> _temporary = [];

  String? _playingVoiceId;

  VoicePreviewController(this.registry);

  String? get playingVoiceId => _playingVoiceId;

  /// Starts (or stops, when already playing) the preview for [voice].
  /// Returns true when playback started.
  Future<bool> toggle(TtsVoice voice) async {
    if (_playingVoiceId == voice.id) {
      await _player.stop();
      _playingVoiceId = null;
      return false;
    }
    await _player.stop();
    final previewUrl = voice.previewUrl?.trim();
    final samplePath = voice.samplePath?.trim();
    if (previewUrl != null && previewUrl.isNotEmpty) {
      await _player.setUrl(previewUrl);
    } else if (samplePath != null && samplePath.isNotEmpty) {
      await _player.setFilePath(samplePath);
    } else {
      final provider = registry.get(voice.providerId);
      if (provider == null || voice.providerVoiceId.trim().isEmpty) {
        throw StateError('This voice has no preview.');
      }
      final chunk = await provider.synthesize(
        text: _previewText(voice),
        voice: voice,
      );
      final directory = await getTemporaryDirectory();
      final extension = chunk.format.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final file = File(
        p.join(
          directory.path,
          'lumina_voice_preview_${voice.id.hashCode}.'
          '${extension.isEmpty ? 'wav' : extension}',
        ),
      );
      await file.writeAsBytes(chunk.audioBytes, flush: true);
      _temporary.add(file);
      await _player.setFilePath(file.path);
    }
    _playingVoiceId = voice.id;
    unawaitedPlay();
    return true;
  }

  void unawaitedPlay() {
    _player.play().catchError((Object error, StackTrace stackTrace) {
      AppLogger.error('Voice', '试听音色失败', error: error, stackTrace: stackTrace);
    });
  }

  String _previewText(TtsVoice voice) {
    final name = voice.name.trim();
    return name.isEmpty ? '这是一段音色试听。' : '你好，我是$name。这是一段音色试听。';
  }

  Future<void> dispose() async {
    await _player.dispose();
    for (final file in _temporary) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // A leftover preview in the temp directory is harmless.
      }
    }
    _temporary.clear();
  }
}
