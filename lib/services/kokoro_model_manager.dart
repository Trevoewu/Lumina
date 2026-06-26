import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum KokoroModelInstallState {
  unknown,
  notInstalled,
  downloading,
  installed,
  failed,
}

class KokoroModelStatus {
  final KokoroModelInstallState state;
  final String? modelPath;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String? message;

  const KokoroModelStatus({
    required this.state,
    this.modelPath,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = KokoroModelManager.totalDownloadBytes,
    this.message,
  });

  bool get isDownloading => state == KokoroModelInstallState.downloading;
  bool get isInstalled => state == KokoroModelInstallState.installed;
}

abstract class LocalTtsModelManager {
  String get displayName;
  String get repositoryId;
  String get sourceLabel;
  int get downloadBytes;
  KokoroModelStatus get status;
  Stream<KokoroModelStatus> get statusStream;

  Future<void> download();
  Future<void> redownload();
  Future<void> deleteModel();
  void cancel();
}

class KokoroModelFile {
  final String path;
  final int size;

  const KokoroModelFile(this.path, this.size);
}

class KokoroModelSource {
  final String name;
  final String baseUrl;

  const KokoroModelSource({required this.name, required this.baseUrl});
}

class KokoroModelManager implements LocalTtsModelManager {
  static const repoId = 'mlx-community/Kokoro-82M-bf16';
  static const revision = 'main';
  static const modelDirectoryName = 'Kokoro-82M-bf16';
  static const sources = <KokoroModelSource>[
    KokoroModelSource(
      name: 'ModelScope',
      baseUrl: 'https://modelscope.cn/models/$repoId/resolve/master',
    ),
    KokoroModelSource(
      name: 'Hugging Face',
      baseUrl: 'https://huggingface.co/$repoId/resolve/$revision',
    ),
  ];

  static const files = <KokoroModelFile>[
    KokoroModelFile('config.json', 2351),
    KokoroModelFile('kokoro-v1_0.safetensors', 327115152),
    KokoroModelFile('voices/af_heart.pt', 523425),
    KokoroModelFile('voices/af_heart.safetensors', 522320),
    KokoroModelFile('voices/af_bella.pt', 523425),
    KokoroModelFile('voices/af_bella.safetensors', 522320),
    KokoroModelFile('voices/af_nova.pt', 523420),
    KokoroModelFile('voices/af_nova.safetensors', 522320),
    KokoroModelFile('voices/am_adam.pt', 523420),
    KokoroModelFile('voices/am_adam.safetensors', 522320),
    KokoroModelFile('voices/am_eric.pt', 523420),
    KokoroModelFile('voices/am_eric.safetensors', 522320),
    KokoroModelFile('voices/zf_xiaoxiao.pt', 523440),
    KokoroModelFile('voices/zf_xiaoxiao.safetensors', 522320),
  ];

  static const totalDownloadBytes = 333391973;

  final Dio _dio;
  final _statusController = StreamController<KokoroModelStatus>.broadcast();
  CancelToken? _cancelToken;

  KokoroModelStatus _status = const KokoroModelStatus(
    state: KokoroModelInstallState.unknown,
    message: '正在检查模型状态',
  );

  KokoroModelManager({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: Duration.zero,
            ),
          ) {
    unawaited(refresh());
  }

  @override
  KokoroModelStatus get status => _status;

  @override
  Stream<KokoroModelStatus> get statusStream => _statusController.stream;

  @override
  String get displayName => 'Kokoro 本地模型';

  @override
  String get repositoryId => repoId;

  @override
  String get sourceLabel => 'ModelScope / Hugging Face';

  @override
  int get downloadBytes => totalDownloadBytes;

  static Future<String> defaultModelPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(
      dir.path,
      'models',
      'kokoro',
      'mlx-community',
      modelDirectoryName,
    );
  }

  Future<Directory> modelDirectory() async {
    return Directory(await defaultModelPath());
  }

  Future<bool> isInstalled() async {
    final dir = await modelDirectory();
    if (!await dir.exists()) return false;

    for (final file in files) {
      final target = File(p.join(dir.path, file.path));
      if (!await target.exists()) return false;
      if (await target.length() <= 0) return false;
    }
    return true;
  }

  Future<void> refresh() async {
    final path = await defaultModelPath();
    final installed = await isInstalled();
    _emit(
      KokoroModelStatus(
        state: installed
            ? KokoroModelInstallState.installed
            : KokoroModelInstallState.notInstalled,
        modelPath: path,
        progress: installed ? 1 : 0,
        downloadedBytes: installed ? totalDownloadBytes : 0,
        message: installed ? '模型已安装' : '模型未安装',
      ),
    );
  }

  @override
  Future<void> download() async {
    if (_status.isDownloading) return;
    if (await isInstalled()) {
      await refresh();
      return;
    }

    await _download(replaceExisting: false);
  }

  @override
  Future<void> redownload() async {
    if (_status.isDownloading) return;
    await _download(replaceExisting: true);
  }

  Future<void> _download({required bool replaceExisting}) async {
    if (_status.isDownloading) return;

    _cancelToken = CancelToken();
    final targetDir = await modelDirectory();
    final partialDir = Directory('${targetDir.path}.partial');

    try {
      if (!replaceExisting && await isInstalled()) {
        await refresh();
        return;
      }

      if (await partialDir.exists()) {
        await partialDir.delete(recursive: true);
      }
      await partialDir.create(recursive: true);

      var completedBytes = 0;
      _emit(
        KokoroModelStatus(
          state: KokoroModelInstallState.downloading,
          modelPath: targetDir.path,
          progress: 0,
          message: '开始下载 Kokoro 模型',
        ),
      );

      for (final modelFile in files) {
        final output = File(p.join(partialDir.path, modelFile.path));
        await output.parent.create(recursive: true);

        await _downloadFile(
          modelFile,
          output,
          onProgress: (received, sourceName) {
            final downloaded = completedBytes + received;
            _emit(
              KokoroModelStatus(
                state: KokoroModelInstallState.downloading,
                modelPath: targetDir.path,
                progress: (downloaded / totalDownloadBytes).clamp(0, 1),
                downloadedBytes: downloaded,
                message: '正在从 $sourceName 下载 ${modelFile.path}',
              ),
            );
          },
        );

        completedBytes += modelFile.size;
      }

      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await partialDir.rename(targetDir.path);

      await refresh();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _emit(
          KokoroModelStatus(
            state: KokoroModelInstallState.notInstalled,
            modelPath: targetDir.path,
            message: '下载已取消',
          ),
        );
        return;
      }
      _emit(
        KokoroModelStatus(
          state: KokoroModelInstallState.failed,
          modelPath: targetDir.path,
          message: '下载失败：${_describeDioError(e)}',
        ),
      );
    } catch (e) {
      _emit(
        KokoroModelStatus(
          state: KokoroModelInstallState.failed,
          modelPath: targetDir.path,
          message: '下载失败：$e',
        ),
      );
    } finally {
      _cancelToken = null;
    }
  }

  @override
  Future<void> deleteModel() async {
    cancel();
    final targetDir = await modelDirectory();
    final partialDir = Directory('${targetDir.path}.partial');
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    if (await partialDir.exists()) {
      await partialDir.delete(recursive: true);
    }
    await refresh();
  }

  @override
  void cancel() {
    _cancelToken?.cancel('cancelled by user');
  }

  void dispose() {
    cancel();
    unawaited(_statusController.close());
  }

  Future<void> _downloadFile(
    KokoroModelFile modelFile,
    File output, {
    required void Function(int received, String sourceName) onProgress,
  }) async {
    Object? lastError;
    for (final source in sources) {
      final url = '${source.baseUrl}/${modelFile.path}';
      try {
        if (await output.exists()) {
          await output.delete();
        }
        await _dio.download(
          url,
          output.path,
          cancelToken: _cancelToken,
          deleteOnError: true,
          onReceiveProgress: (received, _) {
            onProgress(received, source.name);
          },
        );
        final length = await output.length();
        if (length <= 0) {
          throw StateError('${modelFile.path} 下载后文件为空');
        }
        if (length < modelFile.size) {
          throw StateError(
            '${modelFile.path} 下载不完整：$length/${modelFile.size} bytes',
          );
        }
        return;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        lastError = e;
        debugPrint(
          '[KokoroModelManager] ${source.name} failed: '
          'url=$url type=${e.type.name} message=${e.message} error=${e.error}',
        );
        continue;
      } catch (e) {
        lastError = e;
        debugPrint('[KokoroModelManager] ${source.name} failed: $url $e');
        continue;
      }
    }

    if (lastError is DioException) {
      throw lastError;
    }
    throw StateError('所有下载源均失败：$lastError');
  }

  String _describeDioError(DioException e) {
    final parts = <String>[e.type.name];
    final message = e.message;
    if (message != null && message.isNotEmpty && message != 'unknown') {
      parts.add(message);
    }
    final error = e.error;
    if (error != null) {
      parts.add(error.toString());
    }
    final statusCode = e.response?.statusCode;
    if (statusCode != null) {
      parts.add('HTTP $statusCode');
    }
    return parts.join(' · ');
  }

  void _emit(KokoroModelStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
}
