import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/domain/models/chapter_manifest.dart';
import 'package:lumina/services/manifest_store.dart';

void main() {
  test(
    'recovers the previous manifest checkpoint after an interrupted write',
    () async {
      final temp = await Directory.systemTemp.createTemp('lumina_manifest_');
      final store = ManifestStore(documentsDirectory: () async => temp);
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final initial = _manifest(readyCount: 1);
      final latest = _manifest(readyCount: 2);
      await store.save(initial);
      await store.save(latest);

      final file = await store.manifestFile('book', 'chapter');
      await file.writeAsString('{interrupted');

      final recovered = await store.load('book', 'chapter');

      expect(recovered, isNotNull);
      expect(recovered!.readyCount, 1);
      expect(await store.load('book', 'chapter'), isNotNull);
    },
  );
}

ChapterManifest _manifest({required int readyCount}) {
  return ChapterManifest(
    chapterId: 'chapter',
    bookId: 'book',
    providerId: 'provider',
    voiceId: 'voice',
    speed: 1,
    updatedAt: readyCount,
    segments: [
      for (var index = 0; index < 3; index++)
        SegmentEntry(
          paragraphId: 'p$index',
          audioFile: 'chapter/p$index.mp3',
          durationMs: index < readyCount ? 1000 : 0,
          state: index < readyCount
              ? ParagraphAudioState.ready
              : ParagraphAudioState.notGenerated,
        ),
    ],
  );
}
