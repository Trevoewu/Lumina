import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

class ResumableDownloadSource {
  final String name;
  final String url;

  const ResumableDownloadSource({required this.name, required this.url});
}

class ResumableFileDownloader {
  const ResumableFileDownloader._();

  static Future<void> download({
    required Dio dio,
    required List<ResumableDownloadSource> sources,
    required File output,
    required int expectedBytes,
    required CancelToken cancelToken,
    required void Function(int downloadedBytes, String sourceName) onProgress,
    void Function(ResumableDownloadSource source, Object error)? onSourceError,
  }) async {
    await output.parent.create(recursive: true);
    Object? lastError;

    for (final source in sources) {
      try {
        var existingBytes = await _existingBytes(output, expectedBytes);
        if (existingBytes >= expectedBytes) {
          onProgress(expectedBytes, source.name);
          return;
        }

        final response = await dio.get<ResponseBody>(
          source.url,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            headers: existingBytes > 0
                ? {'range': 'bytes=$existingBytes-'}
                : null,
            validateStatus: (status) =>
                status == HttpStatus.ok ||
                status == HttpStatus.partialContent ||
                status == HttpStatus.requestedRangeNotSatisfiable,
          ),
        );

        final body = response.data;
        if (body == null) throw StateError('下载响应为空');

        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
          existingBytes = await _existingBytes(output, expectedBytes);
          if (existingBytes >= expectedBytes) {
            onProgress(expectedBytes, source.name);
            return;
          }
          await output.writeAsBytes(const [], flush: true);
          throw StateError('服务器拒绝续传范围，已重置部分文件');
        }

        var canAppend =
            existingBytes > 0 &&
            response.statusCode == HttpStatus.partialContent;
        if (canAppend) {
          final contentRange = response.headers.value('content-range');
          final match = contentRange == null
              ? null
              : RegExp(r'^bytes (\d+)-').firstMatch(contentRange);
          final rangeStart = int.tryParse(match?.group(1) ?? '');
          if (rangeStart == 0) {
            canAppend = false;
          } else if (rangeStart != existingBytes) {
            throw StateError(
              '服务器返回了错误的续传范围：$contentRange，预期从 $existingBytes 开始',
            );
          }
        }
        final initialBytes = canAppend ? existingBytes : 0;
        final sink = await output.open(
          mode: canAppend ? FileMode.append : FileMode.write,
        );
        var receivedBytes = initialBytes;
        try {
          onProgress(receivedBytes, source.name);
          await for (final chunk in body.stream) {
            await sink.writeFrom(chunk);
            receivedBytes += chunk.length;
            onProgress(receivedBytes, source.name);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        final length = await output.length();
        if (length < expectedBytes) {
          throw StateError('下载不完整：$length/$expectedBytes bytes');
        }
        onProgress(expectedBytes, source.name);
        return;
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) rethrow;
        lastError = error;
        onSourceError?.call(source, error);
      } catch (error) {
        lastError = error;
        onSourceError?.call(source, error);
      }
    }

    if (lastError is DioException) throw lastError;
    throw StateError('所有下载源均失败：$lastError');
  }

  static Future<int> downloadedBytes(
    Directory root,
    Iterable<({String path, int expectedBytes})> files,
  ) async {
    if (!await root.exists()) return 0;
    var total = 0;
    for (final spec in files) {
      final file = File(p.join(root.path, spec.path));
      if (!await file.exists()) continue;
      final length = await file.length();
      total += length.clamp(0, spec.expectedBytes);
    }
    return total;
  }

  static Future<int> _existingBytes(File output, int expectedBytes) async {
    if (!await output.exists()) return 0;
    final length = await output.length();
    if (length > expectedBytes) {
      await output.writeAsBytes(const [], flush: true);
      return 0;
    }
    return length;
  }
}
