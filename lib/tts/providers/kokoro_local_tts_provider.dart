import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../services/kokoro_model_manager.dart';
import '../models/tts_capabilities.dart';
import '../models/tts_chunk.dart';
import '../models/tts_voice.dart';
import '../tts_provider.dart';

/// 本地 Kokoro/MLX TTS Provider。
///
/// 使用持久化 Python 服务（tool/kokoro_tts_server.py）：
/// 模型只加载一次，后续合成通过 stdin/stdout JSON 协议完成。
/// 大幅减少重复模型加载开销。
class KokoroLocalTtsProvider implements TtsProvider {
  static const String idValue = 'kokoro_local';
  static const String defaultPythonPath =
      '/Users/trevorwu/projects/audiobook_app/.kokoro_venv/bin/python';
  static const String defaultServerScript =
      '/Users/trevorwu/projects/audiobook_app/tool/kokoro_tts_server.py';

  final String? modelPath;
  final String pythonPath;
  final String serverScriptPath;

  Process? _serverProcess;
  bool _starting = false;
  final _readyCompleter = Completer<void>();

  /// stdout 广播流，允许多次监听。
  Stream<String>? _stdoutLines;

  /// 响应队列：每次合成请求对应一个 Completer，按顺序从 stdout 广播流拿数据。
  final _responseQueue = <Completer<String>>[];

  KokoroLocalTtsProvider({
    this.modelPath,
    this.pythonPath = defaultPythonPath,
    this.serverScriptPath = defaultServerScript,
  });

  @override
  String get id => idValue;

  @override
  String get displayName => 'Kokoro 本地 TTS（MLX）';

  @override
  TtsCapabilities get capabilities => const TtsCapabilities(
    presetVoices: true,
    voiceCloning: false,
    voiceDescription: false,
    maxCharsPerCall: 500,
    streaming: false,
    outputFormats: ['wav'],
    requiresNetwork: false,
    paid: false,
  );

  static const List<TtsVoice> _presetVoices = <TtsVoice>[
    TtsVoice(
      id: 'kokoro_af_heart',
      name: 'Heart（女·英文）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'af_heart',
      presetDescription: 'Kokoro 高质量英文女声，默认本地音色',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'kokoro_af_bella',
      name: 'Bella（女·英文）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'af_bella',
      presetDescription: 'Kokoro 英文女声',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'kokoro_af_nova',
      name: 'Nova（女·英文）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'af_nova',
      presetDescription: 'Kokoro 英文女声',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'kokoro_am_adam',
      name: 'Adam（男·英文）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'am_adam',
      presetDescription: 'Kokoro 英文男声',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'kokoro_am_eric',
      name: 'Eric（男·英文）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'am_eric',
      presetDescription: 'Kokoro 英文男声',
      createdAt: 0,
    ),
    TtsVoice(
      id: 'kokoro_zf_xiaoxiao',
      name: '晓晓（女·中文）',
      providerId: idValue,
      type: VoiceType.preset,
      providerVoiceId: 'zf_xiaoxiao',
      presetDescription: 'Kokoro 中文女声',
      createdAt: 0,
    ),
  ];

  @override
  Future<bool> validate() async {
    final resolvedModelPath = await _resolveModelPath();
    final python = File(pythonPath);
    final modelDir = Directory(resolvedModelPath);
    final config = File(p.join(resolvedModelPath, 'config.json'));
    final weights = File(p.join(resolvedModelPath, 'kokoro-v1_0.safetensors'));
    final script = File(serverScriptPath);
    return python.existsSync() &&
        modelDir.existsSync() &&
        config.existsSync() &&
        weights.existsSync() &&
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
  }) {
    throw UnsupportedError('Kokoro 本地 TTS 暂不支持音色克隆');
  }

  @override
  Future<TtsVoice> createVoiceFromDescription({
    required String description,
    required String name,
  }) {
    throw UnsupportedError('Kokoro 本地 TTS 暂不支持文字描述生成音色');
  }

  /// 启动持久化 Python TTS 服务进程。
  Future<void> _ensureServer() async {
    // 如果已有进程，直接返回复用
    if (_serverProcess != null) {
      return;
    }
    if (_starting) {
      await _readyCompleter.future;
      return;
    }
    _starting = true;

    try {
      _serverProcess = await Process.start(
        pythonPath,
        [serverScriptPath],
        workingDirectory: '/Users/trevorwu/projects/audiobook_app',
        environment: {'KOKORO_MODEL_PATH': await _resolveModelPath()},
      );

      // 把 stdout 转成广播流，允许多次 listen
      _stdoutLines = _serverProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      // 持续监听 stdout，按顺序把 JSON 行分发给队列中的 Completer
      _stdoutLines!.listen((line) {
        if (line.trim().isEmpty) return;
        if (_responseQueue.isNotEmpty) {
          final completer = _responseQueue.removeAt(0);
          if (!completer.isCompleted) {
            completer.complete(line.trim());
          }
        }
      });

      // 等待服务就绪信号。
      final readySignal = Completer<void>();
      _serverProcess!.stderr.transform(utf8.decoder).listen((data) {
        final ready =
            data.contains('Kokoro server ready') ||
            data.contains('TTS server ready');
        if (ready && !readySignal.isCompleted) {
          readySignal.complete();
        }
      });

      // 超时保护
      await readySignal.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          if (!readySignal.isCompleted) {
            readySignal.completeError(TimeoutException('Kokoro 服务启动超时（120s）'));
          }
        },
      );

      _starting = false;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    } catch (e) {
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
        'Kokoro 本地 TTS 未就绪：请先在设置中下载模型，并确认模型目录 $resolvedModelPath、Python 环境 $pythonPath 和服务脚本 $serverScriptPath 存在',
      );
    }

    await _ensureServer();
    if (_serverProcess == null) {
      throw StateError('Kokoro 服务进程未启动');
    }

    final tempDir = await Directory.systemTemp.createTemp('lumina-kokoro-');
    final outputPath = '${tempDir.path}/chunk.wav';

    try {
      final request = jsonEncode({
        'text': text,
        'voice': voice.providerVoiceId,
        'speed': speed.clamp(0.5, 2.0).toStringAsFixed(2),
        'lang_code': _langCodeForVoice(voice.providerVoiceId),
        'output': outputPath,
      });

      // 发送请求
      _serverProcess!.stdin.writeln(request);

      // 用 Completer 队列接收响应（避免重复 listen stdout）
      final responseCompleter = Completer<String>();
      _responseQueue.add(responseCompleter);

      final responseStr = await responseCompleter.future.timeout(
        const Duration(seconds: 300),
        onTimeout: () {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(
              TimeoutException('Kokoro 合成超时（300s）'),
            );
          }
          throw TimeoutException('Kokoro 合成超时（300s）');
        },
      );

      final response = jsonDecode(responseStr) as Map<String, dynamic>;
      if (response['ok'] != true) {
        throw StateError('Kokoro 合成失败：${response['error'] ?? '未知错误'}');
      }

      final wavFile = File(response['file'] as String);
      if (!wavFile.existsSync() || wavFile.lengthSync() == 0) {
        throw StateError('Kokoro 合成失败：没有生成 wav 文件');
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

  String _langCodeForVoice(String voiceId) {
    if (voiceId.startsWith('z')) return 'z';
    if (voiceId.startsWith('a')) return 'a';
    if (voiceId.startsWith('b')) return 'b';
    if (voiceId.startsWith('j')) return 'j';
    if (voiceId.startsWith('e')) return 'e';
    if (voiceId.startsWith('f')) return 'f';
    if (voiceId.startsWith('h')) return 'h';
    if (voiceId.startsWith('i')) return 'i';
    if (voiceId.startsWith('p')) return 'p';
    return 'z';
  }

  Future<String> _resolveModelPath() async {
    return modelPath ?? KokoroModelManager.defaultModelPath();
  }

  /// 关闭服务进程。
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
