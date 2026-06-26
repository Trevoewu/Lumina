import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'kokoro_model_manager.dart';

class FishAudioModelManager implements LocalTtsModelManager {
  static const repoId = 'mlx-community/fish-audio-s2-pro-8bit';
  static const revision = 'main';
  static const modelDirectoryName = 'fish-audio-s2-pro-8bit';
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
    KokoroModelFile('config.json', 2315),
    KokoroModelFile('configuration.json', 72),
    KokoroModelFile('model.safetensors', 4847260185),
    KokoroModelFile('model.safetensors.index.json', 53694),
    KokoroModelFile('codec.safetensors', 1870921167),
    KokoroModelFile('tokenizer.json', 12217872),
    KokoroModelFile('tokenizer_config.json', 860832),
    KokoroModelFile('special_tokens_map.json', 101864),
    KokoroModelFile('README.md', 3535),
  ];

  static const totalDownloadBytes = 6731421536;

  final Dio _dio;
  final _statusController = StreamController<KokoroModelStatus>.broadcast();
  CancelToken? _cancelToken;

  KokoroModelStatus _status = const KokoroModelStatus(
    state: KokoroModelInstallState.unknown,
    totalBytes: totalDownloadBytes,
    message: '正在检查模型状态',
  );

  FishAudioModelManager({Dio? dio})
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
  String get displayName => 'Fish Audio S2 Pro';

  @override
  String get repositoryId => repoId;

  @override
  String get sourceLabel => 'ModelScope / Hugging Face';

  @override
  int get downloadBytes => totalDownloadBytes;

  @override
  KokoroModelStatus get status => _status;

  @override
  Stream<KokoroModelStatus> get statusStream => _statusController.stream;

  static Future<String> defaultModelPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(
      dir.path,
      'models',
      'fish-audio',
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
        totalBytes: totalDownloadBytes,
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
          totalBytes: totalDownloadBytes,
          message: '开始下载 Fish Audio 模型',
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
                totalBytes: totalDownloadBytes,
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
            totalBytes: totalDownloadBytes,
            message: '下载已取消',
          ),
        );
        return;
      }
      _emit(
        KokoroModelStatus(
          state: KokoroModelInstallState.failed,
          modelPath: targetDir.path,
          totalBytes: totalDownloadBytes,
          message: '下载失败：${_describeDioError(e)}',
        ),
      );
    } catch (e) {
      _emit(
        KokoroModelStatus(
          state: KokoroModelInstallState.failed,
          modelPath: targetDir.path,
          totalBytes: totalDownloadBytes,
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
          '[FishAudioModelManager] ${source.name} failed: '
          'url=$url type=${e.type.name} message=${e.message} error=${e.error}',
        );
        continue;
      } catch (e) {
        lastError = e;
        debugPrint('[FishAudioModelManager] ${source.name} failed: $url $e');
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
