import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/presentation/widgets/disk_cached_network_image.dart';
import 'package:lumina/services/image_disk_cache.dart';

void main() {
  testWidgets('reuses a resolved disk image without loading it again', (
    tester,
  ) async {
    final file = File('assets/app_icon/lumina_app_icon_1024.png');
    final cache = _FakeImageDiskCache(file);

    Widget image() => MaterialApp(
      home: Center(
        child: SizedBox.square(
          dimension: 80,
          child: DiskCachedNetworkImage(
            url: 'https://example.com/cover.png',
            cache: cache,
            placeholder: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    await tester.pumpWidget(image());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Image), findsOneWidget);
    expect(cache.loadCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(image());
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(cache.loadCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

class _FakeImageDiskCache implements ImageDiskCache {
  final File file;
  File? cachedFile;
  int loadCalls = 0;

  _FakeImageDiskCache(this.file);

  @override
  File? peek(String url) => cachedFile;

  @override
  Future<File> load(String url) async {
    loadCalls++;
    cachedFile = file;
    return file;
  }

  @override
  Future<void> clear() async {
    cachedFile = null;
  }
}
