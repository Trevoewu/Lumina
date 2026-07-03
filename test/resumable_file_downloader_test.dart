import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/resumable_file_downloader.dart';

void main() {
  test('resumes an interrupted file with an HTTP range request', () async {
    final bytes = List<int>.generate(256 * 1024, (index) => index % 251);
    final ranges = <String?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      ranges.add(range);
      final start = range == null
          ? 0
          : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      request.response.statusCode = range == null
          ? HttpStatus.ok
          : HttpStatus.partialContent;
      request.response.contentLength = bytes.length - start;
      if (range != null) {
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${bytes.length - 1}/${bytes.length}',
        );
      }
      try {
        for (var offset = start; offset < bytes.length; offset += 4096) {
          final end = (offset + 4096).clamp(0, bytes.length);
          request.response.add(bytes.sublist(offset, end));
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      } catch (_) {
        // The first request is intentionally cancelled by the client.
      } finally {
        await request.response.close();
      }
    });

    final temp = await Directory.systemTemp.createTemp('lumina-resume-test');
    addTearDown(() => temp.delete(recursive: true));
    final output = File('${temp.path}/model.bin');
    final source = ResumableDownloadSource(
      name: 'test',
      url: 'http://${server.address.host}:${server.port}/model.bin',
    );
    final dio = Dio();
    final firstToken = CancelToken();

    await expectLater(
      ResumableFileDownloader.download(
        dio: dio,
        sources: [source],
        output: output,
        expectedBytes: bytes.length,
        cancelToken: firstToken,
        onProgress: (received, _) {
          if (received >= 16 * 1024 && !firstToken.isCancelled) {
            firstToken.cancel('test interruption');
          }
        },
      ),
      throwsA(isA<DioException>()),
    );

    final partialLength = await output.length();
    expect(partialLength, greaterThan(0));
    expect(partialLength, lessThan(bytes.length));

    await ResumableFileDownloader.download(
      dio: dio,
      sources: [source],
      output: output,
      expectedBytes: bytes.length,
      cancelToken: CancelToken(),
      onProgress: (_, _) {},
    );

    expect(ranges, hasLength(2));
    expect(ranges.last, 'bytes=$partialLength-');
    expect(await output.readAsBytes(), orderedEquals(bytes));
  });

  test(
    'counts persisted partial files without exceeding expected sizes',
    () async {
      final temp = await Directory.systemTemp.createTemp('lumina-count-test');
      addTearDown(() => temp.delete(recursive: true));
      await File('${temp.path}/a.bin').writeAsBytes(List.filled(4, 1));
      await File('${temp.path}/b.bin').writeAsBytes(List.filled(12, 2));

      final downloaded = await ResumableFileDownloader.downloadedBytes(temp, [
        (path: 'a.bin', expectedBytes: 10),
        (path: 'b.bin', expectedBytes: 8),
        (path: 'missing.bin', expectedBytes: 5),
      ]);

      expect(downloaded, 12);
    },
  );
}
