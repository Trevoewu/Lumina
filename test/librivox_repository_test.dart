import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/book_sources/librivox_repository.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/domain/models/book_rights.dart';
import 'package:lumina/services/manifest_store.dart';

void main() {
  test('maps LibriVox metadata and playable sections', () {
    final book = LibrivoxBook.fromJson(_bookJson);

    expect(book.id, '47');
    expect(book.title, 'Count of Monte Cristo');
    expect(book.authorLabel, 'Alexandre Dumas');
    expect(book.description, 'A classic adventure. Public domain.');
    expect(book.totalTimeSeconds, 178995);
    expect(book.sections, hasLength(1));
    expect(book.sections.single.listenUrl, endsWith('chapter-1.mp3'));
    expect(book.sections.single.narratorLabel, 'Kristin LeMoine');
    expect(book.canImport, isTrue);
  });

  test('imports remote chapters without generating audio', () async {
    final temp = await Directory.systemTemp.createTemp('librivox_import_');
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final manifests = ManifestStore(documentsDirectory: () async => temp);
    addTearDown(() async {
      await database.close();
      await temp.delete(recursive: true);
    });

    final imported = await LibrivoxRepository().importAudiobook(
      book: LibrivoxBook.fromJson(_bookJson),
      database: database,
      manifestStore: manifests,
      appDir: temp.path,
    );

    expect(imported.externalSource, librivoxSourceId);
    expect(imported.rightsStatus, publicDomainRightsStatus);
    expect(imported.chapterCount, 1);
    final chapters = await database.getChapters(imported.id);
    final manifest = await manifests.load(imported.id, chapters.single.id);
    expect(manifest, isNotNull);
    expect(manifest!.providerId, librivoxSourceId);
    expect(manifest.segments.single.audioFile, endsWith('chapter-1.mp3'));
    expect(manifest.segments.single.state.name, 'ready');
  });
}

final _bookJson = <String, dynamic>{
  'id': '47',
  'title': 'Count of Monte Cristo',
  'description': 'A classic adventure.<br />Public domain.',
  'language': 'English',
  'totaltimesecs': '178995',
  'url_librivox': 'https://librivox.org/example',
  'authors': [
    {'first_name': 'Alexandre', 'last_name': 'Dumas'},
  ],
  'sections': [
    {
      'id': '121010',
      'section_number': '1',
      'title': 'Marseilles–The Arrival',
      'listen_url': 'https://archive.org/download/book/chapter-1.mp3',
      'playtime': '1179',
      'readers': [
        {'display_name': 'Kristin LeMoine'},
      ],
    },
  ],
};
