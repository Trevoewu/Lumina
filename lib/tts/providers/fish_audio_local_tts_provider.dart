import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/fish_audio_model_manager.dart';
import '../models/tts_capabilities.dart';
import '../models/tts_chunk.dart';
import '../models/tts_voice.dart';
import '../tts_provider.dart';

class FishAudioLocalTtsProvider implements TtsProvider {
  static const String idValue = 'fish_audio_local';
  static const String defaultPythonPath =
      '/Users/trevorwu/projects/audiobook_app/.kokoro_venv/bin/python';
  static const String defaultServerScript =
      '/Users/trevorwu/projects/audiobook_app/tool/kokoro_tts_server.py';
  static const String _defaultReferenceText =
      'Lumina uses this steady audiobook narrator voice for every paragraph.';
  static const String _defaultReferenceInstruction =
      'Use a calm, natural, consistent audiobook narrator voice.';

  final String? modelPath;
  final String pythonPath;
  final String serverScriptPath;

  Process? _serverProcess;
  bool _starting = false;
  Completer<void>? _readyCompleter;
  Stream<String>? _stdoutLines;
  final _responseQueue = <Completer<String>>[];

  FishAudioLocalTtsProvider({
    this.modelPath,
    this.pythonPath = defaultPythonPath,
    this.serverScriptPath = defaultServerScript,
  });

  @override
  String get id => idValue;

  @override
  String get displayName => 'Fish Audio S2 Pro（MLX 8bit）';

  @override
  TtsCapabilities get capabilities => const TtsCapabilities(
    presetVoices: true,
    voiceCloning: true,
    voiceDescription: false,
    maxCharsPerCall: 800,
    streaming: false,
    outputFormats: ['wav'],
    requiresNetwork: false,
    paid: false,
    cloneConstraints: VoiceCloneConstraints(
      allowedFormats: ['wav', 'mp3', 'm4a', 'flac'],
      minDurationSeconds: 5,
      maxDurationSeconds: 300,
      maxSizeBytes: 100 * 1024 * 1024,
    ),
  );

  static const List<TtsVoice> _presetVoices = <TtsVoice>[
    TtsVoice(
      id: 'fish_s2_default',
      name: 'Default（多语言）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'default',
      presetDescription: 'Fish Audio S2 Pro 默认本地音色，支持中英日等多语言和内联情绪标签',
      createdAt: 0,
    ),
  ];

  @override
  Future<bool> validate() async {
    final resolvedModelPath = await _resolveModelPath();
    final python = File(pythonPath);
    final modelDir = Directory(resolvedModelPath);
    final config = File(p.join(resolvedModelPath, 'config.json'));
    final weights = File(p.join(resolvedModelPath, 'model.safetensors'));
    final codec = File(p.join(resolvedModelPath, 'codec.safetensors'));
    final tokenizer = File(p.join(resolvedModelPath, 'tokenizer.json'));
    final script = File(serverScriptPath);
    return python.existsSync() &&
        modelDir.existsSync() &&
        config.existsSync() &&
        weights.existsSync() &&
        codec.existsSync() &&
        tokenizer.existsSync() &&
        script.existsSync();
  }

  @override
  Future<List<TtsVoice>> listPresetVoices() async => _presetVoices;

  @override
  Future<TtsVoice> cloneVoice({
    required Uint8List audioBytes,
    required String format,
    required String name,
    String? samplePath,
  }) async {
    final normalizedFormat = format.toLowerCase().replaceFirst('.', '');
    if (!capabilities.cloneConstraints!.allowedFormats.contains(
      normalizedFormat,
    )) {
      throw ArgumentError('Fish Audio 不支持 $format 音频样本');
    }

    final voiceId = 'fish_clone_${DateTime.now().millisecondsSinceEpoch}';
    final target = await _cloneSampleFile(voiceId, normalizedFormat);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(audioBytes, flush: true);

    return TtsVoice(
      id: voiceId,
      name: name,
      providerId: idValue,
      type: VoiceType.clone,
      providerVoiceId: voiceId,
      samplePath: target.path,
      presetDescription: samplePath,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  }) {
    throw UnsupportedError('Fish Audio 本地 TTS 暂不支持文字描述生成音色');
  }

  Future<void> _ensureServer() async {
    if (_serverProcess != null) return;
    if (_starting) {
      await _readyCompleter?.future;
      return;
    }

    _starting = true;
    final readyCompleter = Completer<void>();
    _readyCompleter = readyCompleter;

    try {
      _serverProcess = await Process.start(
        pythonPath,
        [serverScriptPath],
        workingDirectory: '/Users/trevorwu/projects/audiobook_app',
        environment: {'MLX_TTS_MODEL_PATH': await _resolveModelPath()},
      );

      _stdoutLines = _serverProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      _stdoutLines!.listen((line) {
        if (line.trim().isEmpty) return;
        if (_responseQueue.isNotEmpty) {
          final completer = _responseQueue.removeAt(0);
          if (!completer.isCompleted) {
            completer.complete(line.trim());
          }
        }
      });

      _serverProcess!.stderr.transform(utf8.decoder).listen((data) {
        if (data.contains('TTS server ready') && !readyCompleter.isCompleted) {
          readyCompleter.complete();
        }
        if (data.contains('Kokoro server ready') &&
            !readyCompleter.isCompleted) {
          readyCompleter.complete();
        }
      });

      await readyCompleter.future.timeout(
        const Duration(seconds: 180),
        onTimeout: () {
          if (!readyCompleter.isCompleted) {
            readyCompleter.completeError(
              TimeoutException('Fish Audio 服务启动超时（180s）'),
            );
          }
        },
      );
      _starting = false;
    } catch (_) {
      _starting = false;
      rethrow;
    }
  }

  @override
  Future<TtsChunk> synthesize({
    required String text,
    required TtsVoice voice,
    double speed = 1.0,
  }) async {
    if (voice.providerId != id) {
      throw ArgumentError(
        '音色 ${voice.name} 属于 ${voice.providerId}，不能用于 $displayName',
      );
    }
    if (!await validate()) {
      final resolvedModelPath = await _resolveModelPath();
      throw StateError(
        'Fish Audio 本地 TTS 未就绪：请先在设置中下载模型，并确认模型目录 $resolvedModelPath、Python 环境 $pythonPath 和服务脚本 $serverScriptPath 存在',
      );
    }

    await _ensureServer();
    if (_serverProcess == null) {
      throw StateError('Fish Audio 服务进程未启动');
    }

    final referenceAudio = await _referenceAudioForVoice(voice);
    final isClone = voice.type == VoiceType.clone;
    final referenceText = isClone
        ? voice.description?.trim()
        : _defaultReferenceText;
    if (isClone && (referenceText == null || referenceText.isEmpty)) {
      throw StateError('Fish Audio 克隆音色需要填写参考文本：${voice.name}');
    }
    final tempDir = await Directory.systemTemp.createTemp('lumina-fish-');
    final outputPath = '${tempDir.path}/chunk.wav';

    try {
      final response = await _requestSynthesis(
        text: text,
        voice: voice.providerVoiceId,
        speed: speed.clamp(0.5, 2.0).toStringAsFixed(2),
        langCode: 'auto',
        output: outputPath,
        refAudio: referenceAudio.path,
        refText: referenceText,
        instruct: isClone ? null : _defaultReferenceInstruction,
        temperature: 0.45,
        topP: 0.65,
        topK: 20,
        chunkLength: 800,
        timeout: const Duration(seconds: 600),
      );

      final wavFile = File(response['file'] as String);
      if (!wavFile.existsSync() || wavFile.lengthSync() == 0) {
        throw StateError('Fish Audio 合成失败：没有生成 wav 文件');
      }

      final bytes = await wavFile.readAsBytes();
      final durationMs = (response['duration_ms'] as num?)?.toInt() ?? 0;

      return TtsChunk(
        audioBytes: bytes,
        durationMs: durationMs,
        format: 'wav',
        billedCharacters: null,
        sampleRate: 24000,
      );
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
    }
  }

  Future<File> _referenceAudioForVoice(TtsVoice voice) async {
    if (voice.type == VoiceType.clone) {
      final samplePath = voice.samplePath;
      if (samplePath == null || samplePath.isEmpty) {
        throw StateError('Fish Audio 克隆音色缺少参考音频路径：${voice.name}');
      }
      final file = File(samplePath);
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('Fish Audio 克隆音色参考音频不存在：$samplePath');
      }
      return file;
    }
    return _ensureDefaultReferenceAudio(voice);
  }

  Future<File> _ensureDefaultReferenceAudio(TtsVoice voice) async {
    final file = await _defaultReferenceAudioFile();
    if (await file.exists() && await file.length() > 0) {
      return file;
    }

    await file.parent.create(recursive: true);
    final response = await _requestSynthesis(
      text: _defaultReferenceText,
      voice: voice.providerVoiceId,
      speed: '1.00',
      langCode: 'auto',
      output: file.path,
      instruct: _defaultReferenceInstruction,
      temperature: 0.45,
      topP: 0.65,
      topK: 20,
      chunkLength: 800,
      timeout: const Duration(seconds: 600),
    );

    final generated = File(response['file'] as String);
    if (!await generated.exists() || await generated.length() == 0) {
      throw StateError('Fish Audio 默认参考音色生成失败：没有生成 wav 文件');
    }
    return generated;
  }

  Future<Map<String, dynamic>> _requestSynthesis({
    required String text,
    required String voice,
    required String speed,
    required String langCode,
    required String output,
    String? refAudio,
    String? refText,
    String? instruct,
    double? temperature,
    double? topP,
    int? topK,
    int? chunkLength,
    required Duration timeout,
  }) async {
    final responseCompleter = Completer<String>();
    _responseQueue.add(responseCompleter);

    _serverProcess!.stdin.writeln(
      jsonEncode({
        'text': text,
        'voice': voice,
        'speed': speed,
        'lang_code': langCode,
        'output': output,
        'ref_audio': ?refAudio,
        'ref_text': ?refText,
        'instruct': ?instruct,
        'temperature': ?temperature,
        'top_p': ?topP,
        'top_k': ?topK,
        'chunk_length': ?chunkLength,
      }),
    );

    final responseStr = await responseCompleter.future.timeout(
      timeout,
      onTimeout: () {
        if (!responseCompleter.isCompleted) {
          responseCompleter.completeError(
            TimeoutException('Fish Audio 合成超时（${timeout.inSeconds}s）'),
          );
        }
        throw TimeoutException('Fish Audio 合成超时（${timeout.inSeconds}s）');
      },
    );

    final response = jsonDecode(responseStr) as Map<String, dynamic>;
    if (response['ok'] != true) {
      throw StateError('Fish Audio 合成失败：${response['error'] ?? '未知错误'}');
    }
    return response;
  }

  Future<String> _resolveModelPath() async {
    return modelPath ?? FishAudioModelManager.defaultModelPath();
  }

  Future<File> _defaultReferenceAudioFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(
      p.join(
        dir.path,
        'models',
        'fish-audio',
        'voices',
        'default_reference.wav',
      ),
    );
  }

  Future<File> _cloneSampleFile(String voiceId, String format) async {
    final dir = await getApplicationSupportDirectory();
    return File(
      p.join(
        dir.path,
        'models',
        'fish-audio',
        'voices',
        'clones',
        '$voiceId.$format',
      ),
    );
  }

  void dispose() {
    if (_serverProcess != null) {
      try {
        _serverProcess!.stdin.writeln('{"quit":true}');
        _serverProcess!.kill();
      } catch (_) {}
      _serverProcess = null;
    }
    for (final c in _responseQueue) {
      if (!c.isCompleted) c.completeError(StateError('Server disposed'));
    }
    _responseQueue.clear();
  }
}
