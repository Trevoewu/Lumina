// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterCountMeta = const VerificationMeta(
    'chapterCount',
  );
  @override
  late final GeneratedColumn<int> chapterCount = GeneratedColumn<int>(
    'chapter_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _paragraphCountMeta = const VerificationMeta(
    'paragraphCount',
  );
  @override
  late final GeneratedColumn<int> paragraphCount = GeneratedColumn<int>(
    'paragraph_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentChapterIdMeta = const VerificationMeta(
    'currentChapterId',
  );
  @override
  late final GeneratedColumn<String> currentChapterId = GeneratedColumn<String>(
    'current_chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentParagraphIndexMeta =
      const VerificationMeta('currentParagraphIndex');
  @override
  late final GeneratedColumn<int> currentParagraphIndex = GeneratedColumn<int>(
    'current_paragraph_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playbackOffsetMsMeta = const VerificationMeta(
    'playbackOffsetMs',
  );
  @override
  late final GeneratedColumn<int> playbackOffsetMs = GeneratedColumn<int>(
    'playback_offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _voiceIdMeta = const VerificationMeta(
    'voiceId',
  );
  @override
  late final GeneratedColumn<String> voiceId = GeneratedColumn<String>(
    'voice_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<int> importedAt = GeneratedColumn<int>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<int> lastReadAt = GeneratedColumn<int>(
    'last_read_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('book'),
  );
  static const VerificationMeta _externalSourceMeta = const VerificationMeta(
    'externalSource',
  );
  @override
  late final GeneratedColumn<String> externalSource = GeneratedColumn<String>(
    'external_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rightsStatusMeta = const VerificationMeta(
    'rightsStatus',
  );
  @override
  late final GeneratedColumn<String> rightsStatus = GeneratedColumn<String>(
    'rights_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('user_uploaded'),
  );
  static const VerificationMeta _externalMetadataJsonMeta =
      const VerificationMeta('externalMetadataJson');
  @override
  late final GeneratedColumn<String> externalMetadataJson =
      GeneratedColumn<String>(
        'external_metadata_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readingLevelSystemMeta =
      const VerificationMeta('readingLevelSystem');
  @override
  late final GeneratedColumn<String> readingLevelSystem =
      GeneratedColumn<String>(
        'reading_level_system',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _readingLevelCodeMeta = const VerificationMeta(
    'readingLevelCode',
  );
  @override
  late final GeneratedColumn<String> readingLevelCode = GeneratedColumn<String>(
    'reading_level_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readingLevelSourceMeta =
      const VerificationMeta('readingLevelSource');
  @override
  late final GeneratedColumn<String> readingLevelSource =
      GeneratedColumn<String>(
        'reading_level_source',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    format,
    sourcePath,
    coverPath,
    chapterCount,
    paragraphCount,
    currentChapterId,
    currentParagraphIndex,
    playbackOffsetMs,
    voiceId,
    importedAt,
    lastReadAt,
    isRead,
    kind,
    externalSource,
    externalId,
    rightsStatus,
    externalMetadataJson,
    language,
    readingLevelSystem,
    readingLevelCode,
    readingLevelSource,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('chapter_count')) {
      context.handle(
        _chapterCountMeta,
        chapterCount.isAcceptableOrUnknown(
          data['chapter_count']!,
          _chapterCountMeta,
        ),
      );
    }
    if (data.containsKey('paragraph_count')) {
      context.handle(
        _paragraphCountMeta,
        paragraphCount.isAcceptableOrUnknown(
          data['paragraph_count']!,
          _paragraphCountMeta,
        ),
      );
    }
    if (data.containsKey('current_chapter_id')) {
      context.handle(
        _currentChapterIdMeta,
        currentChapterId.isAcceptableOrUnknown(
          data['current_chapter_id']!,
          _currentChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('current_paragraph_index')) {
      context.handle(
        _currentParagraphIndexMeta,
        currentParagraphIndex.isAcceptableOrUnknown(
          data['current_paragraph_index']!,
          _currentParagraphIndexMeta,
        ),
      );
    }
    if (data.containsKey('playback_offset_ms')) {
      context.handle(
        _playbackOffsetMsMeta,
        playbackOffsetMs.isAcceptableOrUnknown(
          data['playback_offset_ms']!,
          _playbackOffsetMsMeta,
        ),
      );
    }
    if (data.containsKey('voice_id')) {
      context.handle(
        _voiceIdMeta,
        voiceId.isAcceptableOrUnknown(data['voice_id']!, _voiceIdMeta),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('external_source')) {
      context.handle(
        _externalSourceMeta,
        externalSource.isAcceptableOrUnknown(
          data['external_source']!,
          _externalSourceMeta,
        ),
      );
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    }
    if (data.containsKey('rights_status')) {
      context.handle(
        _rightsStatusMeta,
        rightsStatus.isAcceptableOrUnknown(
          data['rights_status']!,
          _rightsStatusMeta,
        ),
      );
    }
    if (data.containsKey('external_metadata_json')) {
      context.handle(
        _externalMetadataJsonMeta,
        externalMetadataJson.isAcceptableOrUnknown(
          data['external_metadata_json']!,
          _externalMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('reading_level_system')) {
      context.handle(
        _readingLevelSystemMeta,
        readingLevelSystem.isAcceptableOrUnknown(
          data['reading_level_system']!,
          _readingLevelSystemMeta,
        ),
      );
    }
    if (data.containsKey('reading_level_code')) {
      context.handle(
        _readingLevelCodeMeta,
        readingLevelCode.isAcceptableOrUnknown(
          data['reading_level_code']!,
          _readingLevelCodeMeta,
        ),
      );
    }
    if (data.containsKey('reading_level_source')) {
      context.handle(
        _readingLevelSourceMeta,
        readingLevelSource.isAcceptableOrUnknown(
          data['reading_level_source']!,
          _readingLevelSourceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      chapterCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_count'],
      )!,
      paragraphCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_count'],
      )!,
      currentChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_chapter_id'],
      ),
      currentParagraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_paragraph_index'],
      )!,
      playbackOffsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playback_offset_ms'],
      )!,
      voiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_id'],
      ),
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at'],
      )!,
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_at'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      externalSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_source'],
      ),
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      ),
      rightsStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rights_status'],
      )!,
      externalMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_metadata_json'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      readingLevelSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_level_system'],
      ),
      readingLevelCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_level_code'],
      ),
      readingLevelSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_level_source'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final String id;
  final String title;
  final String? author;
  final String format;
  final String sourcePath;
  final String? coverPath;
  final int chapterCount;
  final int paragraphCount;
  final String? currentChapterId;
  final int currentParagraphIndex;
  final int playbackOffsetMs;
  final String? voiceId;
  final int importedAt;
  final int lastReadAt;
  final bool isRead;
  final String kind;
  final String? externalSource;
  final String? externalId;
  final String rightsStatus;
  final String? externalMetadataJson;
  final String? language;
  final String? readingLevelSystem;
  final String? readingLevelCode;
  final String? readingLevelSource;
  const Book({
    required this.id,
    required this.title,
    this.author,
    required this.format,
    required this.sourcePath,
    this.coverPath,
    required this.chapterCount,
    required this.paragraphCount,
    this.currentChapterId,
    required this.currentParagraphIndex,
    required this.playbackOffsetMs,
    this.voiceId,
    required this.importedAt,
    required this.lastReadAt,
    required this.isRead,
    required this.kind,
    this.externalSource,
    this.externalId,
    required this.rightsStatus,
    this.externalMetadataJson,
    this.language,
    this.readingLevelSystem,
    this.readingLevelCode,
    this.readingLevelSource,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['format'] = Variable<String>(format);
    map['source_path'] = Variable<String>(sourcePath);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['chapter_count'] = Variable<int>(chapterCount);
    map['paragraph_count'] = Variable<int>(paragraphCount);
    if (!nullToAbsent || currentChapterId != null) {
      map['current_chapter_id'] = Variable<String>(currentChapterId);
    }
    map['current_paragraph_index'] = Variable<int>(currentParagraphIndex);
    map['playback_offset_ms'] = Variable<int>(playbackOffsetMs);
    if (!nullToAbsent || voiceId != null) {
      map['voice_id'] = Variable<String>(voiceId);
    }
    map['imported_at'] = Variable<int>(importedAt);
    map['last_read_at'] = Variable<int>(lastReadAt);
    map['is_read'] = Variable<bool>(isRead);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || externalSource != null) {
      map['external_source'] = Variable<String>(externalSource);
    }
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
    }
    map['rights_status'] = Variable<String>(rightsStatus);
    if (!nullToAbsent || externalMetadataJson != null) {
      map['external_metadata_json'] = Variable<String>(externalMetadataJson);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || readingLevelSystem != null) {
      map['reading_level_system'] = Variable<String>(readingLevelSystem);
    }
    if (!nullToAbsent || readingLevelCode != null) {
      map['reading_level_code'] = Variable<String>(readingLevelCode);
    }
    if (!nullToAbsent || readingLevelSource != null) {
      map['reading_level_source'] = Variable<String>(readingLevelSource);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      format: Value(format),
      sourcePath: Value(sourcePath),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      chapterCount: Value(chapterCount),
      paragraphCount: Value(paragraphCount),
      currentChapterId: currentChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentChapterId),
      currentParagraphIndex: Value(currentParagraphIndex),
      playbackOffsetMs: Value(playbackOffsetMs),
      voiceId: voiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceId),
      importedAt: Value(importedAt),
      lastReadAt: Value(lastReadAt),
      isRead: Value(isRead),
      kind: Value(kind),
      externalSource: externalSource == null && nullToAbsent
          ? const Value.absent()
          : Value(externalSource),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
      rightsStatus: Value(rightsStatus),
      externalMetadataJson: externalMetadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(externalMetadataJson),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      readingLevelSystem: readingLevelSystem == null && nullToAbsent
          ? const Value.absent()
          : Value(readingLevelSystem),
      readingLevelCode: readingLevelCode == null && nullToAbsent
          ? const Value.absent()
          : Value(readingLevelCode),
      readingLevelSource: readingLevelSource == null && nullToAbsent
          ? const Value.absent()
          : Value(readingLevelSource),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      format: serializer.fromJson<String>(json['format']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      chapterCount: serializer.fromJson<int>(json['chapterCount']),
      paragraphCount: serializer.fromJson<int>(json['paragraphCount']),
      currentChapterId: serializer.fromJson<String?>(json['currentChapterId']),
      currentParagraphIndex: serializer.fromJson<int>(
        json['currentParagraphIndex'],
      ),
      playbackOffsetMs: serializer.fromJson<int>(json['playbackOffsetMs']),
      voiceId: serializer.fromJson<String?>(json['voiceId']),
      importedAt: serializer.fromJson<int>(json['importedAt']),
      lastReadAt: serializer.fromJson<int>(json['lastReadAt']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      kind: serializer.fromJson<String>(json['kind']),
      externalSource: serializer.fromJson<String?>(json['externalSource']),
      externalId: serializer.fromJson<String?>(json['externalId']),
      rightsStatus: serializer.fromJson<String>(json['rightsStatus']),
      externalMetadataJson: serializer.fromJson<String?>(
        json['externalMetadataJson'],
      ),
      language: serializer.fromJson<String?>(json['language']),
      readingLevelSystem: serializer.fromJson<String?>(
        json['readingLevelSystem'],
      ),
      readingLevelCode: serializer.fromJson<String?>(json['readingLevelCode']),
      readingLevelSource: serializer.fromJson<String?>(
        json['readingLevelSource'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'format': serializer.toJson<String>(format),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'coverPath': serializer.toJson<String?>(coverPath),
      'chapterCount': serializer.toJson<int>(chapterCount),
      'paragraphCount': serializer.toJson<int>(paragraphCount),
      'currentChapterId': serializer.toJson<String?>(currentChapterId),
      'currentParagraphIndex': serializer.toJson<int>(currentParagraphIndex),
      'playbackOffsetMs': serializer.toJson<int>(playbackOffsetMs),
      'voiceId': serializer.toJson<String?>(voiceId),
      'importedAt': serializer.toJson<int>(importedAt),
      'lastReadAt': serializer.toJson<int>(lastReadAt),
      'isRead': serializer.toJson<bool>(isRead),
      'kind': serializer.toJson<String>(kind),
      'externalSource': serializer.toJson<String?>(externalSource),
      'externalId': serializer.toJson<String?>(externalId),
      'rightsStatus': serializer.toJson<String>(rightsStatus),
      'externalMetadataJson': serializer.toJson<String?>(externalMetadataJson),
      'language': serializer.toJson<String?>(language),
      'readingLevelSystem': serializer.toJson<String?>(readingLevelSystem),
      'readingLevelCode': serializer.toJson<String?>(readingLevelCode),
      'readingLevelSource': serializer.toJson<String?>(readingLevelSource),
    };
  }

  Book copyWith({
    String? id,
    String? title,
    Value<String?> author = const Value.absent(),
    String? format,
    String? sourcePath,
    Value<String?> coverPath = const Value.absent(),
    int? chapterCount,
    int? paragraphCount,
    Value<String?> currentChapterId = const Value.absent(),
    int? currentParagraphIndex,
    int? playbackOffsetMs,
    Value<String?> voiceId = const Value.absent(),
    int? importedAt,
    int? lastReadAt,
    bool? isRead,
    String? kind,
    Value<String?> externalSource = const Value.absent(),
    Value<String?> externalId = const Value.absent(),
    String? rightsStatus,
    Value<String?> externalMetadataJson = const Value.absent(),
    Value<String?> language = const Value.absent(),
    Value<String?> readingLevelSystem = const Value.absent(),
    Value<String?> readingLevelCode = const Value.absent(),
    Value<String?> readingLevelSource = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    format: format ?? this.format,
    sourcePath: sourcePath ?? this.sourcePath,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    chapterCount: chapterCount ?? this.chapterCount,
    paragraphCount: paragraphCount ?? this.paragraphCount,
    currentChapterId: currentChapterId.present
        ? currentChapterId.value
        : this.currentChapterId,
    currentParagraphIndex: currentParagraphIndex ?? this.currentParagraphIndex,
    playbackOffsetMs: playbackOffsetMs ?? this.playbackOffsetMs,
    voiceId: voiceId.present ? voiceId.value : this.voiceId,
    importedAt: importedAt ?? this.importedAt,
    lastReadAt: lastReadAt ?? this.lastReadAt,
    isRead: isRead ?? this.isRead,
    kind: kind ?? this.kind,
    externalSource: externalSource.present
        ? externalSource.value
        : this.externalSource,
    externalId: externalId.present ? externalId.value : this.externalId,
    rightsStatus: rightsStatus ?? this.rightsStatus,
    externalMetadataJson: externalMetadataJson.present
        ? externalMetadataJson.value
        : this.externalMetadataJson,
    language: language.present ? language.value : this.language,
    readingLevelSystem: readingLevelSystem.present
        ? readingLevelSystem.value
        : this.readingLevelSystem,
    readingLevelCode: readingLevelCode.present
        ? readingLevelCode.value
        : this.readingLevelCode,
    readingLevelSource: readingLevelSource.present
        ? readingLevelSource.value
        : this.readingLevelSource,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      format: data.format.present ? data.format.value : this.format,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      chapterCount: data.chapterCount.present
          ? data.chapterCount.value
          : this.chapterCount,
      paragraphCount: data.paragraphCount.present
          ? data.paragraphCount.value
          : this.paragraphCount,
      currentChapterId: data.currentChapterId.present
          ? data.currentChapterId.value
          : this.currentChapterId,
      currentParagraphIndex: data.currentParagraphIndex.present
          ? data.currentParagraphIndex.value
          : this.currentParagraphIndex,
      playbackOffsetMs: data.playbackOffsetMs.present
          ? data.playbackOffsetMs.value
          : this.playbackOffsetMs,
      voiceId: data.voiceId.present ? data.voiceId.value : this.voiceId,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      kind: data.kind.present ? data.kind.value : this.kind,
      externalSource: data.externalSource.present
          ? data.externalSource.value
          : this.externalSource,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      rightsStatus: data.rightsStatus.present
          ? data.rightsStatus.value
          : this.rightsStatus,
      externalMetadataJson: data.externalMetadataJson.present
          ? data.externalMetadataJson.value
          : this.externalMetadataJson,
      language: data.language.present ? data.language.value : this.language,
      readingLevelSystem: data.readingLevelSystem.present
          ? data.readingLevelSystem.value
          : this.readingLevelSystem,
      readingLevelCode: data.readingLevelCode.present
          ? data.readingLevelCode.value
          : this.readingLevelCode,
      readingLevelSource: data.readingLevelSource.present
          ? data.readingLevelSource.value
          : this.readingLevelSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('paragraphCount: $paragraphCount, ')
          ..write('currentChapterId: $currentChapterId, ')
          ..write('currentParagraphIndex: $currentParagraphIndex, ')
          ..write('playbackOffsetMs: $playbackOffsetMs, ')
          ..write('voiceId: $voiceId, ')
          ..write('importedAt: $importedAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('isRead: $isRead, ')
          ..write('kind: $kind, ')
          ..write('externalSource: $externalSource, ')
          ..write('externalId: $externalId, ')
          ..write('rightsStatus: $rightsStatus, ')
          ..write('externalMetadataJson: $externalMetadataJson, ')
          ..write('language: $language, ')
          ..write('readingLevelSystem: $readingLevelSystem, ')
          ..write('readingLevelCode: $readingLevelCode, ')
          ..write('readingLevelSource: $readingLevelSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    author,
    format,
    sourcePath,
    coverPath,
    chapterCount,
    paragraphCount,
    currentChapterId,
    currentParagraphIndex,
    playbackOffsetMs,
    voiceId,
    importedAt,
    lastReadAt,
    isRead,
    kind,
    externalSource,
    externalId,
    rightsStatus,
    externalMetadataJson,
    language,
    readingLevelSystem,
    readingLevelCode,
    readingLevelSource,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.format == this.format &&
          other.sourcePath == this.sourcePath &&
          other.coverPath == this.coverPath &&
          other.chapterCount == this.chapterCount &&
          other.paragraphCount == this.paragraphCount &&
          other.currentChapterId == this.currentChapterId &&
          other.currentParagraphIndex == this.currentParagraphIndex &&
          other.playbackOffsetMs == this.playbackOffsetMs &&
          other.voiceId == this.voiceId &&
          other.importedAt == this.importedAt &&
          other.lastReadAt == this.lastReadAt &&
          other.isRead == this.isRead &&
          other.kind == this.kind &&
          other.externalSource == this.externalSource &&
          other.externalId == this.externalId &&
          other.rightsStatus == this.rightsStatus &&
          other.externalMetadataJson == this.externalMetadataJson &&
          other.language == this.language &&
          other.readingLevelSystem == this.readingLevelSystem &&
          other.readingLevelCode == this.readingLevelCode &&
          other.readingLevelSource == this.readingLevelSource);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> author;
  final Value<String> format;
  final Value<String> sourcePath;
  final Value<String?> coverPath;
  final Value<int> chapterCount;
  final Value<int> paragraphCount;
  final Value<String?> currentChapterId;
  final Value<int> currentParagraphIndex;
  final Value<int> playbackOffsetMs;
  final Value<String?> voiceId;
  final Value<int> importedAt;
  final Value<int> lastReadAt;
  final Value<bool> isRead;
  final Value<String> kind;
  final Value<String?> externalSource;
  final Value<String?> externalId;
  final Value<String> rightsStatus;
  final Value<String?> externalMetadataJson;
  final Value<String?> language;
  final Value<String?> readingLevelSystem;
  final Value<String?> readingLevelCode;
  final Value<String?> readingLevelSource;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.format = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.paragraphCount = const Value.absent(),
    this.currentChapterId = const Value.absent(),
    this.currentParagraphIndex = const Value.absent(),
    this.playbackOffsetMs = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.isRead = const Value.absent(),
    this.kind = const Value.absent(),
    this.externalSource = const Value.absent(),
    this.externalId = const Value.absent(),
    this.rightsStatus = const Value.absent(),
    this.externalMetadataJson = const Value.absent(),
    this.language = const Value.absent(),
    this.readingLevelSystem = const Value.absent(),
    this.readingLevelCode = const Value.absent(),
    this.readingLevelSource = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    this.author = const Value.absent(),
    required String format,
    required String sourcePath,
    this.coverPath = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.paragraphCount = const Value.absent(),
    this.currentChapterId = const Value.absent(),
    this.currentParagraphIndex = const Value.absent(),
    this.playbackOffsetMs = const Value.absent(),
    this.voiceId = const Value.absent(),
    required int importedAt,
    this.lastReadAt = const Value.absent(),
    this.isRead = const Value.absent(),
    this.kind = const Value.absent(),
    this.externalSource = const Value.absent(),
    this.externalId = const Value.absent(),
    this.rightsStatus = const Value.absent(),
    this.externalMetadataJson = const Value.absent(),
    this.language = const Value.absent(),
    this.readingLevelSystem = const Value.absent(),
    this.readingLevelCode = const Value.absent(),
    this.readingLevelSource = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       format = Value(format),
       sourcePath = Value(sourcePath),
       importedAt = Value(importedAt);
  static Insertable<Book> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? format,
    Expression<String>? sourcePath,
    Expression<String>? coverPath,
    Expression<int>? chapterCount,
    Expression<int>? paragraphCount,
    Expression<String>? currentChapterId,
    Expression<int>? currentParagraphIndex,
    Expression<int>? playbackOffsetMs,
    Expression<String>? voiceId,
    Expression<int>? importedAt,
    Expression<int>? lastReadAt,
    Expression<bool>? isRead,
    Expression<String>? kind,
    Expression<String>? externalSource,
    Expression<String>? externalId,
    Expression<String>? rightsStatus,
    Expression<String>? externalMetadataJson,
    Expression<String>? language,
    Expression<String>? readingLevelSystem,
    Expression<String>? readingLevelCode,
    Expression<String>? readingLevelSource,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (format != null) 'format': format,
      if (sourcePath != null) 'source_path': sourcePath,
      if (coverPath != null) 'cover_path': coverPath,
      if (chapterCount != null) 'chapter_count': chapterCount,
      if (paragraphCount != null) 'paragraph_count': paragraphCount,
      if (currentChapterId != null) 'current_chapter_id': currentChapterId,
      if (currentParagraphIndex != null)
        'current_paragraph_index': currentParagraphIndex,
      if (playbackOffsetMs != null) 'playback_offset_ms': playbackOffsetMs,
      if (voiceId != null) 'voice_id': voiceId,
      if (importedAt != null) 'imported_at': importedAt,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (isRead != null) 'is_read': isRead,
      if (kind != null) 'kind': kind,
      if (externalSource != null) 'external_source': externalSource,
      if (externalId != null) 'external_id': externalId,
      if (rightsStatus != null) 'rights_status': rightsStatus,
      if (externalMetadataJson != null)
        'external_metadata_json': externalMetadataJson,
      if (language != null) 'language': language,
      if (readingLevelSystem != null)
        'reading_level_system': readingLevelSystem,
      if (readingLevelCode != null) 'reading_level_code': readingLevelCode,
      if (readingLevelSource != null)
        'reading_level_source': readingLevelSource,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? author,
    Value<String>? format,
    Value<String>? sourcePath,
    Value<String?>? coverPath,
    Value<int>? chapterCount,
    Value<int>? paragraphCount,
    Value<String?>? currentChapterId,
    Value<int>? currentParagraphIndex,
    Value<int>? playbackOffsetMs,
    Value<String?>? voiceId,
    Value<int>? importedAt,
    Value<int>? lastReadAt,
    Value<bool>? isRead,
    Value<String>? kind,
    Value<String?>? externalSource,
    Value<String?>? externalId,
    Value<String>? rightsStatus,
    Value<String?>? externalMetadataJson,
    Value<String?>? language,
    Value<String?>? readingLevelSystem,
    Value<String?>? readingLevelCode,
    Value<String?>? readingLevelSource,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format ?? this.format,
      sourcePath: sourcePath ?? this.sourcePath,
      coverPath: coverPath ?? this.coverPath,
      chapterCount: chapterCount ?? this.chapterCount,
      paragraphCount: paragraphCount ?? this.paragraphCount,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      currentParagraphIndex:
          currentParagraphIndex ?? this.currentParagraphIndex,
      playbackOffsetMs: playbackOffsetMs ?? this.playbackOffsetMs,
      voiceId: voiceId ?? this.voiceId,
      importedAt: importedAt ?? this.importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isRead: isRead ?? this.isRead,
      kind: kind ?? this.kind,
      externalSource: externalSource ?? this.externalSource,
      externalId: externalId ?? this.externalId,
      rightsStatus: rightsStatus ?? this.rightsStatus,
      externalMetadataJson: externalMetadataJson ?? this.externalMetadataJson,
      language: language ?? this.language,
      readingLevelSystem: readingLevelSystem ?? this.readingLevelSystem,
      readingLevelCode: readingLevelCode ?? this.readingLevelCode,
      readingLevelSource: readingLevelSource ?? this.readingLevelSource,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (chapterCount.present) {
      map['chapter_count'] = Variable<int>(chapterCount.value);
    }
    if (paragraphCount.present) {
      map['paragraph_count'] = Variable<int>(paragraphCount.value);
    }
    if (currentChapterId.present) {
      map['current_chapter_id'] = Variable<String>(currentChapterId.value);
    }
    if (currentParagraphIndex.present) {
      map['current_paragraph_index'] = Variable<int>(
        currentParagraphIndex.value,
      );
    }
    if (playbackOffsetMs.present) {
      map['playback_offset_ms'] = Variable<int>(playbackOffsetMs.value);
    }
    if (voiceId.present) {
      map['voice_id'] = Variable<String>(voiceId.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<int>(importedAt.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<int>(lastReadAt.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (externalSource.present) {
      map['external_source'] = Variable<String>(externalSource.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (rightsStatus.present) {
      map['rights_status'] = Variable<String>(rightsStatus.value);
    }
    if (externalMetadataJson.present) {
      map['external_metadata_json'] = Variable<String>(
        externalMetadataJson.value,
      );
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (readingLevelSystem.present) {
      map['reading_level_system'] = Variable<String>(readingLevelSystem.value);
    }
    if (readingLevelCode.present) {
      map['reading_level_code'] = Variable<String>(readingLevelCode.value);
    }
    if (readingLevelSource.present) {
      map['reading_level_source'] = Variable<String>(readingLevelSource.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('paragraphCount: $paragraphCount, ')
          ..write('currentChapterId: $currentChapterId, ')
          ..write('currentParagraphIndex: $currentParagraphIndex, ')
          ..write('playbackOffsetMs: $playbackOffsetMs, ')
          ..write('voiceId: $voiceId, ')
          ..write('importedAt: $importedAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('isRead: $isRead, ')
          ..write('kind: $kind, ')
          ..write('externalSource: $externalSource, ')
          ..write('externalId: $externalId, ')
          ..write('rightsStatus: $rightsStatus, ')
          ..write('externalMetadataJson: $externalMetadataJson, ')
          ..write('language: $language, ')
          ..write('readingLevelSystem: $readingLevelSystem, ')
          ..write('readingLevelCode: $readingLevelCode, ')
          ..write('readingLevelSource: $readingLevelSource, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textOffsetMeta = const VerificationMeta(
    'textOffset',
  );
  @override
  late final GeneratedColumn<int> textOffset = GeneratedColumn<int>(
    'text_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _voiceIdMeta = const VerificationMeta(
    'voiceId',
  );
  @override
  late final GeneratedColumn<String> voiceId = GeneratedColumn<String>(
    'voice_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    title,
    textOffset,
    voiceId,
    isHidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('text_offset')) {
      context.handle(
        _textOffsetMeta,
        textOffset.isAcceptableOrUnknown(data['text_offset']!, _textOffsetMeta),
      );
    }
    if (data.containsKey('voice_id')) {
      context.handle(
        _voiceIdMeta,
        voiceId.isAcceptableOrUnknown(data['voice_id']!, _voiceIdMeta),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, chapterIndex},
  ];
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      textOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}text_offset'],
      )!,
      voiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_id'],
      ),
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String title;
  final int textOffset;

  /// Optional narrator override for this chapter.
  final String? voiceId;

  /// Hidden chapters remain in the database and can be restored later.
  final bool isHidden;
  const Chapter({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.title,
    required this.textOffset,
    this.voiceId,
    required this.isHidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['title'] = Variable<String>(title);
    map['text_offset'] = Variable<int>(textOffset);
    if (!nullToAbsent || voiceId != null) {
      map['voice_id'] = Variable<String>(voiceId);
    }
    map['is_hidden'] = Variable<bool>(isHidden);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      title: Value(title),
      textOffset: Value(textOffset),
      voiceId: voiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceId),
      isHidden: Value(isHidden),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      title: serializer.fromJson<String>(json['title']),
      textOffset: serializer.fromJson<int>(json['textOffset']),
      voiceId: serializer.fromJson<String?>(json['voiceId']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'title': serializer.toJson<String>(title),
      'textOffset': serializer.toJson<int>(textOffset),
      'voiceId': serializer.toJson<String?>(voiceId),
      'isHidden': serializer.toJson<bool>(isHidden),
    };
  }

  Chapter copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? title,
    int? textOffset,
    Value<String?> voiceId = const Value.absent(),
    bool? isHidden,
  }) => Chapter(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    title: title ?? this.title,
    textOffset: textOffset ?? this.textOffset,
    voiceId: voiceId.present ? voiceId.value : this.voiceId,
    isHidden: isHidden ?? this.isHidden,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      title: data.title.present ? data.title.value : this.title,
      textOffset: data.textOffset.present
          ? data.textOffset.value
          : this.textOffset,
      voiceId: data.voiceId.present ? data.voiceId.value : this.voiceId,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title, ')
          ..write('textOffset: $textOffset, ')
          ..write('voiceId: $voiceId, ')
          ..write('isHidden: $isHidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    title,
    textOffset,
    voiceId,
    isHidden,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.title == this.title &&
          other.textOffset == this.textOffset &&
          other.voiceId == this.voiceId &&
          other.isHidden == this.isHidden);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<String> title;
  final Value<int> textOffset;
  final Value<String?> voiceId;
  final Value<bool> isHidden;
  final Value<int> rowid;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.title = const Value.absent(),
    this.textOffset = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChaptersCompanion.insert({
    required String id,
    required String bookId,
    required int chapterIndex,
    required String title,
    this.textOffset = const Value.absent(),
    this.voiceId = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       title = Value(title);
  static Insertable<Chapter> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<String>? title,
    Expression<int>? textOffset,
    Expression<String>? voiceId,
    Expression<bool>? isHidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (title != null) 'title': title,
      if (textOffset != null) 'text_offset': textOffset,
      if (voiceId != null) 'voice_id': voiceId,
      if (isHidden != null) 'is_hidden': isHidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChaptersCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<String>? title,
    Value<int>? textOffset,
    Value<String?>? voiceId,
    Value<bool>? isHidden,
    Value<int>? rowid,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      textOffset: textOffset ?? this.textOffset,
      voiceId: voiceId ?? this.voiceId,
      isHidden: isHidden ?? this.isHidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (textOffset.present) {
      map['text_offset'] = Variable<int>(textOffset.value);
    }
    if (voiceId.present) {
      map['voice_id'] = Variable<String>(voiceId.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title, ')
          ..write('textOffset: $textOffset, ')
          ..write('voiceId: $voiceId, ')
          ..write('isHidden: $isHidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChapterPlaybackProgressesTable extends ChapterPlaybackProgresses
    with TableInfo<$ChapterPlaybackProgressesTable, ChapterPlaybackProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterPlaybackProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _paragraphIndexMeta = const VerificationMeta(
    'paragraphIndex',
  );
  @override
  late final GeneratedColumn<int> paragraphIndex = GeneratedColumn<int>(
    'paragraph_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _paragraphOffsetMsMeta = const VerificationMeta(
    'paragraphOffsetMs',
  );
  @override
  late final GeneratedColumn<int> paragraphOffsetMs = GeneratedColumn<int>(
    'paragraph_offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFinishedMeta = const VerificationMeta(
    'isFinished',
  );
  @override
  late final GeneratedColumn<bool> isFinished = GeneratedColumn<bool>(
    'is_finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    chapterId,
    bookId,
    positionMs,
    paragraphIndex,
    paragraphOffsetMs,
    isFinished,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_playback_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterPlaybackProgress> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('paragraph_index')) {
      context.handle(
        _paragraphIndexMeta,
        paragraphIndex.isAcceptableOrUnknown(
          data['paragraph_index']!,
          _paragraphIndexMeta,
        ),
      );
    }
    if (data.containsKey('paragraph_offset_ms')) {
      context.handle(
        _paragraphOffsetMsMeta,
        paragraphOffsetMs.isAcceptableOrUnknown(
          data['paragraph_offset_ms']!,
          _paragraphOffsetMsMeta,
        ),
      );
    }
    if (data.containsKey('is_finished')) {
      context.handle(
        _isFinishedMeta,
        isFinished.isAcceptableOrUnknown(data['is_finished']!, _isFinishedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chapterId};
  @override
  ChapterPlaybackProgress map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterPlaybackProgress(
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      paragraphOffsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_offset_ms'],
      )!,
      isFinished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_finished'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChapterPlaybackProgressesTable createAlias(String alias) {
    return $ChapterPlaybackProgressesTable(attachedDatabase, alias);
  }
}

class ChapterPlaybackProgress extends DataClass
    implements Insertable<ChapterPlaybackProgress> {
  final String chapterId;
  final String bookId;
  final int positionMs;
  final int paragraphIndex;
  final int paragraphOffsetMs;
  final bool isFinished;
  final int updatedAt;
  const ChapterPlaybackProgress({
    required this.chapterId,
    required this.bookId,
    required this.positionMs,
    required this.paragraphIndex,
    required this.paragraphOffsetMs,
    required this.isFinished,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chapter_id'] = Variable<String>(chapterId);
    map['book_id'] = Variable<String>(bookId);
    map['position_ms'] = Variable<int>(positionMs);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['paragraph_offset_ms'] = Variable<int>(paragraphOffsetMs);
    map['is_finished'] = Variable<bool>(isFinished);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ChapterPlaybackProgressesCompanion toCompanion(bool nullToAbsent) {
    return ChapterPlaybackProgressesCompanion(
      chapterId: Value(chapterId),
      bookId: Value(bookId),
      positionMs: Value(positionMs),
      paragraphIndex: Value(paragraphIndex),
      paragraphOffsetMs: Value(paragraphOffsetMs),
      isFinished: Value(isFinished),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChapterPlaybackProgress.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterPlaybackProgress(
      chapterId: serializer.fromJson<String>(json['chapterId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      paragraphOffsetMs: serializer.fromJson<int>(json['paragraphOffsetMs']),
      isFinished: serializer.fromJson<bool>(json['isFinished']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chapterId': serializer.toJson<String>(chapterId),
      'bookId': serializer.toJson<String>(bookId),
      'positionMs': serializer.toJson<int>(positionMs),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'paragraphOffsetMs': serializer.toJson<int>(paragraphOffsetMs),
      'isFinished': serializer.toJson<bool>(isFinished),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ChapterPlaybackProgress copyWith({
    String? chapterId,
    String? bookId,
    int? positionMs,
    int? paragraphIndex,
    int? paragraphOffsetMs,
    bool? isFinished,
    int? updatedAt,
  }) => ChapterPlaybackProgress(
    chapterId: chapterId ?? this.chapterId,
    bookId: bookId ?? this.bookId,
    positionMs: positionMs ?? this.positionMs,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    paragraphOffsetMs: paragraphOffsetMs ?? this.paragraphOffsetMs,
    isFinished: isFinished ?? this.isFinished,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChapterPlaybackProgress copyWithCompanion(
    ChapterPlaybackProgressesCompanion data,
  ) {
    return ChapterPlaybackProgress(
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      paragraphIndex: data.paragraphIndex.present
          ? data.paragraphIndex.value
          : this.paragraphIndex,
      paragraphOffsetMs: data.paragraphOffsetMs.present
          ? data.paragraphOffsetMs.value
          : this.paragraphOffsetMs,
      isFinished: data.isFinished.present
          ? data.isFinished.value
          : this.isFinished,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterPlaybackProgress(')
          ..write('chapterId: $chapterId, ')
          ..write('bookId: $bookId, ')
          ..write('positionMs: $positionMs, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('paragraphOffsetMs: $paragraphOffsetMs, ')
          ..write('isFinished: $isFinished, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    chapterId,
    bookId,
    positionMs,
    paragraphIndex,
    paragraphOffsetMs,
    isFinished,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterPlaybackProgress &&
          other.chapterId == this.chapterId &&
          other.bookId == this.bookId &&
          other.positionMs == this.positionMs &&
          other.paragraphIndex == this.paragraphIndex &&
          other.paragraphOffsetMs == this.paragraphOffsetMs &&
          other.isFinished == this.isFinished &&
          other.updatedAt == this.updatedAt);
}

class ChapterPlaybackProgressesCompanion
    extends UpdateCompanion<ChapterPlaybackProgress> {
  final Value<String> chapterId;
  final Value<String> bookId;
  final Value<int> positionMs;
  final Value<int> paragraphIndex;
  final Value<int> paragraphOffsetMs;
  final Value<bool> isFinished;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ChapterPlaybackProgressesCompanion({
    this.chapterId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.paragraphOffsetMs = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChapterPlaybackProgressesCompanion.insert({
    required String chapterId,
    required String bookId,
    this.positionMs = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.paragraphOffsetMs = const Value.absent(),
    this.isFinished = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : chapterId = Value(chapterId),
       bookId = Value(bookId),
       updatedAt = Value(updatedAt);
  static Insertable<ChapterPlaybackProgress> custom({
    Expression<String>? chapterId,
    Expression<String>? bookId,
    Expression<int>? positionMs,
    Expression<int>? paragraphIndex,
    Expression<int>? paragraphOffsetMs,
    Expression<bool>? isFinished,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chapterId != null) 'chapter_id': chapterId,
      if (bookId != null) 'book_id': bookId,
      if (positionMs != null) 'position_ms': positionMs,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (paragraphOffsetMs != null) 'paragraph_offset_ms': paragraphOffsetMs,
      if (isFinished != null) 'is_finished': isFinished,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChapterPlaybackProgressesCompanion copyWith({
    Value<String>? chapterId,
    Value<String>? bookId,
    Value<int>? positionMs,
    Value<int>? paragraphIndex,
    Value<int>? paragraphOffsetMs,
    Value<bool>? isFinished,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChapterPlaybackProgressesCompanion(
      chapterId: chapterId ?? this.chapterId,
      bookId: bookId ?? this.bookId,
      positionMs: positionMs ?? this.positionMs,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      paragraphOffsetMs: paragraphOffsetMs ?? this.paragraphOffsetMs,
      isFinished: isFinished ?? this.isFinished,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (paragraphOffsetMs.present) {
      map['paragraph_offset_ms'] = Variable<int>(paragraphOffsetMs.value);
    }
    if (isFinished.present) {
      map['is_finished'] = Variable<bool>(isFinished.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChapterPlaybackProgressesCompanion(')
          ..write('chapterId: $chapterId, ')
          ..write('bookId: $bookId, ')
          ..write('positionMs: $positionMs, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('paragraphOffsetMs: $paragraphOffsetMs, ')
          ..write('isFinished: $isFinished, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ParagraphsTable extends Paragraphs
    with TableInfo<$ParagraphsTable, Paragraph> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParagraphsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paragraphIndexMeta = const VerificationMeta(
    'paragraphIndex',
  );
  @override
  late final GeneratedColumn<int> paragraphIndex = GeneratedColumn<int>(
    'paragraph_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chapterId,
    bookId,
    paragraphIndex,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paragraphs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Paragraph> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('paragraph_index')) {
      context.handle(
        _paragraphIndexMeta,
        paragraphIndex.isAcceptableOrUnknown(
          data['paragraph_index']!,
          _paragraphIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paragraphIndexMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['text']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {chapterId, paragraphIndex},
  ];
  @override
  Paragraph map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Paragraph(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
    );
  }

  @override
  $ParagraphsTable createAlias(String alias) {
    return $ParagraphsTable(attachedDatabase, alias);
  }
}

class Paragraph extends DataClass implements Insertable<Paragraph> {
  final String id;
  final String chapterId;
  final String bookId;
  final int paragraphIndex;
  final String content;
  const Paragraph({
    required this.id,
    required this.chapterId,
    required this.bookId,
    required this.paragraphIndex,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chapter_id'] = Variable<String>(chapterId);
    map['book_id'] = Variable<String>(bookId);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['text'] = Variable<String>(content);
    return map;
  }

  ParagraphsCompanion toCompanion(bool nullToAbsent) {
    return ParagraphsCompanion(
      id: Value(id),
      chapterId: Value(chapterId),
      bookId: Value(bookId),
      paragraphIndex: Value(paragraphIndex),
      content: Value(content),
    );
  }

  factory Paragraph.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Paragraph(
      id: serializer.fromJson<String>(json['id']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chapterId': serializer.toJson<String>(chapterId),
      'bookId': serializer.toJson<String>(bookId),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'content': serializer.toJson<String>(content),
    };
  }

  Paragraph copyWith({
    String? id,
    String? chapterId,
    String? bookId,
    int? paragraphIndex,
    String? content,
  }) => Paragraph(
    id: id ?? this.id,
    chapterId: chapterId ?? this.chapterId,
    bookId: bookId ?? this.bookId,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    content: content ?? this.content,
  );
  Paragraph copyWithCompanion(ParagraphsCompanion data) {
    return Paragraph(
      id: data.id.present ? data.id.value : this.id,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      paragraphIndex: data.paragraphIndex.present
          ? data.paragraphIndex.value
          : this.paragraphIndex,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Paragraph(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('bookId: $bookId, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, chapterId, bookId, paragraphIndex, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Paragraph &&
          other.id == this.id &&
          other.chapterId == this.chapterId &&
          other.bookId == this.bookId &&
          other.paragraphIndex == this.paragraphIndex &&
          other.content == this.content);
}

class ParagraphsCompanion extends UpdateCompanion<Paragraph> {
  final Value<String> id;
  final Value<String> chapterId;
  final Value<String> bookId;
  final Value<int> paragraphIndex;
  final Value<String> content;
  final Value<int> rowid;
  const ParagraphsCompanion({
    this.id = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParagraphsCompanion.insert({
    required String id,
    required String chapterId,
    required String bookId,
    required int paragraphIndex,
    required String content,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chapterId = Value(chapterId),
       bookId = Value(bookId),
       paragraphIndex = Value(paragraphIndex),
       content = Value(content);
  static Insertable<Paragraph> custom({
    Expression<String>? id,
    Expression<String>? chapterId,
    Expression<String>? bookId,
    Expression<int>? paragraphIndex,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chapterId != null) 'chapter_id': chapterId,
      if (bookId != null) 'book_id': bookId,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (content != null) 'text': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParagraphsCompanion copyWith({
    Value<String>? id,
    Value<String>? chapterId,
    Value<String>? bookId,
    Value<int>? paragraphIndex,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return ParagraphsCompanion(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      bookId: bookId ?? this.bookId,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (content.present) {
      map['text'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParagraphsCompanion(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('bookId: $bookId, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paragraphIndexMeta = const VerificationMeta(
    'paragraphIndex',
  );
  @override
  late final GeneratedColumn<int> paragraphIndex = GeneratedColumn<int>(
    'paragraph_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _excerptMeta = const VerificationMeta(
    'excerpt',
  );
  @override
  late final GeneratedColumn<String> excerpt = GeneratedColumn<String>(
    'excerpt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterId,
    paragraphIndex,
    excerpt,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('paragraph_index')) {
      context.handle(
        _paragraphIndexMeta,
        paragraphIndex.isAcceptableOrUnknown(
          data['paragraph_index']!,
          _paragraphIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paragraphIndexMeta);
    }
    if (data.containsKey('excerpt')) {
      context.handle(
        _excerptMeta,
        excerpt.isAcceptableOrUnknown(data['excerpt']!, _excerptMeta),
      );
    } else if (isInserting) {
      context.missing(_excerptMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      excerpt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}excerpt'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final String id;
  final String bookId;
  final String chapterId;
  final int paragraphIndex;
  final String excerpt;
  final String? note;
  final int createdAt;
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.paragraphIndex,
    required this.excerpt,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<String>(chapterId);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['excerpt'] = Variable<String>(excerpt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      paragraphIndex: Value(paragraphIndex),
      excerpt: Value(excerpt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      excerpt: serializer.fromJson<String>(json['excerpt']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterId': serializer.toJson<String>(chapterId),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'excerpt': serializer.toJson<String>(excerpt),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Bookmark copyWith({
    String? id,
    String? bookId,
    String? chapterId,
    int? paragraphIndex,
    String? excerpt,
    Value<String?> note = const Value.absent(),
    int? createdAt,
  }) => Bookmark(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    excerpt: excerpt ?? this.excerpt,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      paragraphIndex: data.paragraphIndex.present
          ? data.paragraphIndex.value
          : this.paragraphIndex,
      excerpt: data.excerpt.present ? data.excerpt.value : this.excerpt,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('excerpt: $excerpt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterId,
    paragraphIndex,
    excerpt,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.paragraphIndex == this.paragraphIndex &&
          other.excerpt == this.excerpt &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> chapterId;
  final Value<int> paragraphIndex;
  final Value<String> excerpt;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.excerpt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String bookId,
    required String chapterId,
    required int paragraphIndex,
    required String excerpt,
    this.note = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterId = Value(chapterId),
       paragraphIndex = Value(paragraphIndex),
       excerpt = Value(excerpt),
       createdAt = Value(createdAt);
  static Insertable<Bookmark> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? chapterId,
    Expression<int>? paragraphIndex,
    Expression<String>? excerpt,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (excerpt != null) 'excerpt': excerpt,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? chapterId,
    Value<int>? paragraphIndex,
    Value<String>? excerpt,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      excerpt: excerpt ?? this.excerpt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (excerpt.present) {
      map['excerpt'] = Variable<String>(excerpt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('excerpt: $excerpt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoicesTable extends Voices with TableInfo<$VoicesTable, Voice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerVoiceIdMeta = const VerificationMeta(
    'providerVoiceId',
  );
  @override
  late final GeneratedColumn<String> providerVoiceId = GeneratedColumn<String>(
    'provider_voice_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _samplePathMeta = const VerificationMeta(
    'samplePath',
  );
  @override
  late final GeneratedColumn<String> samplePath = GeneratedColumn<String>(
    'sample_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _presetDescriptionMeta = const VerificationMeta(
    'presetDescription',
  );
  @override
  late final GeneratedColumn<String> presetDescription =
      GeneratedColumn<String>(
        'preset_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _previewUrlMeta = const VerificationMeta(
    'previewUrl',
  );
  @override
  late final GeneratedColumn<String> previewUrl = GeneratedColumn<String>(
    'preview_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    providerId,
    type,
    providerVoiceId,
    samplePath,
    description,
    presetDescription,
    previewUrl,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Voice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('provider_voice_id')) {
      context.handle(
        _providerVoiceIdMeta,
        providerVoiceId.isAcceptableOrUnknown(
          data['provider_voice_id']!,
          _providerVoiceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerVoiceIdMeta);
    }
    if (data.containsKey('sample_path')) {
      context.handle(
        _samplePathMeta,
        samplePath.isAcceptableOrUnknown(data['sample_path']!, _samplePathMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('preset_description')) {
      context.handle(
        _presetDescriptionMeta,
        presetDescription.isAcceptableOrUnknown(
          data['preset_description']!,
          _presetDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('preview_url')) {
      context.handle(
        _previewUrlMeta,
        previewUrl.isAcceptableOrUnknown(data['preview_url']!, _previewUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Voice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Voice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      providerVoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_voice_id'],
      )!,
      samplePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sample_path'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      presetDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_description'],
      ),
      previewUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VoicesTable createAlias(String alias) {
    return $VoicesTable(attachedDatabase, alias);
  }
}

class Voice extends DataClass implements Insertable<Voice> {
  final String id;
  final String name;
  final String providerId;
  final String type;
  final String providerVoiceId;
  final String? samplePath;
  final String? description;
  final String? presetDescription;
  final String? previewUrl;
  final int createdAt;
  const Voice({
    required this.id,
    required this.name,
    required this.providerId,
    required this.type,
    required this.providerVoiceId,
    this.samplePath,
    this.description,
    this.presetDescription,
    this.previewUrl,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['provider_id'] = Variable<String>(providerId);
    map['type'] = Variable<String>(type);
    map['provider_voice_id'] = Variable<String>(providerVoiceId);
    if (!nullToAbsent || samplePath != null) {
      map['sample_path'] = Variable<String>(samplePath);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || presetDescription != null) {
      map['preset_description'] = Variable<String>(presetDescription);
    }
    if (!nullToAbsent || previewUrl != null) {
      map['preview_url'] = Variable<String>(previewUrl);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  VoicesCompanion toCompanion(bool nullToAbsent) {
    return VoicesCompanion(
      id: Value(id),
      name: Value(name),
      providerId: Value(providerId),
      type: Value(type),
      providerVoiceId: Value(providerVoiceId),
      samplePath: samplePath == null && nullToAbsent
          ? const Value.absent()
          : Value(samplePath),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      presetDescription: presetDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(presetDescription),
      previewUrl: previewUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(previewUrl),
      createdAt: Value(createdAt),
    );
  }

  factory Voice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Voice(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      providerId: serializer.fromJson<String>(json['providerId']),
      type: serializer.fromJson<String>(json['type']),
      providerVoiceId: serializer.fromJson<String>(json['providerVoiceId']),
      samplePath: serializer.fromJson<String?>(json['samplePath']),
      description: serializer.fromJson<String?>(json['description']),
      presetDescription: serializer.fromJson<String?>(
        json['presetDescription'],
      ),
      previewUrl: serializer.fromJson<String?>(json['previewUrl']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'providerId': serializer.toJson<String>(providerId),
      'type': serializer.toJson<String>(type),
      'providerVoiceId': serializer.toJson<String>(providerVoiceId),
      'samplePath': serializer.toJson<String?>(samplePath),
      'description': serializer.toJson<String?>(description),
      'presetDescription': serializer.toJson<String?>(presetDescription),
      'previewUrl': serializer.toJson<String?>(previewUrl),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Voice copyWith({
    String? id,
    String? name,
    String? providerId,
    String? type,
    String? providerVoiceId,
    Value<String?> samplePath = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> presetDescription = const Value.absent(),
    Value<String?> previewUrl = const Value.absent(),
    int? createdAt,
  }) => Voice(
    id: id ?? this.id,
    name: name ?? this.name,
    providerId: providerId ?? this.providerId,
    type: type ?? this.type,
    providerVoiceId: providerVoiceId ?? this.providerVoiceId,
    samplePath: samplePath.present ? samplePath.value : this.samplePath,
    description: description.present ? description.value : this.description,
    presetDescription: presetDescription.present
        ? presetDescription.value
        : this.presetDescription,
    previewUrl: previewUrl.present ? previewUrl.value : this.previewUrl,
    createdAt: createdAt ?? this.createdAt,
  );
  Voice copyWithCompanion(VoicesCompanion data) {
    return Voice(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      type: data.type.present ? data.type.value : this.type,
      providerVoiceId: data.providerVoiceId.present
          ? data.providerVoiceId.value
          : this.providerVoiceId,
      samplePath: data.samplePath.present
          ? data.samplePath.value
          : this.samplePath,
      description: data.description.present
          ? data.description.value
          : this.description,
      presetDescription: data.presetDescription.present
          ? data.presetDescription.value
          : this.presetDescription,
      previewUrl: data.previewUrl.present
          ? data.previewUrl.value
          : this.previewUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Voice(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('providerId: $providerId, ')
          ..write('type: $type, ')
          ..write('providerVoiceId: $providerVoiceId, ')
          ..write('samplePath: $samplePath, ')
          ..write('description: $description, ')
          ..write('presetDescription: $presetDescription, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    providerId,
    type,
    providerVoiceId,
    samplePath,
    description,
    presetDescription,
    previewUrl,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Voice &&
          other.id == this.id &&
          other.name == this.name &&
          other.providerId == this.providerId &&
          other.type == this.type &&
          other.providerVoiceId == this.providerVoiceId &&
          other.samplePath == this.samplePath &&
          other.description == this.description &&
          other.presetDescription == this.presetDescription &&
          other.previewUrl == this.previewUrl &&
          other.createdAt == this.createdAt);
}

class VoicesCompanion extends UpdateCompanion<Voice> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> providerId;
  final Value<String> type;
  final Value<String> providerVoiceId;
  final Value<String?> samplePath;
  final Value<String?> description;
  final Value<String?> presetDescription;
  final Value<String?> previewUrl;
  final Value<int> createdAt;
  final Value<int> rowid;
  const VoicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.providerId = const Value.absent(),
    this.type = const Value.absent(),
    this.providerVoiceId = const Value.absent(),
    this.samplePath = const Value.absent(),
    this.description = const Value.absent(),
    this.presetDescription = const Value.absent(),
    this.previewUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoicesCompanion.insert({
    required String id,
    required String name,
    required String providerId,
    required String type,
    required String providerVoiceId,
    this.samplePath = const Value.absent(),
    this.description = const Value.absent(),
    this.presetDescription = const Value.absent(),
    this.previewUrl = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       providerId = Value(providerId),
       type = Value(type),
       providerVoiceId = Value(providerVoiceId),
       createdAt = Value(createdAt);
  static Insertable<Voice> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? providerId,
    Expression<String>? type,
    Expression<String>? providerVoiceId,
    Expression<String>? samplePath,
    Expression<String>? description,
    Expression<String>? presetDescription,
    Expression<String>? previewUrl,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (providerId != null) 'provider_id': providerId,
      if (type != null) 'type': type,
      if (providerVoiceId != null) 'provider_voice_id': providerVoiceId,
      if (samplePath != null) 'sample_path': samplePath,
      if (description != null) 'description': description,
      if (presetDescription != null) 'preset_description': presetDescription,
      if (previewUrl != null) 'preview_url': previewUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoicesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? providerId,
    Value<String>? type,
    Value<String>? providerVoiceId,
    Value<String?>? samplePath,
    Value<String?>? description,
    Value<String?>? presetDescription,
    Value<String?>? previewUrl,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return VoicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      type: type ?? this.type,
      providerVoiceId: providerVoiceId ?? this.providerVoiceId,
      samplePath: samplePath ?? this.samplePath,
      description: description ?? this.description,
      presetDescription: presetDescription ?? this.presetDescription,
      previewUrl: previewUrl ?? this.previewUrl,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (providerVoiceId.present) {
      map['provider_voice_id'] = Variable<String>(providerVoiceId.value);
    }
    if (samplePath.present) {
      map['sample_path'] = Variable<String>(samplePath.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (presetDescription.present) {
      map['preset_description'] = Variable<String>(presetDescription.value);
    }
    if (previewUrl.present) {
      map['preview_url'] = Variable<String>(previewUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('providerId: $providerId, ')
          ..write('type: $type, ')
          ..write('providerVoiceId: $providerVoiceId, ')
          ..write('samplePath: $samplePath, ')
          ..write('description: $description, ')
          ..write('presetDescription: $presetDescription, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CostRecordsTable extends CostRecords
    with TableInfo<$CostRecordsTable, CostRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CostRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _charactersMeta = const VerificationMeta(
    'characters',
  );
  @override
  late final GeneratedColumn<int> characters = GeneratedColumn<int>(
    'characters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterId,
    providerId,
    characters,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cost_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<CostRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('characters')) {
      context.handle(
        _charactersMeta,
        characters.isAcceptableOrUnknown(data['characters']!, _charactersMeta),
      );
    } else if (isInserting) {
      context.missing(_charactersMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CostRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CostRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      characters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}characters'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CostRecordsTable createAlias(String alias) {
    return $CostRecordsTable(attachedDatabase, alias);
  }
}

class CostRecord extends DataClass implements Insertable<CostRecord> {
  final int id;
  final String bookId;
  final String chapterId;
  final String providerId;
  final int characters;
  final int createdAt;
  const CostRecord({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.providerId,
    required this.characters,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<String>(chapterId);
    map['provider_id'] = Variable<String>(providerId);
    map['characters'] = Variable<int>(characters);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  CostRecordsCompanion toCompanion(bool nullToAbsent) {
    return CostRecordsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      providerId: Value(providerId),
      characters: Value(characters),
      createdAt: Value(createdAt),
    );
  }

  factory CostRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CostRecord(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      characters: serializer.fromJson<int>(json['characters']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterId': serializer.toJson<String>(chapterId),
      'providerId': serializer.toJson<String>(providerId),
      'characters': serializer.toJson<int>(characters),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  CostRecord copyWith({
    int? id,
    String? bookId,
    String? chapterId,
    String? providerId,
    int? characters,
    int? createdAt,
  }) => CostRecord(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    providerId: providerId ?? this.providerId,
    characters: characters ?? this.characters,
    createdAt: createdAt ?? this.createdAt,
  );
  CostRecord copyWithCompanion(CostRecordsCompanion data) {
    return CostRecord(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      characters: data.characters.present
          ? data.characters.value
          : this.characters,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CostRecord(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('providerId: $providerId, ')
          ..write('characters: $characters, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, chapterId, providerId, characters, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CostRecord &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.providerId == this.providerId &&
          other.characters == this.characters &&
          other.createdAt == this.createdAt);
}

class CostRecordsCompanion extends UpdateCompanion<CostRecord> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> chapterId;
  final Value<String> providerId;
  final Value<int> characters;
  final Value<int> createdAt;
  const CostRecordsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.characters = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CostRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String chapterId,
    required String providerId,
    required int characters,
    required int createdAt,
  }) : bookId = Value(bookId),
       chapterId = Value(chapterId),
       providerId = Value(providerId),
       characters = Value(characters),
       createdAt = Value(createdAt);
  static Insertable<CostRecord> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? chapterId,
    Expression<String>? providerId,
    Expression<int>? characters,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (providerId != null) 'provider_id': providerId,
      if (characters != null) 'characters': characters,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CostRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<String>? chapterId,
    Value<String>? providerId,
    Value<int>? characters,
    Value<int>? createdAt,
  }) {
    return CostRecordsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      providerId: providerId ?? this.providerId,
      characters: characters ?? this.characters,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (characters.present) {
      map['characters'] = Variable<int>(characters.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CostRecordsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('providerId: $providerId, ')
          ..write('characters: $characters, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ListeningDaysTable extends ListeningDays
    with TableInfo<$ListeningDaysTable, ListeningDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListeningDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listenedMsMeta = const VerificationMeta(
    'listenedMs',
  );
  @override
  late final GeneratedColumn<int> listenedMs = GeneratedColumn<int>(
    'listened_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sessionsMeta = const VerificationMeta(
    'sessions',
  );
  @override
  late final GeneratedColumn<int> sessions = GeneratedColumn<int>(
    'sessions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    dateKey,
    listenedMs,
    sessions,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listening_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListeningDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('listened_ms')) {
      context.handle(
        _listenedMsMeta,
        listenedMs.isAcceptableOrUnknown(data['listened_ms']!, _listenedMsMeta),
      );
    }
    if (data.containsKey('sessions')) {
      context.handle(
        _sessionsMeta,
        sessions.isAcceptableOrUnknown(data['sessions']!, _sessionsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dateKey};
  @override
  ListeningDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListeningDay(
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      listenedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}listened_ms'],
      )!,
      sessions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sessions'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ListeningDaysTable createAlias(String alias) {
    return $ListeningDaysTable(attachedDatabase, alias);
  }
}

class ListeningDay extends DataClass implements Insertable<ListeningDay> {
  final String dateKey;
  final int listenedMs;
  final int sessions;
  final int updatedAt;
  const ListeningDay({
    required this.dateKey,
    required this.listenedMs,
    required this.sessions,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date_key'] = Variable<String>(dateKey);
    map['listened_ms'] = Variable<int>(listenedMs);
    map['sessions'] = Variable<int>(sessions);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ListeningDaysCompanion toCompanion(bool nullToAbsent) {
    return ListeningDaysCompanion(
      dateKey: Value(dateKey),
      listenedMs: Value(listenedMs),
      sessions: Value(sessions),
      updatedAt: Value(updatedAt),
    );
  }

  factory ListeningDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListeningDay(
      dateKey: serializer.fromJson<String>(json['dateKey']),
      listenedMs: serializer.fromJson<int>(json['listenedMs']),
      sessions: serializer.fromJson<int>(json['sessions']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dateKey': serializer.toJson<String>(dateKey),
      'listenedMs': serializer.toJson<int>(listenedMs),
      'sessions': serializer.toJson<int>(sessions),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ListeningDay copyWith({
    String? dateKey,
    int? listenedMs,
    int? sessions,
    int? updatedAt,
  }) => ListeningDay(
    dateKey: dateKey ?? this.dateKey,
    listenedMs: listenedMs ?? this.listenedMs,
    sessions: sessions ?? this.sessions,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ListeningDay copyWithCompanion(ListeningDaysCompanion data) {
    return ListeningDay(
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      listenedMs: data.listenedMs.present
          ? data.listenedMs.value
          : this.listenedMs,
      sessions: data.sessions.present ? data.sessions.value : this.sessions,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListeningDay(')
          ..write('dateKey: $dateKey, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('sessions: $sessions, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dateKey, listenedMs, sessions, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListeningDay &&
          other.dateKey == this.dateKey &&
          other.listenedMs == this.listenedMs &&
          other.sessions == this.sessions &&
          other.updatedAt == this.updatedAt);
}

class ListeningDaysCompanion extends UpdateCompanion<ListeningDay> {
  final Value<String> dateKey;
  final Value<int> listenedMs;
  final Value<int> sessions;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ListeningDaysCompanion({
    this.dateKey = const Value.absent(),
    this.listenedMs = const Value.absent(),
    this.sessions = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListeningDaysCompanion.insert({
    required String dateKey,
    this.listenedMs = const Value.absent(),
    this.sessions = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : dateKey = Value(dateKey),
       updatedAt = Value(updatedAt);
  static Insertable<ListeningDay> custom({
    Expression<String>? dateKey,
    Expression<int>? listenedMs,
    Expression<int>? sessions,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dateKey != null) 'date_key': dateKey,
      if (listenedMs != null) 'listened_ms': listenedMs,
      if (sessions != null) 'sessions': sessions,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListeningDaysCompanion copyWith({
    Value<String>? dateKey,
    Value<int>? listenedMs,
    Value<int>? sessions,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ListeningDaysCompanion(
      dateKey: dateKey ?? this.dateKey,
      listenedMs: listenedMs ?? this.listenedMs,
      sessions: sessions ?? this.sessions,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (listenedMs.present) {
      map['listened_ms'] = Variable<int>(listenedMs.value);
    }
    if (sessions.present) {
      map['sessions'] = Variable<int>(sessions.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListeningDaysCompanion(')
          ..write('dateKey: $dateKey, ')
          ..write('listenedMs: $listenedMs, ')
          ..write('sessions: $sessions, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DictionaryEntriesTable extends DictionaryEntries
    with TableInfo<$DictionaryEntriesTable, DictionaryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedTermMeta = const VerificationMeta(
    'normalizedTerm',
  );
  @override
  late final GeneratedColumn<String> normalizedTerm = GeneratedColumn<String>(
    'normalized_term',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayWordMeta = const VerificationMeta(
    'displayWord',
  );
  @override
  late final GeneratedColumn<String> displayWord = GeneratedColumn<String>(
    'display_word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usPhoneticMeta = const VerificationMeta(
    'usPhonetic',
  );
  @override
  late final GeneratedColumn<String> usPhonetic = GeneratedColumn<String>(
    'us_phonetic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ukPhoneticMeta = const VerificationMeta(
    'ukPhonetic',
  );
  @override
  late final GeneratedColumn<String> ukPhonetic = GeneratedColumn<String>(
    'uk_phonetic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _definitionsJsonMeta = const VerificationMeta(
    'definitionsJson',
  );
  @override
  late final GeneratedColumn<String> definitionsJson = GeneratedColumn<String>(
    'definitions_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherFormsJsonMeta = const VerificationMeta(
    'otherFormsJson',
  );
  @override
  late final GeneratedColumn<String> otherFormsJson = GeneratedColumn<String>(
    'other_forms_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shortExplanationMeta = const VerificationMeta(
    'shortExplanation',
  );
  @override
  late final GeneratedColumn<String> shortExplanation = GeneratedColumn<String>(
    'short_explanation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longExplanationMeta = const VerificationMeta(
    'longExplanation',
  );
  @override
  late final GeneratedColumn<String> longExplanation = GeneratedColumn<String>(
    'long_explanation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingLevelSystemMeta =
      const VerificationMeta('readingLevelSystem');
  @override
  late final GeneratedColumn<String> readingLevelSystem =
      GeneratedColumn<String>(
        'reading_level_system',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _readingLevelCodeMeta = const VerificationMeta(
    'readingLevelCode',
  );
  @override
  late final GeneratedColumn<String> readingLevelCode = GeneratedColumn<String>(
    'reading_level_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readingLevelSourceMeta =
      const VerificationMeta('readingLevelSource');
  @override
  late final GeneratedColumn<String> readingLevelSource =
      GeneratedColumn<String>(
        'reading_level_source',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<int> lastAccessedAt = GeneratedColumn<int>(
    'last_accessed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accessCountMeta = const VerificationMeta(
    'accessCount',
  );
  @override
  late final GeneratedColumn<int> accessCount = GeneratedColumn<int>(
    'access_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    provider,
    language,
    normalizedTerm,
    displayWord,
    status,
    usPhonetic,
    ukPhonetic,
    definitionsJson,
    otherFormsJson,
    shortExplanation,
    longExplanation,
    sourceUrl,
    readingLevelSystem,
    readingLevelCode,
    readingLevelSource,
    fetchedAt,
    expiresAt,
    lastAccessedAt,
    accessCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DictionaryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('normalized_term')) {
      context.handle(
        _normalizedTermMeta,
        normalizedTerm.isAcceptableOrUnknown(
          data['normalized_term']!,
          _normalizedTermMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedTermMeta);
    }
    if (data.containsKey('display_word')) {
      context.handle(
        _displayWordMeta,
        displayWord.isAcceptableOrUnknown(
          data['display_word']!,
          _displayWordMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayWordMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('us_phonetic')) {
      context.handle(
        _usPhoneticMeta,
        usPhonetic.isAcceptableOrUnknown(data['us_phonetic']!, _usPhoneticMeta),
      );
    }
    if (data.containsKey('uk_phonetic')) {
      context.handle(
        _ukPhoneticMeta,
        ukPhonetic.isAcceptableOrUnknown(data['uk_phonetic']!, _ukPhoneticMeta),
      );
    }
    if (data.containsKey('definitions_json')) {
      context.handle(
        _definitionsJsonMeta,
        definitionsJson.isAcceptableOrUnknown(
          data['definitions_json']!,
          _definitionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('other_forms_json')) {
      context.handle(
        _otherFormsJsonMeta,
        otherFormsJson.isAcceptableOrUnknown(
          data['other_forms_json']!,
          _otherFormsJsonMeta,
        ),
      );
    }
    if (data.containsKey('short_explanation')) {
      context.handle(
        _shortExplanationMeta,
        shortExplanation.isAcceptableOrUnknown(
          data['short_explanation']!,
          _shortExplanationMeta,
        ),
      );
    }
    if (data.containsKey('long_explanation')) {
      context.handle(
        _longExplanationMeta,
        longExplanation.isAcceptableOrUnknown(
          data['long_explanation']!,
          _longExplanationMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('reading_level_system')) {
      context.handle(
        _readingLevelSystemMeta,
        readingLevelSystem.isAcceptableOrUnknown(
          data['reading_level_system']!,
          _readingLevelSystemMeta,
        ),
      );
    }
    if (data.containsKey('reading_level_code')) {
      context.handle(
        _readingLevelCodeMeta,
        readingLevelCode.isAcceptableOrUnknown(
          data['reading_level_code']!,
          _readingLevelCodeMeta,
        ),
      );
    }
    if (data.containsKey('reading_level_source')) {
      context.handle(
        _readingLevelSourceMeta,
        readingLevelSource.isAcceptableOrUnknown(
          data['reading_level_source']!,
          _readingLevelSourceMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    if (data.containsKey('access_count')) {
      context.handle(
        _accessCountMeta,
        accessCount.isAcceptableOrUnknown(
          data['access_count']!,
          _accessCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {provider, language, normalizedTerm},
  ];
  @override
  DictionaryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      normalizedTerm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_term'],
      )!,
      displayWord: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_word'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      usPhonetic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}us_phonetic'],
      ),
      ukPhonetic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uk_phonetic'],
      ),
      definitionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definitions_json'],
      ),
      otherFormsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_forms_json'],
      ),
      shortExplanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}short_explanation'],
      ),
      longExplanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}long_explanation'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      readingLevelSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_level_system'],
      ),
      readingLevelCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_level_code'],
      ),
      readingLevelSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_level_source'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      ),
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed_at'],
      )!,
      accessCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}access_count'],
      )!,
    );
  }

  @override
  $DictionaryEntriesTable createAlias(String alias) {
    return $DictionaryEntriesTable(attachedDatabase, alias);
  }
}

class DictionaryEntry extends DataClass implements Insertable<DictionaryEntry> {
  final String id;
  final String provider;
  final String language;
  final String normalizedTerm;
  final String displayWord;
  final String status;
  final String? usPhonetic;
  final String? ukPhonetic;
  final String? definitionsJson;
  final String? otherFormsJson;
  final String? shortExplanation;
  final String? longExplanation;
  final String sourceUrl;
  final String? readingLevelSystem;
  final String? readingLevelCode;
  final String? readingLevelSource;
  final int fetchedAt;
  final int? expiresAt;
  final int lastAccessedAt;
  final int accessCount;
  const DictionaryEntry({
    required this.id,
    required this.provider,
    required this.language,
    required this.normalizedTerm,
    required this.displayWord,
    required this.status,
    this.usPhonetic,
    this.ukPhonetic,
    this.definitionsJson,
    this.otherFormsJson,
    this.shortExplanation,
    this.longExplanation,
    required this.sourceUrl,
    this.readingLevelSystem,
    this.readingLevelCode,
    this.readingLevelSource,
    required this.fetchedAt,
    this.expiresAt,
    required this.lastAccessedAt,
    required this.accessCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider'] = Variable<String>(provider);
    map['language'] = Variable<String>(language);
    map['normalized_term'] = Variable<String>(normalizedTerm);
    map['display_word'] = Variable<String>(displayWord);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || usPhonetic != null) {
      map['us_phonetic'] = Variable<String>(usPhonetic);
    }
    if (!nullToAbsent || ukPhonetic != null) {
      map['uk_phonetic'] = Variable<String>(ukPhonetic);
    }
    if (!nullToAbsent || definitionsJson != null) {
      map['definitions_json'] = Variable<String>(definitionsJson);
    }
    if (!nullToAbsent || otherFormsJson != null) {
      map['other_forms_json'] = Variable<String>(otherFormsJson);
    }
    if (!nullToAbsent || shortExplanation != null) {
      map['short_explanation'] = Variable<String>(shortExplanation);
    }
    if (!nullToAbsent || longExplanation != null) {
      map['long_explanation'] = Variable<String>(longExplanation);
    }
    map['source_url'] = Variable<String>(sourceUrl);
    if (!nullToAbsent || readingLevelSystem != null) {
      map['reading_level_system'] = Variable<String>(readingLevelSystem);
    }
    if (!nullToAbsent || readingLevelCode != null) {
      map['reading_level_code'] = Variable<String>(readingLevelCode);
    }
    if (!nullToAbsent || readingLevelSource != null) {
      map['reading_level_source'] = Variable<String>(readingLevelSource);
    }
    map['fetched_at'] = Variable<int>(fetchedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(expiresAt);
    }
    map['last_accessed_at'] = Variable<int>(lastAccessedAt);
    map['access_count'] = Variable<int>(accessCount);
    return map;
  }

  DictionaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DictionaryEntriesCompanion(
      id: Value(id),
      provider: Value(provider),
      language: Value(language),
      normalizedTerm: Value(normalizedTerm),
      displayWord: Value(displayWord),
      status: Value(status),
      usPhonetic: usPhonetic == null && nullToAbsent
          ? const Value.absent()
          : Value(usPhonetic),
      ukPhonetic: ukPhonetic == null && nullToAbsent
          ? const Value.absent()
          : Value(ukPhonetic),
      definitionsJson: definitionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(definitionsJson),
      otherFormsJson: otherFormsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(otherFormsJson),
      shortExplanation: shortExplanation == null && nullToAbsent
          ? const Value.absent()
          : Value(shortExplanation),
      longExplanation: longExplanation == null && nullToAbsent
          ? const Value.absent()
          : Value(longExplanation),
      sourceUrl: Value(sourceUrl),
      readingLevelSystem: readingLevelSystem == null && nullToAbsent
          ? const Value.absent()
          : Value(readingLevelSystem),
      readingLevelCode: readingLevelCode == null && nullToAbsent
          ? const Value.absent()
          : Value(readingLevelCode),
      readingLevelSource: readingLevelSource == null && nullToAbsent
          ? const Value.absent()
          : Value(readingLevelSource),
      fetchedAt: Value(fetchedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      lastAccessedAt: Value(lastAccessedAt),
      accessCount: Value(accessCount),
    );
  }

  factory DictionaryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryEntry(
      id: serializer.fromJson<String>(json['id']),
      provider: serializer.fromJson<String>(json['provider']),
      language: serializer.fromJson<String>(json['language']),
      normalizedTerm: serializer.fromJson<String>(json['normalizedTerm']),
      displayWord: serializer.fromJson<String>(json['displayWord']),
      status: serializer.fromJson<String>(json['status']),
      usPhonetic: serializer.fromJson<String?>(json['usPhonetic']),
      ukPhonetic: serializer.fromJson<String?>(json['ukPhonetic']),
      definitionsJson: serializer.fromJson<String?>(json['definitionsJson']),
      otherFormsJson: serializer.fromJson<String?>(json['otherFormsJson']),
      shortExplanation: serializer.fromJson<String?>(json['shortExplanation']),
      longExplanation: serializer.fromJson<String?>(json['longExplanation']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      readingLevelSystem: serializer.fromJson<String?>(
        json['readingLevelSystem'],
      ),
      readingLevelCode: serializer.fromJson<String?>(json['readingLevelCode']),
      readingLevelSource: serializer.fromJson<String?>(
        json['readingLevelSource'],
      ),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
      expiresAt: serializer.fromJson<int?>(json['expiresAt']),
      lastAccessedAt: serializer.fromJson<int>(json['lastAccessedAt']),
      accessCount: serializer.fromJson<int>(json['accessCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'provider': serializer.toJson<String>(provider),
      'language': serializer.toJson<String>(language),
      'normalizedTerm': serializer.toJson<String>(normalizedTerm),
      'displayWord': serializer.toJson<String>(displayWord),
      'status': serializer.toJson<String>(status),
      'usPhonetic': serializer.toJson<String?>(usPhonetic),
      'ukPhonetic': serializer.toJson<String?>(ukPhonetic),
      'definitionsJson': serializer.toJson<String?>(definitionsJson),
      'otherFormsJson': serializer.toJson<String?>(otherFormsJson),
      'shortExplanation': serializer.toJson<String?>(shortExplanation),
      'longExplanation': serializer.toJson<String?>(longExplanation),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'readingLevelSystem': serializer.toJson<String?>(readingLevelSystem),
      'readingLevelCode': serializer.toJson<String?>(readingLevelCode),
      'readingLevelSource': serializer.toJson<String?>(readingLevelSource),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
      'expiresAt': serializer.toJson<int?>(expiresAt),
      'lastAccessedAt': serializer.toJson<int>(lastAccessedAt),
      'accessCount': serializer.toJson<int>(accessCount),
    };
  }

  DictionaryEntry copyWith({
    String? id,
    String? provider,
    String? language,
    String? normalizedTerm,
    String? displayWord,
    String? status,
    Value<String?> usPhonetic = const Value.absent(),
    Value<String?> ukPhonetic = const Value.absent(),
    Value<String?> definitionsJson = const Value.absent(),
    Value<String?> otherFormsJson = const Value.absent(),
    Value<String?> shortExplanation = const Value.absent(),
    Value<String?> longExplanation = const Value.absent(),
    String? sourceUrl,
    Value<String?> readingLevelSystem = const Value.absent(),
    Value<String?> readingLevelCode = const Value.absent(),
    Value<String?> readingLevelSource = const Value.absent(),
    int? fetchedAt,
    Value<int?> expiresAt = const Value.absent(),
    int? lastAccessedAt,
    int? accessCount,
  }) => DictionaryEntry(
    id: id ?? this.id,
    provider: provider ?? this.provider,
    language: language ?? this.language,
    normalizedTerm: normalizedTerm ?? this.normalizedTerm,
    displayWord: displayWord ?? this.displayWord,
    status: status ?? this.status,
    usPhonetic: usPhonetic.present ? usPhonetic.value : this.usPhonetic,
    ukPhonetic: ukPhonetic.present ? ukPhonetic.value : this.ukPhonetic,
    definitionsJson: definitionsJson.present
        ? definitionsJson.value
        : this.definitionsJson,
    otherFormsJson: otherFormsJson.present
        ? otherFormsJson.value
        : this.otherFormsJson,
    shortExplanation: shortExplanation.present
        ? shortExplanation.value
        : this.shortExplanation,
    longExplanation: longExplanation.present
        ? longExplanation.value
        : this.longExplanation,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    readingLevelSystem: readingLevelSystem.present
        ? readingLevelSystem.value
        : this.readingLevelSystem,
    readingLevelCode: readingLevelCode.present
        ? readingLevelCode.value
        : this.readingLevelCode,
    readingLevelSource: readingLevelSource.present
        ? readingLevelSource.value
        : this.readingLevelSource,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    accessCount: accessCount ?? this.accessCount,
  );
  DictionaryEntry copyWithCompanion(DictionaryEntriesCompanion data) {
    return DictionaryEntry(
      id: data.id.present ? data.id.value : this.id,
      provider: data.provider.present ? data.provider.value : this.provider,
      language: data.language.present ? data.language.value : this.language,
      normalizedTerm: data.normalizedTerm.present
          ? data.normalizedTerm.value
          : this.normalizedTerm,
      displayWord: data.displayWord.present
          ? data.displayWord.value
          : this.displayWord,
      status: data.status.present ? data.status.value : this.status,
      usPhonetic: data.usPhonetic.present
          ? data.usPhonetic.value
          : this.usPhonetic,
      ukPhonetic: data.ukPhonetic.present
          ? data.ukPhonetic.value
          : this.ukPhonetic,
      definitionsJson: data.definitionsJson.present
          ? data.definitionsJson.value
          : this.definitionsJson,
      otherFormsJson: data.otherFormsJson.present
          ? data.otherFormsJson.value
          : this.otherFormsJson,
      shortExplanation: data.shortExplanation.present
          ? data.shortExplanation.value
          : this.shortExplanation,
      longExplanation: data.longExplanation.present
          ? data.longExplanation.value
          : this.longExplanation,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      readingLevelSystem: data.readingLevelSystem.present
          ? data.readingLevelSystem.value
          : this.readingLevelSystem,
      readingLevelCode: data.readingLevelCode.present
          ? data.readingLevelCode.value
          : this.readingLevelCode,
      readingLevelSource: data.readingLevelSource.present
          ? data.readingLevelSource.value
          : this.readingLevelSource,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
      accessCount: data.accessCount.present
          ? data.accessCount.value
          : this.accessCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryEntry(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('language: $language, ')
          ..write('normalizedTerm: $normalizedTerm, ')
          ..write('displayWord: $displayWord, ')
          ..write('status: $status, ')
          ..write('usPhonetic: $usPhonetic, ')
          ..write('ukPhonetic: $ukPhonetic, ')
          ..write('definitionsJson: $definitionsJson, ')
          ..write('otherFormsJson: $otherFormsJson, ')
          ..write('shortExplanation: $shortExplanation, ')
          ..write('longExplanation: $longExplanation, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('readingLevelSystem: $readingLevelSystem, ')
          ..write('readingLevelCode: $readingLevelCode, ')
          ..write('readingLevelSource: $readingLevelSource, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('accessCount: $accessCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    provider,
    language,
    normalizedTerm,
    displayWord,
    status,
    usPhonetic,
    ukPhonetic,
    definitionsJson,
    otherFormsJson,
    shortExplanation,
    longExplanation,
    sourceUrl,
    readingLevelSystem,
    readingLevelCode,
    readingLevelSource,
    fetchedAt,
    expiresAt,
    lastAccessedAt,
    accessCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryEntry &&
          other.id == this.id &&
          other.provider == this.provider &&
          other.language == this.language &&
          other.normalizedTerm == this.normalizedTerm &&
          other.displayWord == this.displayWord &&
          other.status == this.status &&
          other.usPhonetic == this.usPhonetic &&
          other.ukPhonetic == this.ukPhonetic &&
          other.definitionsJson == this.definitionsJson &&
          other.otherFormsJson == this.otherFormsJson &&
          other.shortExplanation == this.shortExplanation &&
          other.longExplanation == this.longExplanation &&
          other.sourceUrl == this.sourceUrl &&
          other.readingLevelSystem == this.readingLevelSystem &&
          other.readingLevelCode == this.readingLevelCode &&
          other.readingLevelSource == this.readingLevelSource &&
          other.fetchedAt == this.fetchedAt &&
          other.expiresAt == this.expiresAt &&
          other.lastAccessedAt == this.lastAccessedAt &&
          other.accessCount == this.accessCount);
}

class DictionaryEntriesCompanion extends UpdateCompanion<DictionaryEntry> {
  final Value<String> id;
  final Value<String> provider;
  final Value<String> language;
  final Value<String> normalizedTerm;
  final Value<String> displayWord;
  final Value<String> status;
  final Value<String?> usPhonetic;
  final Value<String?> ukPhonetic;
  final Value<String?> definitionsJson;
  final Value<String?> otherFormsJson;
  final Value<String?> shortExplanation;
  final Value<String?> longExplanation;
  final Value<String> sourceUrl;
  final Value<String?> readingLevelSystem;
  final Value<String?> readingLevelCode;
  final Value<String?> readingLevelSource;
  final Value<int> fetchedAt;
  final Value<int?> expiresAt;
  final Value<int> lastAccessedAt;
  final Value<int> accessCount;
  final Value<int> rowid;
  const DictionaryEntriesCompanion({
    this.id = const Value.absent(),
    this.provider = const Value.absent(),
    this.language = const Value.absent(),
    this.normalizedTerm = const Value.absent(),
    this.displayWord = const Value.absent(),
    this.status = const Value.absent(),
    this.usPhonetic = const Value.absent(),
    this.ukPhonetic = const Value.absent(),
    this.definitionsJson = const Value.absent(),
    this.otherFormsJson = const Value.absent(),
    this.shortExplanation = const Value.absent(),
    this.longExplanation = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.readingLevelSystem = const Value.absent(),
    this.readingLevelCode = const Value.absent(),
    this.readingLevelSource = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.accessCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DictionaryEntriesCompanion.insert({
    required String id,
    required String provider,
    required String language,
    required String normalizedTerm,
    required String displayWord,
    required String status,
    this.usPhonetic = const Value.absent(),
    this.ukPhonetic = const Value.absent(),
    this.definitionsJson = const Value.absent(),
    this.otherFormsJson = const Value.absent(),
    this.shortExplanation = const Value.absent(),
    this.longExplanation = const Value.absent(),
    required String sourceUrl,
    this.readingLevelSystem = const Value.absent(),
    this.readingLevelCode = const Value.absent(),
    this.readingLevelSource = const Value.absent(),
    required int fetchedAt,
    this.expiresAt = const Value.absent(),
    required int lastAccessedAt,
    this.accessCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       language = Value(language),
       normalizedTerm = Value(normalizedTerm),
       displayWord = Value(displayWord),
       status = Value(status),
       sourceUrl = Value(sourceUrl),
       fetchedAt = Value(fetchedAt),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<DictionaryEntry> custom({
    Expression<String>? id,
    Expression<String>? provider,
    Expression<String>? language,
    Expression<String>? normalizedTerm,
    Expression<String>? displayWord,
    Expression<String>? status,
    Expression<String>? usPhonetic,
    Expression<String>? ukPhonetic,
    Expression<String>? definitionsJson,
    Expression<String>? otherFormsJson,
    Expression<String>? shortExplanation,
    Expression<String>? longExplanation,
    Expression<String>? sourceUrl,
    Expression<String>? readingLevelSystem,
    Expression<String>? readingLevelCode,
    Expression<String>? readingLevelSource,
    Expression<int>? fetchedAt,
    Expression<int>? expiresAt,
    Expression<int>? lastAccessedAt,
    Expression<int>? accessCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (provider != null) 'provider': provider,
      if (language != null) 'language': language,
      if (normalizedTerm != null) 'normalized_term': normalizedTerm,
      if (displayWord != null) 'display_word': displayWord,
      if (status != null) 'status': status,
      if (usPhonetic != null) 'us_phonetic': usPhonetic,
      if (ukPhonetic != null) 'uk_phonetic': ukPhonetic,
      if (definitionsJson != null) 'definitions_json': definitionsJson,
      if (otherFormsJson != null) 'other_forms_json': otherFormsJson,
      if (shortExplanation != null) 'short_explanation': shortExplanation,
      if (longExplanation != null) 'long_explanation': longExplanation,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (readingLevelSystem != null)
        'reading_level_system': readingLevelSystem,
      if (readingLevelCode != null) 'reading_level_code': readingLevelCode,
      if (readingLevelSource != null)
        'reading_level_source': readingLevelSource,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (accessCount != null) 'access_count': accessCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DictionaryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? provider,
    Value<String>? language,
    Value<String>? normalizedTerm,
    Value<String>? displayWord,
    Value<String>? status,
    Value<String?>? usPhonetic,
    Value<String?>? ukPhonetic,
    Value<String?>? definitionsJson,
    Value<String?>? otherFormsJson,
    Value<String?>? shortExplanation,
    Value<String?>? longExplanation,
    Value<String>? sourceUrl,
    Value<String?>? readingLevelSystem,
    Value<String?>? readingLevelCode,
    Value<String?>? readingLevelSource,
    Value<int>? fetchedAt,
    Value<int?>? expiresAt,
    Value<int>? lastAccessedAt,
    Value<int>? accessCount,
    Value<int>? rowid,
  }) {
    return DictionaryEntriesCompanion(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      language: language ?? this.language,
      normalizedTerm: normalizedTerm ?? this.normalizedTerm,
      displayWord: displayWord ?? this.displayWord,
      status: status ?? this.status,
      usPhonetic: usPhonetic ?? this.usPhonetic,
      ukPhonetic: ukPhonetic ?? this.ukPhonetic,
      definitionsJson: definitionsJson ?? this.definitionsJson,
      otherFormsJson: otherFormsJson ?? this.otherFormsJson,
      shortExplanation: shortExplanation ?? this.shortExplanation,
      longExplanation: longExplanation ?? this.longExplanation,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      readingLevelSystem: readingLevelSystem ?? this.readingLevelSystem,
      readingLevelCode: readingLevelCode ?? this.readingLevelCode,
      readingLevelSource: readingLevelSource ?? this.readingLevelSource,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      accessCount: accessCount ?? this.accessCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (normalizedTerm.present) {
      map['normalized_term'] = Variable<String>(normalizedTerm.value);
    }
    if (displayWord.present) {
      map['display_word'] = Variable<String>(displayWord.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (usPhonetic.present) {
      map['us_phonetic'] = Variable<String>(usPhonetic.value);
    }
    if (ukPhonetic.present) {
      map['uk_phonetic'] = Variable<String>(ukPhonetic.value);
    }
    if (definitionsJson.present) {
      map['definitions_json'] = Variable<String>(definitionsJson.value);
    }
    if (otherFormsJson.present) {
      map['other_forms_json'] = Variable<String>(otherFormsJson.value);
    }
    if (shortExplanation.present) {
      map['short_explanation'] = Variable<String>(shortExplanation.value);
    }
    if (longExplanation.present) {
      map['long_explanation'] = Variable<String>(longExplanation.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (readingLevelSystem.present) {
      map['reading_level_system'] = Variable<String>(readingLevelSystem.value);
    }
    if (readingLevelCode.present) {
      map['reading_level_code'] = Variable<String>(readingLevelCode.value);
    }
    if (readingLevelSource.present) {
      map['reading_level_source'] = Variable<String>(readingLevelSource.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<int>(lastAccessedAt.value);
    }
    if (accessCount.present) {
      map['access_count'] = Variable<int>(accessCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('provider: $provider, ')
          ..write('language: $language, ')
          ..write('normalizedTerm: $normalizedTerm, ')
          ..write('displayWord: $displayWord, ')
          ..write('status: $status, ')
          ..write('usPhonetic: $usPhonetic, ')
          ..write('ukPhonetic: $ukPhonetic, ')
          ..write('definitionsJson: $definitionsJson, ')
          ..write('otherFormsJson: $otherFormsJson, ')
          ..write('shortExplanation: $shortExplanation, ')
          ..write('longExplanation: $longExplanation, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('readingLevelSystem: $readingLevelSystem, ')
          ..write('readingLevelCode: $readingLevelCode, ')
          ..write('readingLevelSource: $readingLevelSource, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('accessCount: $accessCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteWordsTable extends FavoriteWords
    with TableInfo<$FavoriteWordsTable, FavoriteWord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteWordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dictionaryEntryIdMeta = const VerificationMeta(
    'dictionaryEntryId',
  );
  @override
  late final GeneratedColumn<String> dictionaryEntryId =
      GeneratedColumn<String>(
        'dictionary_entry_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _contextTextMeta = const VerificationMeta(
    'contextText',
  );
  @override
  late final GeneratedColumn<String> contextText = GeneratedColumn<String>(
    'context_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectionStartMeta = const VerificationMeta(
    'selectionStart',
  );
  @override
  late final GeneratedColumn<int> selectionStart = GeneratedColumn<int>(
    'selection_start',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _selectionEndMeta = const VerificationMeta(
    'selectionEnd',
  );
  @override
  late final GeneratedColumn<int> selectionEnd = GeneratedColumn<int>(
    'selection_end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceBookIdMeta = const VerificationMeta(
    'sourceBookId',
  );
  @override
  late final GeneratedColumn<String> sourceBookId = GeneratedColumn<String>(
    'source_book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceBookTitleMeta = const VerificationMeta(
    'sourceBookTitle',
  );
  @override
  late final GeneratedColumn<String> sourceBookTitle = GeneratedColumn<String>(
    'source_book_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceChapterIdMeta = const VerificationMeta(
    'sourceChapterId',
  );
  @override
  late final GeneratedColumn<String> sourceChapterId = GeneratedColumn<String>(
    'source_chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceChapterTitleMeta =
      const VerificationMeta('sourceChapterTitle');
  @override
  late final GeneratedColumn<String> sourceChapterTitle =
      GeneratedColumn<String>(
        'source_chapter_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourceParagraphIdMeta = const VerificationMeta(
    'sourceParagraphId',
  );
  @override
  late final GeneratedColumn<String> sourceParagraphId =
      GeneratedColumn<String>(
        'source_paragraph_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sourceLineIdMeta = const VerificationMeta(
    'sourceLineId',
  );
  @override
  late final GeneratedColumn<String> sourceLineId = GeneratedColumn<String>(
    'source_line_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioStartMsMeta = const VerificationMeta(
    'audioStartMs',
  );
  @override
  late final GeneratedColumn<int> audioStartMs = GeneratedColumn<int>(
    'audio_start_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioEndMsMeta = const VerificationMeta(
    'audioEndMs',
  );
  @override
  late final GeneratedColumn<int> audioEndMs = GeneratedColumn<int>(
    'audio_end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<int> favoritedAt = GeneratedColumn<int>(
    'favorited_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dictionaryEntryId,
    contextText,
    selectionStart,
    selectionEnd,
    sourceBookId,
    sourceBookTitle,
    sourceChapterId,
    sourceChapterTitle,
    sourceParagraphId,
    sourceLineId,
    audioStartMs,
    audioEndMs,
    favoritedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_words';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteWord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dictionary_entry_id')) {
      context.handle(
        _dictionaryEntryIdMeta,
        dictionaryEntryId.isAcceptableOrUnknown(
          data['dictionary_entry_id']!,
          _dictionaryEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dictionaryEntryIdMeta);
    }
    if (data.containsKey('context_text')) {
      context.handle(
        _contextTextMeta,
        contextText.isAcceptableOrUnknown(
          data['context_text']!,
          _contextTextMeta,
        ),
      );
    }
    if (data.containsKey('selection_start')) {
      context.handle(
        _selectionStartMeta,
        selectionStart.isAcceptableOrUnknown(
          data['selection_start']!,
          _selectionStartMeta,
        ),
      );
    }
    if (data.containsKey('selection_end')) {
      context.handle(
        _selectionEndMeta,
        selectionEnd.isAcceptableOrUnknown(
          data['selection_end']!,
          _selectionEndMeta,
        ),
      );
    }
    if (data.containsKey('source_book_id')) {
      context.handle(
        _sourceBookIdMeta,
        sourceBookId.isAcceptableOrUnknown(
          data['source_book_id']!,
          _sourceBookIdMeta,
        ),
      );
    }
    if (data.containsKey('source_book_title')) {
      context.handle(
        _sourceBookTitleMeta,
        sourceBookTitle.isAcceptableOrUnknown(
          data['source_book_title']!,
          _sourceBookTitleMeta,
        ),
      );
    }
    if (data.containsKey('source_chapter_id')) {
      context.handle(
        _sourceChapterIdMeta,
        sourceChapterId.isAcceptableOrUnknown(
          data['source_chapter_id']!,
          _sourceChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('source_chapter_title')) {
      context.handle(
        _sourceChapterTitleMeta,
        sourceChapterTitle.isAcceptableOrUnknown(
          data['source_chapter_title']!,
          _sourceChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('source_paragraph_id')) {
      context.handle(
        _sourceParagraphIdMeta,
        sourceParagraphId.isAcceptableOrUnknown(
          data['source_paragraph_id']!,
          _sourceParagraphIdMeta,
        ),
      );
    }
    if (data.containsKey('source_line_id')) {
      context.handle(
        _sourceLineIdMeta,
        sourceLineId.isAcceptableOrUnknown(
          data['source_line_id']!,
          _sourceLineIdMeta,
        ),
      );
    }
    if (data.containsKey('audio_start_ms')) {
      context.handle(
        _audioStartMsMeta,
        audioStartMs.isAcceptableOrUnknown(
          data['audio_start_ms']!,
          _audioStartMsMeta,
        ),
      );
    }
    if (data.containsKey('audio_end_ms')) {
      context.handle(
        _audioEndMsMeta,
        audioEndMs.isAcceptableOrUnknown(
          data['audio_end_ms']!,
          _audioEndMsMeta,
        ),
      );
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {dictionaryEntryId},
  ];
  @override
  FavoriteWord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteWord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dictionaryEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dictionary_entry_id'],
      )!,
      contextText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_text'],
      ),
      selectionStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}selection_start'],
      ),
      selectionEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}selection_end'],
      ),
      sourceBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_book_id'],
      ),
      sourceBookTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_book_title'],
      ),
      sourceChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_chapter_id'],
      ),
      sourceChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_chapter_title'],
      ),
      sourceParagraphId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_paragraph_id'],
      ),
      sourceLineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_line_id'],
      ),
      audioStartMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_start_ms'],
      ),
      audioEndMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_end_ms'],
      ),
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorited_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FavoriteWordsTable createAlias(String alias) {
    return $FavoriteWordsTable(attachedDatabase, alias);
  }
}

class FavoriteWord extends DataClass implements Insertable<FavoriteWord> {
  final String id;
  final String dictionaryEntryId;
  final String? contextText;
  final int? selectionStart;
  final int? selectionEnd;
  final String? sourceBookId;
  final String? sourceBookTitle;
  final String? sourceChapterId;
  final String? sourceChapterTitle;
  final String? sourceParagraphId;
  final String? sourceLineId;
  final int? audioStartMs;
  final int? audioEndMs;
  final int favoritedAt;
  final int updatedAt;
  const FavoriteWord({
    required this.id,
    required this.dictionaryEntryId,
    this.contextText,
    this.selectionStart,
    this.selectionEnd,
    this.sourceBookId,
    this.sourceBookTitle,
    this.sourceChapterId,
    this.sourceChapterTitle,
    this.sourceParagraphId,
    this.sourceLineId,
    this.audioStartMs,
    this.audioEndMs,
    required this.favoritedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dictionary_entry_id'] = Variable<String>(dictionaryEntryId);
    if (!nullToAbsent || contextText != null) {
      map['context_text'] = Variable<String>(contextText);
    }
    if (!nullToAbsent || selectionStart != null) {
      map['selection_start'] = Variable<int>(selectionStart);
    }
    if (!nullToAbsent || selectionEnd != null) {
      map['selection_end'] = Variable<int>(selectionEnd);
    }
    if (!nullToAbsent || sourceBookId != null) {
      map['source_book_id'] = Variable<String>(sourceBookId);
    }
    if (!nullToAbsent || sourceBookTitle != null) {
      map['source_book_title'] = Variable<String>(sourceBookTitle);
    }
    if (!nullToAbsent || sourceChapterId != null) {
      map['source_chapter_id'] = Variable<String>(sourceChapterId);
    }
    if (!nullToAbsent || sourceChapterTitle != null) {
      map['source_chapter_title'] = Variable<String>(sourceChapterTitle);
    }
    if (!nullToAbsent || sourceParagraphId != null) {
      map['source_paragraph_id'] = Variable<String>(sourceParagraphId);
    }
    if (!nullToAbsent || sourceLineId != null) {
      map['source_line_id'] = Variable<String>(sourceLineId);
    }
    if (!nullToAbsent || audioStartMs != null) {
      map['audio_start_ms'] = Variable<int>(audioStartMs);
    }
    if (!nullToAbsent || audioEndMs != null) {
      map['audio_end_ms'] = Variable<int>(audioEndMs);
    }
    map['favorited_at'] = Variable<int>(favoritedAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  FavoriteWordsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteWordsCompanion(
      id: Value(id),
      dictionaryEntryId: Value(dictionaryEntryId),
      contextText: contextText == null && nullToAbsent
          ? const Value.absent()
          : Value(contextText),
      selectionStart: selectionStart == null && nullToAbsent
          ? const Value.absent()
          : Value(selectionStart),
      selectionEnd: selectionEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(selectionEnd),
      sourceBookId: sourceBookId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceBookId),
      sourceBookTitle: sourceBookTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceBookTitle),
      sourceChapterId: sourceChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceChapterId),
      sourceChapterTitle: sourceChapterTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceChapterTitle),
      sourceParagraphId: sourceParagraphId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceParagraphId),
      sourceLineId: sourceLineId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceLineId),
      audioStartMs: audioStartMs == null && nullToAbsent
          ? const Value.absent()
          : Value(audioStartMs),
      audioEndMs: audioEndMs == null && nullToAbsent
          ? const Value.absent()
          : Value(audioEndMs),
      favoritedAt: Value(favoritedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FavoriteWord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteWord(
      id: serializer.fromJson<String>(json['id']),
      dictionaryEntryId: serializer.fromJson<String>(json['dictionaryEntryId']),
      contextText: serializer.fromJson<String?>(json['contextText']),
      selectionStart: serializer.fromJson<int?>(json['selectionStart']),
      selectionEnd: serializer.fromJson<int?>(json['selectionEnd']),
      sourceBookId: serializer.fromJson<String?>(json['sourceBookId']),
      sourceBookTitle: serializer.fromJson<String?>(json['sourceBookTitle']),
      sourceChapterId: serializer.fromJson<String?>(json['sourceChapterId']),
      sourceChapterTitle: serializer.fromJson<String?>(
        json['sourceChapterTitle'],
      ),
      sourceParagraphId: serializer.fromJson<String?>(
        json['sourceParagraphId'],
      ),
      sourceLineId: serializer.fromJson<String?>(json['sourceLineId']),
      audioStartMs: serializer.fromJson<int?>(json['audioStartMs']),
      audioEndMs: serializer.fromJson<int?>(json['audioEndMs']),
      favoritedAt: serializer.fromJson<int>(json['favoritedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dictionaryEntryId': serializer.toJson<String>(dictionaryEntryId),
      'contextText': serializer.toJson<String?>(contextText),
      'selectionStart': serializer.toJson<int?>(selectionStart),
      'selectionEnd': serializer.toJson<int?>(selectionEnd),
      'sourceBookId': serializer.toJson<String?>(sourceBookId),
      'sourceBookTitle': serializer.toJson<String?>(sourceBookTitle),
      'sourceChapterId': serializer.toJson<String?>(sourceChapterId),
      'sourceChapterTitle': serializer.toJson<String?>(sourceChapterTitle),
      'sourceParagraphId': serializer.toJson<String?>(sourceParagraphId),
      'sourceLineId': serializer.toJson<String?>(sourceLineId),
      'audioStartMs': serializer.toJson<int?>(audioStartMs),
      'audioEndMs': serializer.toJson<int?>(audioEndMs),
      'favoritedAt': serializer.toJson<int>(favoritedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  FavoriteWord copyWith({
    String? id,
    String? dictionaryEntryId,
    Value<String?> contextText = const Value.absent(),
    Value<int?> selectionStart = const Value.absent(),
    Value<int?> selectionEnd = const Value.absent(),
    Value<String?> sourceBookId = const Value.absent(),
    Value<String?> sourceBookTitle = const Value.absent(),
    Value<String?> sourceChapterId = const Value.absent(),
    Value<String?> sourceChapterTitle = const Value.absent(),
    Value<String?> sourceParagraphId = const Value.absent(),
    Value<String?> sourceLineId = const Value.absent(),
    Value<int?> audioStartMs = const Value.absent(),
    Value<int?> audioEndMs = const Value.absent(),
    int? favoritedAt,
    int? updatedAt,
  }) => FavoriteWord(
    id: id ?? this.id,
    dictionaryEntryId: dictionaryEntryId ?? this.dictionaryEntryId,
    contextText: contextText.present ? contextText.value : this.contextText,
    selectionStart: selectionStart.present
        ? selectionStart.value
        : this.selectionStart,
    selectionEnd: selectionEnd.present ? selectionEnd.value : this.selectionEnd,
    sourceBookId: sourceBookId.present ? sourceBookId.value : this.sourceBookId,
    sourceBookTitle: sourceBookTitle.present
        ? sourceBookTitle.value
        : this.sourceBookTitle,
    sourceChapterId: sourceChapterId.present
        ? sourceChapterId.value
        : this.sourceChapterId,
    sourceChapterTitle: sourceChapterTitle.present
        ? sourceChapterTitle.value
        : this.sourceChapterTitle,
    sourceParagraphId: sourceParagraphId.present
        ? sourceParagraphId.value
        : this.sourceParagraphId,
    sourceLineId: sourceLineId.present ? sourceLineId.value : this.sourceLineId,
    audioStartMs: audioStartMs.present ? audioStartMs.value : this.audioStartMs,
    audioEndMs: audioEndMs.present ? audioEndMs.value : this.audioEndMs,
    favoritedAt: favoritedAt ?? this.favoritedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FavoriteWord copyWithCompanion(FavoriteWordsCompanion data) {
    return FavoriteWord(
      id: data.id.present ? data.id.value : this.id,
      dictionaryEntryId: data.dictionaryEntryId.present
          ? data.dictionaryEntryId.value
          : this.dictionaryEntryId,
      contextText: data.contextText.present
          ? data.contextText.value
          : this.contextText,
      selectionStart: data.selectionStart.present
          ? data.selectionStart.value
          : this.selectionStart,
      selectionEnd: data.selectionEnd.present
          ? data.selectionEnd.value
          : this.selectionEnd,
      sourceBookId: data.sourceBookId.present
          ? data.sourceBookId.value
          : this.sourceBookId,
      sourceBookTitle: data.sourceBookTitle.present
          ? data.sourceBookTitle.value
          : this.sourceBookTitle,
      sourceChapterId: data.sourceChapterId.present
          ? data.sourceChapterId.value
          : this.sourceChapterId,
      sourceChapterTitle: data.sourceChapterTitle.present
          ? data.sourceChapterTitle.value
          : this.sourceChapterTitle,
      sourceParagraphId: data.sourceParagraphId.present
          ? data.sourceParagraphId.value
          : this.sourceParagraphId,
      sourceLineId: data.sourceLineId.present
          ? data.sourceLineId.value
          : this.sourceLineId,
      audioStartMs: data.audioStartMs.present
          ? data.audioStartMs.value
          : this.audioStartMs,
      audioEndMs: data.audioEndMs.present
          ? data.audioEndMs.value
          : this.audioEndMs,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteWord(')
          ..write('id: $id, ')
          ..write('dictionaryEntryId: $dictionaryEntryId, ')
          ..write('contextText: $contextText, ')
          ..write('selectionStart: $selectionStart, ')
          ..write('selectionEnd: $selectionEnd, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourceBookTitle: $sourceBookTitle, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('sourceChapterTitle: $sourceChapterTitle, ')
          ..write('sourceParagraphId: $sourceParagraphId, ')
          ..write('sourceLineId: $sourceLineId, ')
          ..write('audioStartMs: $audioStartMs, ')
          ..write('audioEndMs: $audioEndMs, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dictionaryEntryId,
    contextText,
    selectionStart,
    selectionEnd,
    sourceBookId,
    sourceBookTitle,
    sourceChapterId,
    sourceChapterTitle,
    sourceParagraphId,
    sourceLineId,
    audioStartMs,
    audioEndMs,
    favoritedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteWord &&
          other.id == this.id &&
          other.dictionaryEntryId == this.dictionaryEntryId &&
          other.contextText == this.contextText &&
          other.selectionStart == this.selectionStart &&
          other.selectionEnd == this.selectionEnd &&
          other.sourceBookId == this.sourceBookId &&
          other.sourceBookTitle == this.sourceBookTitle &&
          other.sourceChapterId == this.sourceChapterId &&
          other.sourceChapterTitle == this.sourceChapterTitle &&
          other.sourceParagraphId == this.sourceParagraphId &&
          other.sourceLineId == this.sourceLineId &&
          other.audioStartMs == this.audioStartMs &&
          other.audioEndMs == this.audioEndMs &&
          other.favoritedAt == this.favoritedAt &&
          other.updatedAt == this.updatedAt);
}

class FavoriteWordsCompanion extends UpdateCompanion<FavoriteWord> {
  final Value<String> id;
  final Value<String> dictionaryEntryId;
  final Value<String?> contextText;
  final Value<int?> selectionStart;
  final Value<int?> selectionEnd;
  final Value<String?> sourceBookId;
  final Value<String?> sourceBookTitle;
  final Value<String?> sourceChapterId;
  final Value<String?> sourceChapterTitle;
  final Value<String?> sourceParagraphId;
  final Value<String?> sourceLineId;
  final Value<int?> audioStartMs;
  final Value<int?> audioEndMs;
  final Value<int> favoritedAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const FavoriteWordsCompanion({
    this.id = const Value.absent(),
    this.dictionaryEntryId = const Value.absent(),
    this.contextText = const Value.absent(),
    this.selectionStart = const Value.absent(),
    this.selectionEnd = const Value.absent(),
    this.sourceBookId = const Value.absent(),
    this.sourceBookTitle = const Value.absent(),
    this.sourceChapterId = const Value.absent(),
    this.sourceChapterTitle = const Value.absent(),
    this.sourceParagraphId = const Value.absent(),
    this.sourceLineId = const Value.absent(),
    this.audioStartMs = const Value.absent(),
    this.audioEndMs = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteWordsCompanion.insert({
    required String id,
    required String dictionaryEntryId,
    this.contextText = const Value.absent(),
    this.selectionStart = const Value.absent(),
    this.selectionEnd = const Value.absent(),
    this.sourceBookId = const Value.absent(),
    this.sourceBookTitle = const Value.absent(),
    this.sourceChapterId = const Value.absent(),
    this.sourceChapterTitle = const Value.absent(),
    this.sourceParagraphId = const Value.absent(),
    this.sourceLineId = const Value.absent(),
    this.audioStartMs = const Value.absent(),
    this.audioEndMs = const Value.absent(),
    required int favoritedAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dictionaryEntryId = Value(dictionaryEntryId),
       favoritedAt = Value(favoritedAt),
       updatedAt = Value(updatedAt);
  static Insertable<FavoriteWord> custom({
    Expression<String>? id,
    Expression<String>? dictionaryEntryId,
    Expression<String>? contextText,
    Expression<int>? selectionStart,
    Expression<int>? selectionEnd,
    Expression<String>? sourceBookId,
    Expression<String>? sourceBookTitle,
    Expression<String>? sourceChapterId,
    Expression<String>? sourceChapterTitle,
    Expression<String>? sourceParagraphId,
    Expression<String>? sourceLineId,
    Expression<int>? audioStartMs,
    Expression<int>? audioEndMs,
    Expression<int>? favoritedAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dictionaryEntryId != null) 'dictionary_entry_id': dictionaryEntryId,
      if (contextText != null) 'context_text': contextText,
      if (selectionStart != null) 'selection_start': selectionStart,
      if (selectionEnd != null) 'selection_end': selectionEnd,
      if (sourceBookId != null) 'source_book_id': sourceBookId,
      if (sourceBookTitle != null) 'source_book_title': sourceBookTitle,
      if (sourceChapterId != null) 'source_chapter_id': sourceChapterId,
      if (sourceChapterTitle != null)
        'source_chapter_title': sourceChapterTitle,
      if (sourceParagraphId != null) 'source_paragraph_id': sourceParagraphId,
      if (sourceLineId != null) 'source_line_id': sourceLineId,
      if (audioStartMs != null) 'audio_start_ms': audioStartMs,
      if (audioEndMs != null) 'audio_end_ms': audioEndMs,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteWordsCompanion copyWith({
    Value<String>? id,
    Value<String>? dictionaryEntryId,
    Value<String?>? contextText,
    Value<int?>? selectionStart,
    Value<int?>? selectionEnd,
    Value<String?>? sourceBookId,
    Value<String?>? sourceBookTitle,
    Value<String?>? sourceChapterId,
    Value<String?>? sourceChapterTitle,
    Value<String?>? sourceParagraphId,
    Value<String?>? sourceLineId,
    Value<int?>? audioStartMs,
    Value<int?>? audioEndMs,
    Value<int>? favoritedAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return FavoriteWordsCompanion(
      id: id ?? this.id,
      dictionaryEntryId: dictionaryEntryId ?? this.dictionaryEntryId,
      contextText: contextText ?? this.contextText,
      selectionStart: selectionStart ?? this.selectionStart,
      selectionEnd: selectionEnd ?? this.selectionEnd,
      sourceBookId: sourceBookId ?? this.sourceBookId,
      sourceBookTitle: sourceBookTitle ?? this.sourceBookTitle,
      sourceChapterId: sourceChapterId ?? this.sourceChapterId,
      sourceChapterTitle: sourceChapterTitle ?? this.sourceChapterTitle,
      sourceParagraphId: sourceParagraphId ?? this.sourceParagraphId,
      sourceLineId: sourceLineId ?? this.sourceLineId,
      audioStartMs: audioStartMs ?? this.audioStartMs,
      audioEndMs: audioEndMs ?? this.audioEndMs,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dictionaryEntryId.present) {
      map['dictionary_entry_id'] = Variable<String>(dictionaryEntryId.value);
    }
    if (contextText.present) {
      map['context_text'] = Variable<String>(contextText.value);
    }
    if (selectionStart.present) {
      map['selection_start'] = Variable<int>(selectionStart.value);
    }
    if (selectionEnd.present) {
      map['selection_end'] = Variable<int>(selectionEnd.value);
    }
    if (sourceBookId.present) {
      map['source_book_id'] = Variable<String>(sourceBookId.value);
    }
    if (sourceBookTitle.present) {
      map['source_book_title'] = Variable<String>(sourceBookTitle.value);
    }
    if (sourceChapterId.present) {
      map['source_chapter_id'] = Variable<String>(sourceChapterId.value);
    }
    if (sourceChapterTitle.present) {
      map['source_chapter_title'] = Variable<String>(sourceChapterTitle.value);
    }
    if (sourceParagraphId.present) {
      map['source_paragraph_id'] = Variable<String>(sourceParagraphId.value);
    }
    if (sourceLineId.present) {
      map['source_line_id'] = Variable<String>(sourceLineId.value);
    }
    if (audioStartMs.present) {
      map['audio_start_ms'] = Variable<int>(audioStartMs.value);
    }
    if (audioEndMs.present) {
      map['audio_end_ms'] = Variable<int>(audioEndMs.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<int>(favoritedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteWordsCompanion(')
          ..write('id: $id, ')
          ..write('dictionaryEntryId: $dictionaryEntryId, ')
          ..write('contextText: $contextText, ')
          ..write('selectionStart: $selectionStart, ')
          ..write('selectionEnd: $selectionEnd, ')
          ..write('sourceBookId: $sourceBookId, ')
          ..write('sourceBookTitle: $sourceBookTitle, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('sourceChapterTitle: $sourceChapterTitle, ')
          ..write('sourceParagraphId: $sourceParagraphId, ')
          ..write('sourceLineId: $sourceLineId, ')
          ..write('audioStartMs: $audioStartMs, ')
          ..write('audioEndMs: $audioEndMs, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PodcastShowsTable extends PodcastShows
    with TableInfo<$PodcastShowsTable, PodcastShow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastShowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feedUrlMeta = const VerificationMeta(
    'feedUrl',
  );
  @override
  late final GeneratedColumn<String> feedUrl = GeneratedColumn<String>(
    'feed_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _websiteUrlMeta = const VerificationMeta(
    'websiteUrl',
  );
  @override
  late final GeneratedColumn<String> websiteUrl = GeneratedColumn<String>(
    'website_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesJsonMeta = const VerificationMeta(
    'categoriesJson',
  );
  @override
  late final GeneratedColumn<String> categoriesJson = GeneratedColumn<String>(
    'categories_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subscribedAtMeta = const VerificationMeta(
    'subscribedAt',
  );
  @override
  late final GeneratedColumn<int> subscribedAt = GeneratedColumn<int>(
    'subscribed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastRefreshedAtMeta = const VerificationMeta(
    'lastRefreshedAt',
  );
  @override
  late final GeneratedColumn<int> lastRefreshedAt = GeneratedColumn<int>(
    'last_refreshed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    feedUrl,
    title,
    author,
    description,
    imageUrl,
    language,
    websiteUrl,
    categoriesJson,
    subscribedAt,
    lastRefreshedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'podcast_shows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PodcastShow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('feed_url')) {
      context.handle(
        _feedUrlMeta,
        feedUrl.isAcceptableOrUnknown(data['feed_url']!, _feedUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_feedUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('website_url')) {
      context.handle(
        _websiteUrlMeta,
        websiteUrl.isAcceptableOrUnknown(data['website_url']!, _websiteUrlMeta),
      );
    }
    if (data.containsKey('categories_json')) {
      context.handle(
        _categoriesJsonMeta,
        categoriesJson.isAcceptableOrUnknown(
          data['categories_json']!,
          _categoriesJsonMeta,
        ),
      );
    }
    if (data.containsKey('subscribed_at')) {
      context.handle(
        _subscribedAtMeta,
        subscribedAt.isAcceptableOrUnknown(
          data['subscribed_at']!,
          _subscribedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subscribedAtMeta);
    }
    if (data.containsKey('last_refreshed_at')) {
      context.handle(
        _lastRefreshedAtMeta,
        lastRefreshedAt.isAcceptableOrUnknown(
          data['last_refreshed_at']!,
          _lastRefreshedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastRefreshedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {feedUrl},
  ];
  @override
  PodcastShow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PodcastShow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      feedUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      websiteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website_url'],
      ),
      categoriesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories_json'],
      ),
      subscribedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subscribed_at'],
      )!,
      lastRefreshedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_refreshed_at'],
      )!,
    );
  }

  @override
  $PodcastShowsTable createAlias(String alias) {
    return $PodcastShowsTable(attachedDatabase, alias);
  }
}

class PodcastShow extends DataClass implements Insertable<PodcastShow> {
  final String id;
  final String feedUrl;
  final String title;
  final String? author;
  final String description;
  final String? imageUrl;
  final String? language;
  final String? websiteUrl;
  final String? categoriesJson;
  final int subscribedAt;
  final int lastRefreshedAt;
  const PodcastShow({
    required this.id,
    required this.feedUrl,
    required this.title,
    this.author,
    required this.description,
    this.imageUrl,
    this.language,
    this.websiteUrl,
    this.categoriesJson,
    required this.subscribedAt,
    required this.lastRefreshedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['feed_url'] = Variable<String>(feedUrl);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || websiteUrl != null) {
      map['website_url'] = Variable<String>(websiteUrl);
    }
    if (!nullToAbsent || categoriesJson != null) {
      map['categories_json'] = Variable<String>(categoriesJson);
    }
    map['subscribed_at'] = Variable<int>(subscribedAt);
    map['last_refreshed_at'] = Variable<int>(lastRefreshedAt);
    return map;
  }

  PodcastShowsCompanion toCompanion(bool nullToAbsent) {
    return PodcastShowsCompanion(
      id: Value(id),
      feedUrl: Value(feedUrl),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      description: Value(description),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      websiteUrl: websiteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(websiteUrl),
      categoriesJson: categoriesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(categoriesJson),
      subscribedAt: Value(subscribedAt),
      lastRefreshedAt: Value(lastRefreshedAt),
    );
  }

  factory PodcastShow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PodcastShow(
      id: serializer.fromJson<String>(json['id']),
      feedUrl: serializer.fromJson<String>(json['feedUrl']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      description: serializer.fromJson<String>(json['description']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      language: serializer.fromJson<String?>(json['language']),
      websiteUrl: serializer.fromJson<String?>(json['websiteUrl']),
      categoriesJson: serializer.fromJson<String?>(json['categoriesJson']),
      subscribedAt: serializer.fromJson<int>(json['subscribedAt']),
      lastRefreshedAt: serializer.fromJson<int>(json['lastRefreshedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'feedUrl': serializer.toJson<String>(feedUrl),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'description': serializer.toJson<String>(description),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'language': serializer.toJson<String?>(language),
      'websiteUrl': serializer.toJson<String?>(websiteUrl),
      'categoriesJson': serializer.toJson<String?>(categoriesJson),
      'subscribedAt': serializer.toJson<int>(subscribedAt),
      'lastRefreshedAt': serializer.toJson<int>(lastRefreshedAt),
    };
  }

  PodcastShow copyWith({
    String? id,
    String? feedUrl,
    String? title,
    Value<String?> author = const Value.absent(),
    String? description,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> language = const Value.absent(),
    Value<String?> websiteUrl = const Value.absent(),
    Value<String?> categoriesJson = const Value.absent(),
    int? subscribedAt,
    int? lastRefreshedAt,
  }) => PodcastShow(
    id: id ?? this.id,
    feedUrl: feedUrl ?? this.feedUrl,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    description: description ?? this.description,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    language: language.present ? language.value : this.language,
    websiteUrl: websiteUrl.present ? websiteUrl.value : this.websiteUrl,
    categoriesJson: categoriesJson.present
        ? categoriesJson.value
        : this.categoriesJson,
    subscribedAt: subscribedAt ?? this.subscribedAt,
    lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
  );
  PodcastShow copyWithCompanion(PodcastShowsCompanion data) {
    return PodcastShow(
      id: data.id.present ? data.id.value : this.id,
      feedUrl: data.feedUrl.present ? data.feedUrl.value : this.feedUrl,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      description: data.description.present
          ? data.description.value
          : this.description,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      language: data.language.present ? data.language.value : this.language,
      websiteUrl: data.websiteUrl.present
          ? data.websiteUrl.value
          : this.websiteUrl,
      categoriesJson: data.categoriesJson.present
          ? data.categoriesJson.value
          : this.categoriesJson,
      subscribedAt: data.subscribedAt.present
          ? data.subscribedAt.value
          : this.subscribedAt,
      lastRefreshedAt: data.lastRefreshedAt.present
          ? data.lastRefreshedAt.value
          : this.lastRefreshedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PodcastShow(')
          ..write('id: $id, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('language: $language, ')
          ..write('websiteUrl: $websiteUrl, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('lastRefreshedAt: $lastRefreshedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    feedUrl,
    title,
    author,
    description,
    imageUrl,
    language,
    websiteUrl,
    categoriesJson,
    subscribedAt,
    lastRefreshedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PodcastShow &&
          other.id == this.id &&
          other.feedUrl == this.feedUrl &&
          other.title == this.title &&
          other.author == this.author &&
          other.description == this.description &&
          other.imageUrl == this.imageUrl &&
          other.language == this.language &&
          other.websiteUrl == this.websiteUrl &&
          other.categoriesJson == this.categoriesJson &&
          other.subscribedAt == this.subscribedAt &&
          other.lastRefreshedAt == this.lastRefreshedAt);
}

class PodcastShowsCompanion extends UpdateCompanion<PodcastShow> {
  final Value<String> id;
  final Value<String> feedUrl;
  final Value<String> title;
  final Value<String?> author;
  final Value<String> description;
  final Value<String?> imageUrl;
  final Value<String?> language;
  final Value<String?> websiteUrl;
  final Value<String?> categoriesJson;
  final Value<int> subscribedAt;
  final Value<int> lastRefreshedAt;
  final Value<int> rowid;
  const PodcastShowsCompanion({
    this.id = const Value.absent(),
    this.feedUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.language = const Value.absent(),
    this.websiteUrl = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.subscribedAt = const Value.absent(),
    this.lastRefreshedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PodcastShowsCompanion.insert({
    required String id,
    required String feedUrl,
    required String title,
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.language = const Value.absent(),
    this.websiteUrl = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    required int subscribedAt,
    required int lastRefreshedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       feedUrl = Value(feedUrl),
       title = Value(title),
       subscribedAt = Value(subscribedAt),
       lastRefreshedAt = Value(lastRefreshedAt);
  static Insertable<PodcastShow> custom({
    Expression<String>? id,
    Expression<String>? feedUrl,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? description,
    Expression<String>? imageUrl,
    Expression<String>? language,
    Expression<String>? websiteUrl,
    Expression<String>? categoriesJson,
    Expression<int>? subscribedAt,
    Expression<int>? lastRefreshedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (feedUrl != null) 'feed_url': feedUrl,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (language != null) 'language': language,
      if (websiteUrl != null) 'website_url': websiteUrl,
      if (categoriesJson != null) 'categories_json': categoriesJson,
      if (subscribedAt != null) 'subscribed_at': subscribedAt,
      if (lastRefreshedAt != null) 'last_refreshed_at': lastRefreshedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PodcastShowsCompanion copyWith({
    Value<String>? id,
    Value<String>? feedUrl,
    Value<String>? title,
    Value<String?>? author,
    Value<String>? description,
    Value<String?>? imageUrl,
    Value<String?>? language,
    Value<String?>? websiteUrl,
    Value<String?>? categoriesJson,
    Value<int>? subscribedAt,
    Value<int>? lastRefreshedAt,
    Value<int>? rowid,
  }) {
    return PodcastShowsCompanion(
      id: id ?? this.id,
      feedUrl: feedUrl ?? this.feedUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      language: language ?? this.language,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      categoriesJson: categoriesJson ?? this.categoriesJson,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (feedUrl.present) {
      map['feed_url'] = Variable<String>(feedUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (websiteUrl.present) {
      map['website_url'] = Variable<String>(websiteUrl.value);
    }
    if (categoriesJson.present) {
      map['categories_json'] = Variable<String>(categoriesJson.value);
    }
    if (subscribedAt.present) {
      map['subscribed_at'] = Variable<int>(subscribedAt.value);
    }
    if (lastRefreshedAt.present) {
      map['last_refreshed_at'] = Variable<int>(lastRefreshedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PodcastShowsCompanion(')
          ..write('id: $id, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('language: $language, ')
          ..write('websiteUrl: $websiteUrl, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('lastRefreshedAt: $lastRefreshedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PodcastEpisodesTable extends PodcastEpisodes
    with TableInfo<$PodcastEpisodesTable, PodcastEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _showIdMeta = const VerificationMeta('showId');
  @override
  late final GeneratedColumn<String> showId = GeneratedColumn<String>(
    'show_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _guidMeta = const VerificationMeta('guid');
  @override
  late final GeneratedColumn<String> guid = GeneratedColumn<String>(
    'guid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<int> publishedAt = GeneratedColumn<int>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playbackPositionMsMeta =
      const VerificationMeta('playbackPositionMs');
  @override
  late final GeneratedColumn<int> playbackPositionMs = GeneratedColumn<int>(
    'playback_position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
    'last_played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPlayedMeta = const VerificationMeta(
    'isPlayed',
  );
  @override
  late final GeneratedColumn<bool> isPlayed = GeneratedColumn<bool>(
    'is_played',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_played" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localAudioPathMeta = const VerificationMeta(
    'localAudioPath',
  );
  @override
  late final GeneratedColumn<String> localAudioPath = GeneratedColumn<String>(
    'local_audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptJsonMeta = const VerificationMeta(
    'transcriptJson',
  );
  @override
  late final GeneratedColumn<String> transcriptJson = GeneratedColumn<String>(
    'transcript_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptLanguageMeta =
      const VerificationMeta('transcriptLanguage');
  @override
  late final GeneratedColumn<String> transcriptLanguage =
      GeneratedColumn<String>(
        'transcript_language',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _transcriptStatusMeta = const VerificationMeta(
    'transcriptStatus',
  );
  @override
  late final GeneratedColumn<String> transcriptStatus = GeneratedColumn<String>(
    'transcript_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _transcriptErrorMeta = const VerificationMeta(
    'transcriptError',
  );
  @override
  late final GeneratedColumn<String> transcriptError = GeneratedColumn<String>(
    'transcript_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptProgressMsMeta =
      const VerificationMeta('transcriptProgressMs');
  @override
  late final GeneratedColumn<int> transcriptProgressMs = GeneratedColumn<int>(
    'transcript_progress_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceTranscriptUrlMeta =
      const VerificationMeta('sourceTranscriptUrl');
  @override
  late final GeneratedColumn<String> sourceTranscriptUrl =
      GeneratedColumn<String>(
        'source_transcript_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    showId,
    guid,
    title,
    description,
    audioUrl,
    imageUrl,
    publishedAt,
    durationMs,
    playbackPositionMs,
    lastPlayedAt,
    isPlayed,
    localAudioPath,
    transcriptJson,
    transcriptLanguage,
    transcriptStatus,
    transcriptError,
    transcriptProgressMs,
    sourceTranscriptUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'podcast_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PodcastEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('show_id')) {
      context.handle(
        _showIdMeta,
        showId.isAcceptableOrUnknown(data['show_id']!, _showIdMeta),
      );
    } else if (isInserting) {
      context.missing(_showIdMeta);
    }
    if (data.containsKey('guid')) {
      context.handle(
        _guidMeta,
        guid.isAcceptableOrUnknown(data['guid']!, _guidMeta),
      );
    } else if (isInserting) {
      context.missing(_guidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('playback_position_ms')) {
      context.handle(
        _playbackPositionMsMeta,
        playbackPositionMs.isAcceptableOrUnknown(
          data['playback_position_ms']!,
          _playbackPositionMsMeta,
        ),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_played')) {
      context.handle(
        _isPlayedMeta,
        isPlayed.isAcceptableOrUnknown(data['is_played']!, _isPlayedMeta),
      );
    }
    if (data.containsKey('local_audio_path')) {
      context.handle(
        _localAudioPathMeta,
        localAudioPath.isAcceptableOrUnknown(
          data['local_audio_path']!,
          _localAudioPathMeta,
        ),
      );
    }
    if (data.containsKey('transcript_json')) {
      context.handle(
        _transcriptJsonMeta,
        transcriptJson.isAcceptableOrUnknown(
          data['transcript_json']!,
          _transcriptJsonMeta,
        ),
      );
    }
    if (data.containsKey('transcript_language')) {
      context.handle(
        _transcriptLanguageMeta,
        transcriptLanguage.isAcceptableOrUnknown(
          data['transcript_language']!,
          _transcriptLanguageMeta,
        ),
      );
    }
    if (data.containsKey('transcript_status')) {
      context.handle(
        _transcriptStatusMeta,
        transcriptStatus.isAcceptableOrUnknown(
          data['transcript_status']!,
          _transcriptStatusMeta,
        ),
      );
    }
    if (data.containsKey('transcript_error')) {
      context.handle(
        _transcriptErrorMeta,
        transcriptError.isAcceptableOrUnknown(
          data['transcript_error']!,
          _transcriptErrorMeta,
        ),
      );
    }
    if (data.containsKey('transcript_progress_ms')) {
      context.handle(
        _transcriptProgressMsMeta,
        transcriptProgressMs.isAcceptableOrUnknown(
          data['transcript_progress_ms']!,
          _transcriptProgressMsMeta,
        ),
      );
    }
    if (data.containsKey('source_transcript_url')) {
      context.handle(
        _sourceTranscriptUrlMeta,
        sourceTranscriptUrl.isAcceptableOrUnknown(
          data['source_transcript_url']!,
          _sourceTranscriptUrlMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {showId, guid},
  ];
  @override
  PodcastEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PodcastEpisode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      showId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}show_id'],
      )!,
      guid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      playbackPositionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playback_position_ms'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played_at'],
      )!,
      isPlayed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_played'],
      )!,
      localAudioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_audio_path'],
      ),
      transcriptJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_json'],
      ),
      transcriptLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_language'],
      ),
      transcriptStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_status'],
      )!,
      transcriptError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_error'],
      ),
      transcriptProgressMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transcript_progress_ms'],
      )!,
      sourceTranscriptUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_transcript_url'],
      ),
    );
  }

  @override
  $PodcastEpisodesTable createAlias(String alias) {
    return $PodcastEpisodesTable(attachedDatabase, alias);
  }
}

class PodcastEpisode extends DataClass implements Insertable<PodcastEpisode> {
  final String id;
  final String showId;
  final String guid;
  final String title;
  final String description;
  final String audioUrl;
  final String? imageUrl;
  final int publishedAt;
  final int durationMs;
  final int playbackPositionMs;
  final int lastPlayedAt;
  final bool isPlayed;
  final String? localAudioPath;
  final String? transcriptJson;
  final String? transcriptLanguage;
  final String transcriptStatus;
  final String? transcriptError;

  /// Audio offset already covered by fully transcribed chunks. A paused run
  /// resumes from here instead of listening to the episode again.
  final int transcriptProgressMs;
  final String? sourceTranscriptUrl;
  const PodcastEpisode({
    required this.id,
    required this.showId,
    required this.guid,
    required this.title,
    required this.description,
    required this.audioUrl,
    this.imageUrl,
    required this.publishedAt,
    required this.durationMs,
    required this.playbackPositionMs,
    required this.lastPlayedAt,
    required this.isPlayed,
    this.localAudioPath,
    this.transcriptJson,
    this.transcriptLanguage,
    required this.transcriptStatus,
    this.transcriptError,
    required this.transcriptProgressMs,
    this.sourceTranscriptUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['show_id'] = Variable<String>(showId);
    map['guid'] = Variable<String>(guid);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['audio_url'] = Variable<String>(audioUrl);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['published_at'] = Variable<int>(publishedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['playback_position_ms'] = Variable<int>(playbackPositionMs);
    map['last_played_at'] = Variable<int>(lastPlayedAt);
    map['is_played'] = Variable<bool>(isPlayed);
    if (!nullToAbsent || localAudioPath != null) {
      map['local_audio_path'] = Variable<String>(localAudioPath);
    }
    if (!nullToAbsent || transcriptJson != null) {
      map['transcript_json'] = Variable<String>(transcriptJson);
    }
    if (!nullToAbsent || transcriptLanguage != null) {
      map['transcript_language'] = Variable<String>(transcriptLanguage);
    }
    map['transcript_status'] = Variable<String>(transcriptStatus);
    if (!nullToAbsent || transcriptError != null) {
      map['transcript_error'] = Variable<String>(transcriptError);
    }
    map['transcript_progress_ms'] = Variable<int>(transcriptProgressMs);
    if (!nullToAbsent || sourceTranscriptUrl != null) {
      map['source_transcript_url'] = Variable<String>(sourceTranscriptUrl);
    }
    return map;
  }

  PodcastEpisodesCompanion toCompanion(bool nullToAbsent) {
    return PodcastEpisodesCompanion(
      id: Value(id),
      showId: Value(showId),
      guid: Value(guid),
      title: Value(title),
      description: Value(description),
      audioUrl: Value(audioUrl),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      publishedAt: Value(publishedAt),
      durationMs: Value(durationMs),
      playbackPositionMs: Value(playbackPositionMs),
      lastPlayedAt: Value(lastPlayedAt),
      isPlayed: Value(isPlayed),
      localAudioPath: localAudioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localAudioPath),
      transcriptJson: transcriptJson == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptJson),
      transcriptLanguage: transcriptLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptLanguage),
      transcriptStatus: Value(transcriptStatus),
      transcriptError: transcriptError == null && nullToAbsent
          ? const Value.absent()
          : Value(transcriptError),
      transcriptProgressMs: Value(transcriptProgressMs),
      sourceTranscriptUrl: sourceTranscriptUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTranscriptUrl),
    );
  }

  factory PodcastEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PodcastEpisode(
      id: serializer.fromJson<String>(json['id']),
      showId: serializer.fromJson<String>(json['showId']),
      guid: serializer.fromJson<String>(json['guid']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      publishedAt: serializer.fromJson<int>(json['publishedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      playbackPositionMs: serializer.fromJson<int>(json['playbackPositionMs']),
      lastPlayedAt: serializer.fromJson<int>(json['lastPlayedAt']),
      isPlayed: serializer.fromJson<bool>(json['isPlayed']),
      localAudioPath: serializer.fromJson<String?>(json['localAudioPath']),
      transcriptJson: serializer.fromJson<String?>(json['transcriptJson']),
      transcriptLanguage: serializer.fromJson<String?>(
        json['transcriptLanguage'],
      ),
      transcriptStatus: serializer.fromJson<String>(json['transcriptStatus']),
      transcriptError: serializer.fromJson<String?>(json['transcriptError']),
      transcriptProgressMs: serializer.fromJson<int>(
        json['transcriptProgressMs'],
      ),
      sourceTranscriptUrl: serializer.fromJson<String?>(
        json['sourceTranscriptUrl'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'showId': serializer.toJson<String>(showId),
      'guid': serializer.toJson<String>(guid),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'audioUrl': serializer.toJson<String>(audioUrl),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'publishedAt': serializer.toJson<int>(publishedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'playbackPositionMs': serializer.toJson<int>(playbackPositionMs),
      'lastPlayedAt': serializer.toJson<int>(lastPlayedAt),
      'isPlayed': serializer.toJson<bool>(isPlayed),
      'localAudioPath': serializer.toJson<String?>(localAudioPath),
      'transcriptJson': serializer.toJson<String?>(transcriptJson),
      'transcriptLanguage': serializer.toJson<String?>(transcriptLanguage),
      'transcriptStatus': serializer.toJson<String>(transcriptStatus),
      'transcriptError': serializer.toJson<String?>(transcriptError),
      'transcriptProgressMs': serializer.toJson<int>(transcriptProgressMs),
      'sourceTranscriptUrl': serializer.toJson<String?>(sourceTranscriptUrl),
    };
  }

  PodcastEpisode copyWith({
    String? id,
    String? showId,
    String? guid,
    String? title,
    String? description,
    String? audioUrl,
    Value<String?> imageUrl = const Value.absent(),
    int? publishedAt,
    int? durationMs,
    int? playbackPositionMs,
    int? lastPlayedAt,
    bool? isPlayed,
    Value<String?> localAudioPath = const Value.absent(),
    Value<String?> transcriptJson = const Value.absent(),
    Value<String?> transcriptLanguage = const Value.absent(),
    String? transcriptStatus,
    Value<String?> transcriptError = const Value.absent(),
    int? transcriptProgressMs,
    Value<String?> sourceTranscriptUrl = const Value.absent(),
  }) => PodcastEpisode(
    id: id ?? this.id,
    showId: showId ?? this.showId,
    guid: guid ?? this.guid,
    title: title ?? this.title,
    description: description ?? this.description,
    audioUrl: audioUrl ?? this.audioUrl,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    publishedAt: publishedAt ?? this.publishedAt,
    durationMs: durationMs ?? this.durationMs,
    playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    isPlayed: isPlayed ?? this.isPlayed,
    localAudioPath: localAudioPath.present
        ? localAudioPath.value
        : this.localAudioPath,
    transcriptJson: transcriptJson.present
        ? transcriptJson.value
        : this.transcriptJson,
    transcriptLanguage: transcriptLanguage.present
        ? transcriptLanguage.value
        : this.transcriptLanguage,
    transcriptStatus: transcriptStatus ?? this.transcriptStatus,
    transcriptError: transcriptError.present
        ? transcriptError.value
        : this.transcriptError,
    transcriptProgressMs: transcriptProgressMs ?? this.transcriptProgressMs,
    sourceTranscriptUrl: sourceTranscriptUrl.present
        ? sourceTranscriptUrl.value
        : this.sourceTranscriptUrl,
  );
  PodcastEpisode copyWithCompanion(PodcastEpisodesCompanion data) {
    return PodcastEpisode(
      id: data.id.present ? data.id.value : this.id,
      showId: data.showId.present ? data.showId.value : this.showId,
      guid: data.guid.present ? data.guid.value : this.guid,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      playbackPositionMs: data.playbackPositionMs.present
          ? data.playbackPositionMs.value
          : this.playbackPositionMs,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      isPlayed: data.isPlayed.present ? data.isPlayed.value : this.isPlayed,
      localAudioPath: data.localAudioPath.present
          ? data.localAudioPath.value
          : this.localAudioPath,
      transcriptJson: data.transcriptJson.present
          ? data.transcriptJson.value
          : this.transcriptJson,
      transcriptLanguage: data.transcriptLanguage.present
          ? data.transcriptLanguage.value
          : this.transcriptLanguage,
      transcriptStatus: data.transcriptStatus.present
          ? data.transcriptStatus.value
          : this.transcriptStatus,
      transcriptError: data.transcriptError.present
          ? data.transcriptError.value
          : this.transcriptError,
      transcriptProgressMs: data.transcriptProgressMs.present
          ? data.transcriptProgressMs.value
          : this.transcriptProgressMs,
      sourceTranscriptUrl: data.sourceTranscriptUrl.present
          ? data.sourceTranscriptUrl.value
          : this.sourceTranscriptUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PodcastEpisode(')
          ..write('id: $id, ')
          ..write('showId: $showId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('playbackPositionMs: $playbackPositionMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('isPlayed: $isPlayed, ')
          ..write('localAudioPath: $localAudioPath, ')
          ..write('transcriptJson: $transcriptJson, ')
          ..write('transcriptLanguage: $transcriptLanguage, ')
          ..write('transcriptStatus: $transcriptStatus, ')
          ..write('transcriptError: $transcriptError, ')
          ..write('transcriptProgressMs: $transcriptProgressMs, ')
          ..write('sourceTranscriptUrl: $sourceTranscriptUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    showId,
    guid,
    title,
    description,
    audioUrl,
    imageUrl,
    publishedAt,
    durationMs,
    playbackPositionMs,
    lastPlayedAt,
    isPlayed,
    localAudioPath,
    transcriptJson,
    transcriptLanguage,
    transcriptStatus,
    transcriptError,
    transcriptProgressMs,
    sourceTranscriptUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PodcastEpisode &&
          other.id == this.id &&
          other.showId == this.showId &&
          other.guid == this.guid &&
          other.title == this.title &&
          other.description == this.description &&
          other.audioUrl == this.audioUrl &&
          other.imageUrl == this.imageUrl &&
          other.publishedAt == this.publishedAt &&
          other.durationMs == this.durationMs &&
          other.playbackPositionMs == this.playbackPositionMs &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.isPlayed == this.isPlayed &&
          other.localAudioPath == this.localAudioPath &&
          other.transcriptJson == this.transcriptJson &&
          other.transcriptLanguage == this.transcriptLanguage &&
          other.transcriptStatus == this.transcriptStatus &&
          other.transcriptError == this.transcriptError &&
          other.transcriptProgressMs == this.transcriptProgressMs &&
          other.sourceTranscriptUrl == this.sourceTranscriptUrl);
}

class PodcastEpisodesCompanion extends UpdateCompanion<PodcastEpisode> {
  final Value<String> id;
  final Value<String> showId;
  final Value<String> guid;
  final Value<String> title;
  final Value<String> description;
  final Value<String> audioUrl;
  final Value<String?> imageUrl;
  final Value<int> publishedAt;
  final Value<int> durationMs;
  final Value<int> playbackPositionMs;
  final Value<int> lastPlayedAt;
  final Value<bool> isPlayed;
  final Value<String?> localAudioPath;
  final Value<String?> transcriptJson;
  final Value<String?> transcriptLanguage;
  final Value<String> transcriptStatus;
  final Value<String?> transcriptError;
  final Value<int> transcriptProgressMs;
  final Value<String?> sourceTranscriptUrl;
  final Value<int> rowid;
  const PodcastEpisodesCompanion({
    this.id = const Value.absent(),
    this.showId = const Value.absent(),
    this.guid = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.playbackPositionMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.isPlayed = const Value.absent(),
    this.localAudioPath = const Value.absent(),
    this.transcriptJson = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.transcriptStatus = const Value.absent(),
    this.transcriptError = const Value.absent(),
    this.transcriptProgressMs = const Value.absent(),
    this.sourceTranscriptUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PodcastEpisodesCompanion.insert({
    required String id,
    required String showId,
    required String guid,
    required String title,
    this.description = const Value.absent(),
    required String audioUrl,
    this.imageUrl = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.playbackPositionMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.isPlayed = const Value.absent(),
    this.localAudioPath = const Value.absent(),
    this.transcriptJson = const Value.absent(),
    this.transcriptLanguage = const Value.absent(),
    this.transcriptStatus = const Value.absent(),
    this.transcriptError = const Value.absent(),
    this.transcriptProgressMs = const Value.absent(),
    this.sourceTranscriptUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       showId = Value(showId),
       guid = Value(guid),
       title = Value(title),
       audioUrl = Value(audioUrl);
  static Insertable<PodcastEpisode> custom({
    Expression<String>? id,
    Expression<String>? showId,
    Expression<String>? guid,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? audioUrl,
    Expression<String>? imageUrl,
    Expression<int>? publishedAt,
    Expression<int>? durationMs,
    Expression<int>? playbackPositionMs,
    Expression<int>? lastPlayedAt,
    Expression<bool>? isPlayed,
    Expression<String>? localAudioPath,
    Expression<String>? transcriptJson,
    Expression<String>? transcriptLanguage,
    Expression<String>? transcriptStatus,
    Expression<String>? transcriptError,
    Expression<int>? transcriptProgressMs,
    Expression<String>? sourceTranscriptUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (showId != null) 'show_id': showId,
      if (guid != null) 'guid': guid,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (imageUrl != null) 'image_url': imageUrl,
      if (publishedAt != null) 'published_at': publishedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (playbackPositionMs != null)
        'playback_position_ms': playbackPositionMs,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (isPlayed != null) 'is_played': isPlayed,
      if (localAudioPath != null) 'local_audio_path': localAudioPath,
      if (transcriptJson != null) 'transcript_json': transcriptJson,
      if (transcriptLanguage != null) 'transcript_language': transcriptLanguage,
      if (transcriptStatus != null) 'transcript_status': transcriptStatus,
      if (transcriptError != null) 'transcript_error': transcriptError,
      if (transcriptProgressMs != null)
        'transcript_progress_ms': transcriptProgressMs,
      if (sourceTranscriptUrl != null)
        'source_transcript_url': sourceTranscriptUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PodcastEpisodesCompanion copyWith({
    Value<String>? id,
    Value<String>? showId,
    Value<String>? guid,
    Value<String>? title,
    Value<String>? description,
    Value<String>? audioUrl,
    Value<String?>? imageUrl,
    Value<int>? publishedAt,
    Value<int>? durationMs,
    Value<int>? playbackPositionMs,
    Value<int>? lastPlayedAt,
    Value<bool>? isPlayed,
    Value<String?>? localAudioPath,
    Value<String?>? transcriptJson,
    Value<String?>? transcriptLanguage,
    Value<String>? transcriptStatus,
    Value<String?>? transcriptError,
    Value<int>? transcriptProgressMs,
    Value<String?>? sourceTranscriptUrl,
    Value<int>? rowid,
  }) {
    return PodcastEpisodesCompanion(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      guid: guid ?? this.guid,
      title: title ?? this.title,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      durationMs: durationMs ?? this.durationMs,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isPlayed: isPlayed ?? this.isPlayed,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      transcriptJson: transcriptJson ?? this.transcriptJson,
      transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
      transcriptStatus: transcriptStatus ?? this.transcriptStatus,
      transcriptError: transcriptError ?? this.transcriptError,
      transcriptProgressMs: transcriptProgressMs ?? this.transcriptProgressMs,
      sourceTranscriptUrl: sourceTranscriptUrl ?? this.sourceTranscriptUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (showId.present) {
      map['show_id'] = Variable<String>(showId.value);
    }
    if (guid.present) {
      map['guid'] = Variable<String>(guid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(publishedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (playbackPositionMs.present) {
      map['playback_position_ms'] = Variable<int>(playbackPositionMs.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (isPlayed.present) {
      map['is_played'] = Variable<bool>(isPlayed.value);
    }
    if (localAudioPath.present) {
      map['local_audio_path'] = Variable<String>(localAudioPath.value);
    }
    if (transcriptJson.present) {
      map['transcript_json'] = Variable<String>(transcriptJson.value);
    }
    if (transcriptLanguage.present) {
      map['transcript_language'] = Variable<String>(transcriptLanguage.value);
    }
    if (transcriptStatus.present) {
      map['transcript_status'] = Variable<String>(transcriptStatus.value);
    }
    if (transcriptError.present) {
      map['transcript_error'] = Variable<String>(transcriptError.value);
    }
    if (transcriptProgressMs.present) {
      map['transcript_progress_ms'] = Variable<int>(transcriptProgressMs.value);
    }
    if (sourceTranscriptUrl.present) {
      map['source_transcript_url'] = Variable<String>(
        sourceTranscriptUrl.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PodcastEpisodesCompanion(')
          ..write('id: $id, ')
          ..write('showId: $showId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('playbackPositionMs: $playbackPositionMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('isPlayed: $isPlayed, ')
          ..write('localAudioPath: $localAudioPath, ')
          ..write('transcriptJson: $transcriptJson, ')
          ..write('transcriptLanguage: $transcriptLanguage, ')
          ..write('transcriptStatus: $transcriptStatus, ')
          ..write('transcriptError: $transcriptError, ')
          ..write('transcriptProgressMs: $transcriptProgressMs, ')
          ..write('sourceTranscriptUrl: $sourceTranscriptUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiThreadsTable extends AiThreads
    with TableInfo<$AiThreadsTable, AiThread> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiThreadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeTypeMeta = const VerificationMeta(
    'scopeType',
  );
  @override
  late final GeneratedColumn<String> scopeType = GeneratedColumn<String>(
    'scope_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeParentIdMeta = const VerificationMeta(
    'scopeParentId',
  );
  @override
  late final GeneratedColumn<String> scopeParentId = GeneratedColumn<String>(
    'scope_parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentFingerprintMeta =
      const VerificationMeta('contentFingerprint');
  @override
  late final GeneratedColumn<String> contentFingerprint =
      GeneratedColumn<String>(
        'content_fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _summaryTextMeta = const VerificationMeta(
    'summaryText',
  );
  @override
  late final GeneratedColumn<String> summaryText = GeneratedColumn<String>(
    'summary_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteConversationIdMeta =
      const VerificationMeta('remoteConversationId');
  @override
  late final GeneratedColumn<String> remoteConversationId =
      GeneratedColumn<String>(
        'remote_conversation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastResponseIdMeta = const VerificationMeta(
    'lastResponseId',
  );
  @override
  late final GeneratedColumn<String> lastResponseId = GeneratedColumn<String>(
    'last_response_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scopeType,
    scopeId,
    scopeParentId,
    contentFingerprint,
    summaryText,
    remoteConversationId,
    lastResponseId,
    modelId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_threads';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiThread> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope_type')) {
      context.handle(
        _scopeTypeMeta,
        scopeType.isAcceptableOrUnknown(data['scope_type']!, _scopeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeTypeMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('scope_parent_id')) {
      context.handle(
        _scopeParentIdMeta,
        scopeParentId.isAcceptableOrUnknown(
          data['scope_parent_id']!,
          _scopeParentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scopeParentIdMeta);
    }
    if (data.containsKey('content_fingerprint')) {
      context.handle(
        _contentFingerprintMeta,
        contentFingerprint.isAcceptableOrUnknown(
          data['content_fingerprint']!,
          _contentFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentFingerprintMeta);
    }
    if (data.containsKey('summary_text')) {
      context.handle(
        _summaryTextMeta,
        summaryText.isAcceptableOrUnknown(
          data['summary_text']!,
          _summaryTextMeta,
        ),
      );
    }
    if (data.containsKey('remote_conversation_id')) {
      context.handle(
        _remoteConversationIdMeta,
        remoteConversationId.isAcceptableOrUnknown(
          data['remote_conversation_id']!,
          _remoteConversationIdMeta,
        ),
      );
    }
    if (data.containsKey('last_response_id')) {
      context.handle(
        _lastResponseIdMeta,
        lastResponseId.isAcceptableOrUnknown(
          data['last_response_id']!,
          _lastResponseIdMeta,
        ),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scopeType, scopeId},
  ];
  @override
  AiThread map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiThread(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scopeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_type'],
      )!,
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_id'],
      )!,
      scopeParentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_parent_id'],
      )!,
      contentFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_fingerprint'],
      )!,
      summaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_text'],
      ),
      remoteConversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_conversation_id'],
      ),
      lastResponseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_response_id'],
      ),
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiThreadsTable createAlias(String alias) {
    return $AiThreadsTable(attachedDatabase, alias);
  }
}

class AiThread extends DataClass implements Insertable<AiThread> {
  final String id;
  final String scopeType;
  final String scopeId;
  final String scopeParentId;
  final String contentFingerprint;
  final String? summaryText;
  final String? remoteConversationId;
  final String? lastResponseId;
  final String? modelId;
  final int createdAt;
  final int updatedAt;
  const AiThread({
    required this.id,
    required this.scopeType,
    required this.scopeId,
    required this.scopeParentId,
    required this.contentFingerprint,
    this.summaryText,
    this.remoteConversationId,
    this.lastResponseId,
    this.modelId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope_type'] = Variable<String>(scopeType);
    map['scope_id'] = Variable<String>(scopeId);
    map['scope_parent_id'] = Variable<String>(scopeParentId);
    map['content_fingerprint'] = Variable<String>(contentFingerprint);
    if (!nullToAbsent || summaryText != null) {
      map['summary_text'] = Variable<String>(summaryText);
    }
    if (!nullToAbsent || remoteConversationId != null) {
      map['remote_conversation_id'] = Variable<String>(remoteConversationId);
    }
    if (!nullToAbsent || lastResponseId != null) {
      map['last_response_id'] = Variable<String>(lastResponseId);
    }
    if (!nullToAbsent || modelId != null) {
      map['model_id'] = Variable<String>(modelId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AiThreadsCompanion toCompanion(bool nullToAbsent) {
    return AiThreadsCompanion(
      id: Value(id),
      scopeType: Value(scopeType),
      scopeId: Value(scopeId),
      scopeParentId: Value(scopeParentId),
      contentFingerprint: Value(contentFingerprint),
      summaryText: summaryText == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryText),
      remoteConversationId: remoteConversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteConversationId),
      lastResponseId: lastResponseId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastResponseId),
      modelId: modelId == null && nullToAbsent
          ? const Value.absent()
          : Value(modelId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiThread.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiThread(
      id: serializer.fromJson<String>(json['id']),
      scopeType: serializer.fromJson<String>(json['scopeType']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      scopeParentId: serializer.fromJson<String>(json['scopeParentId']),
      contentFingerprint: serializer.fromJson<String>(
        json['contentFingerprint'],
      ),
      summaryText: serializer.fromJson<String?>(json['summaryText']),
      remoteConversationId: serializer.fromJson<String?>(
        json['remoteConversationId'],
      ),
      lastResponseId: serializer.fromJson<String?>(json['lastResponseId']),
      modelId: serializer.fromJson<String?>(json['modelId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scopeType': serializer.toJson<String>(scopeType),
      'scopeId': serializer.toJson<String>(scopeId),
      'scopeParentId': serializer.toJson<String>(scopeParentId),
      'contentFingerprint': serializer.toJson<String>(contentFingerprint),
      'summaryText': serializer.toJson<String?>(summaryText),
      'remoteConversationId': serializer.toJson<String?>(remoteConversationId),
      'lastResponseId': serializer.toJson<String?>(lastResponseId),
      'modelId': serializer.toJson<String?>(modelId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AiThread copyWith({
    String? id,
    String? scopeType,
    String? scopeId,
    String? scopeParentId,
    String? contentFingerprint,
    Value<String?> summaryText = const Value.absent(),
    Value<String?> remoteConversationId = const Value.absent(),
    Value<String?> lastResponseId = const Value.absent(),
    Value<String?> modelId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => AiThread(
    id: id ?? this.id,
    scopeType: scopeType ?? this.scopeType,
    scopeId: scopeId ?? this.scopeId,
    scopeParentId: scopeParentId ?? this.scopeParentId,
    contentFingerprint: contentFingerprint ?? this.contentFingerprint,
    summaryText: summaryText.present ? summaryText.value : this.summaryText,
    remoteConversationId: remoteConversationId.present
        ? remoteConversationId.value
        : this.remoteConversationId,
    lastResponseId: lastResponseId.present
        ? lastResponseId.value
        : this.lastResponseId,
    modelId: modelId.present ? modelId.value : this.modelId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiThread copyWithCompanion(AiThreadsCompanion data) {
    return AiThread(
      id: data.id.present ? data.id.value : this.id,
      scopeType: data.scopeType.present ? data.scopeType.value : this.scopeType,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      scopeParentId: data.scopeParentId.present
          ? data.scopeParentId.value
          : this.scopeParentId,
      contentFingerprint: data.contentFingerprint.present
          ? data.contentFingerprint.value
          : this.contentFingerprint,
      summaryText: data.summaryText.present
          ? data.summaryText.value
          : this.summaryText,
      remoteConversationId: data.remoteConversationId.present
          ? data.remoteConversationId.value
          : this.remoteConversationId,
      lastResponseId: data.lastResponseId.present
          ? data.lastResponseId.value
          : this.lastResponseId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiThread(')
          ..write('id: $id, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('scopeParentId: $scopeParentId, ')
          ..write('contentFingerprint: $contentFingerprint, ')
          ..write('summaryText: $summaryText, ')
          ..write('remoteConversationId: $remoteConversationId, ')
          ..write('lastResponseId: $lastResponseId, ')
          ..write('modelId: $modelId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scopeType,
    scopeId,
    scopeParentId,
    contentFingerprint,
    summaryText,
    remoteConversationId,
    lastResponseId,
    modelId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiThread &&
          other.id == this.id &&
          other.scopeType == this.scopeType &&
          other.scopeId == this.scopeId &&
          other.scopeParentId == this.scopeParentId &&
          other.contentFingerprint == this.contentFingerprint &&
          other.summaryText == this.summaryText &&
          other.remoteConversationId == this.remoteConversationId &&
          other.lastResponseId == this.lastResponseId &&
          other.modelId == this.modelId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiThreadsCompanion extends UpdateCompanion<AiThread> {
  final Value<String> id;
  final Value<String> scopeType;
  final Value<String> scopeId;
  final Value<String> scopeParentId;
  final Value<String> contentFingerprint;
  final Value<String?> summaryText;
  final Value<String?> remoteConversationId;
  final Value<String?> lastResponseId;
  final Value<String?> modelId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AiThreadsCompanion({
    this.id = const Value.absent(),
    this.scopeType = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.scopeParentId = const Value.absent(),
    this.contentFingerprint = const Value.absent(),
    this.summaryText = const Value.absent(),
    this.remoteConversationId = const Value.absent(),
    this.lastResponseId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiThreadsCompanion.insert({
    required String id,
    required String scopeType,
    required String scopeId,
    required String scopeParentId,
    required String contentFingerprint,
    this.summaryText = const Value.absent(),
    this.remoteConversationId = const Value.absent(),
    this.lastResponseId = const Value.absent(),
    this.modelId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scopeType = Value(scopeType),
       scopeId = Value(scopeId),
       scopeParentId = Value(scopeParentId),
       contentFingerprint = Value(contentFingerprint),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AiThread> custom({
    Expression<String>? id,
    Expression<String>? scopeType,
    Expression<String>? scopeId,
    Expression<String>? scopeParentId,
    Expression<String>? contentFingerprint,
    Expression<String>? summaryText,
    Expression<String>? remoteConversationId,
    Expression<String>? lastResponseId,
    Expression<String>? modelId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scopeType != null) 'scope_type': scopeType,
      if (scopeId != null) 'scope_id': scopeId,
      if (scopeParentId != null) 'scope_parent_id': scopeParentId,
      if (contentFingerprint != null) 'content_fingerprint': contentFingerprint,
      if (summaryText != null) 'summary_text': summaryText,
      if (remoteConversationId != null)
        'remote_conversation_id': remoteConversationId,
      if (lastResponseId != null) 'last_response_id': lastResponseId,
      if (modelId != null) 'model_id': modelId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiThreadsCompanion copyWith({
    Value<String>? id,
    Value<String>? scopeType,
    Value<String>? scopeId,
    Value<String>? scopeParentId,
    Value<String>? contentFingerprint,
    Value<String?>? summaryText,
    Value<String?>? remoteConversationId,
    Value<String?>? lastResponseId,
    Value<String?>? modelId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiThreadsCompanion(
      id: id ?? this.id,
      scopeType: scopeType ?? this.scopeType,
      scopeId: scopeId ?? this.scopeId,
      scopeParentId: scopeParentId ?? this.scopeParentId,
      contentFingerprint: contentFingerprint ?? this.contentFingerprint,
      summaryText: summaryText ?? this.summaryText,
      remoteConversationId: remoteConversationId ?? this.remoteConversationId,
      lastResponseId: lastResponseId ?? this.lastResponseId,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scopeType.present) {
      map['scope_type'] = Variable<String>(scopeType.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (scopeParentId.present) {
      map['scope_parent_id'] = Variable<String>(scopeParentId.value);
    }
    if (contentFingerprint.present) {
      map['content_fingerprint'] = Variable<String>(contentFingerprint.value);
    }
    if (summaryText.present) {
      map['summary_text'] = Variable<String>(summaryText.value);
    }
    if (remoteConversationId.present) {
      map['remote_conversation_id'] = Variable<String>(
        remoteConversationId.value,
      );
    }
    if (lastResponseId.present) {
      map['last_response_id'] = Variable<String>(lastResponseId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiThreadsCompanion(')
          ..write('id: $id, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('scopeParentId: $scopeParentId, ')
          ..write('contentFingerprint: $contentFingerprint, ')
          ..write('summaryText: $summaryText, ')
          ..write('remoteConversationId: $remoteConversationId, ')
          ..write('lastResponseId: $lastResponseId, ')
          ..write('modelId: $modelId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiMessagesTable extends AiMessages
    with TableInfo<$AiMessagesTable, AiMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('chat'),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _citationsJsonMeta = const VerificationMeta(
    'citationsJson',
  );
  @override
  late final GeneratedColumn<String> citationsJson = GeneratedColumn<String>(
    'citations_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _responseIdMeta = const VerificationMeta(
    'responseId',
  );
  @override
  late final GeneratedColumn<String> responseId = GeneratedColumn<String>(
    'response_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    threadId,
    role,
    kind,
    content,
    citationsJson,
    responseId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('citations_json')) {
      context.handle(
        _citationsJsonMeta,
        citationsJson.isAcceptableOrUnknown(
          data['citations_json']!,
          _citationsJsonMeta,
        ),
      );
    }
    if (data.containsKey('response_id')) {
      context.handle(
        _responseIdMeta,
        responseId.isAcceptableOrUnknown(data['response_id']!, _responseIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      citationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}citations_json'],
      ),
      responseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AiMessagesTable createAlias(String alias) {
    return $AiMessagesTable(attachedDatabase, alias);
  }
}

class AiMessage extends DataClass implements Insertable<AiMessage> {
  final String id;
  final String threadId;
  final String role;
  final String kind;
  final String content;
  final String? citationsJson;
  final String? responseId;
  final int createdAt;
  const AiMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.kind,
    required this.content,
    this.citationsJson,
    this.responseId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['thread_id'] = Variable<String>(threadId);
    map['role'] = Variable<String>(role);
    map['kind'] = Variable<String>(kind);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || citationsJson != null) {
      map['citations_json'] = Variable<String>(citationsJson);
    }
    if (!nullToAbsent || responseId != null) {
      map['response_id'] = Variable<String>(responseId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AiMessagesCompanion toCompanion(bool nullToAbsent) {
    return AiMessagesCompanion(
      id: Value(id),
      threadId: Value(threadId),
      role: Value(role),
      kind: Value(kind),
      content: Value(content),
      citationsJson: citationsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(citationsJson),
      responseId: responseId == null && nullToAbsent
          ? const Value.absent()
          : Value(responseId),
      createdAt: Value(createdAt),
    );
  }

  factory AiMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiMessage(
      id: serializer.fromJson<String>(json['id']),
      threadId: serializer.fromJson<String>(json['threadId']),
      role: serializer.fromJson<String>(json['role']),
      kind: serializer.fromJson<String>(json['kind']),
      content: serializer.fromJson<String>(json['content']),
      citationsJson: serializer.fromJson<String?>(json['citationsJson']),
      responseId: serializer.fromJson<String?>(json['responseId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'threadId': serializer.toJson<String>(threadId),
      'role': serializer.toJson<String>(role),
      'kind': serializer.toJson<String>(kind),
      'content': serializer.toJson<String>(content),
      'citationsJson': serializer.toJson<String?>(citationsJson),
      'responseId': serializer.toJson<String?>(responseId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AiMessage copyWith({
    String? id,
    String? threadId,
    String? role,
    String? kind,
    String? content,
    Value<String?> citationsJson = const Value.absent(),
    Value<String?> responseId = const Value.absent(),
    int? createdAt,
  }) => AiMessage(
    id: id ?? this.id,
    threadId: threadId ?? this.threadId,
    role: role ?? this.role,
    kind: kind ?? this.kind,
    content: content ?? this.content,
    citationsJson: citationsJson.present
        ? citationsJson.value
        : this.citationsJson,
    responseId: responseId.present ? responseId.value : this.responseId,
    createdAt: createdAt ?? this.createdAt,
  );
  AiMessage copyWithCompanion(AiMessagesCompanion data) {
    return AiMessage(
      id: data.id.present ? data.id.value : this.id,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      role: data.role.present ? data.role.value : this.role,
      kind: data.kind.present ? data.kind.value : this.kind,
      content: data.content.present ? data.content.value : this.content,
      citationsJson: data.citationsJson.present
          ? data.citationsJson.value
          : this.citationsJson,
      responseId: data.responseId.present
          ? data.responseId.value
          : this.responseId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiMessage(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('role: $role, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('citationsJson: $citationsJson, ')
          ..write('responseId: $responseId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    threadId,
    role,
    kind,
    content,
    citationsJson,
    responseId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiMessage &&
          other.id == this.id &&
          other.threadId == this.threadId &&
          other.role == this.role &&
          other.kind == this.kind &&
          other.content == this.content &&
          other.citationsJson == this.citationsJson &&
          other.responseId == this.responseId &&
          other.createdAt == this.createdAt);
}

class AiMessagesCompanion extends UpdateCompanion<AiMessage> {
  final Value<String> id;
  final Value<String> threadId;
  final Value<String> role;
  final Value<String> kind;
  final Value<String> content;
  final Value<String?> citationsJson;
  final Value<String?> responseId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AiMessagesCompanion({
    this.id = const Value.absent(),
    this.threadId = const Value.absent(),
    this.role = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.citationsJson = const Value.absent(),
    this.responseId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiMessagesCompanion.insert({
    required String id,
    required String threadId,
    required String role,
    this.kind = const Value.absent(),
    required String content,
    this.citationsJson = const Value.absent(),
    this.responseId = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       threadId = Value(threadId),
       role = Value(role),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<AiMessage> custom({
    Expression<String>? id,
    Expression<String>? threadId,
    Expression<String>? role,
    Expression<String>? kind,
    Expression<String>? content,
    Expression<String>? citationsJson,
    Expression<String>? responseId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (threadId != null) 'thread_id': threadId,
      if (role != null) 'role': role,
      if (kind != null) 'kind': kind,
      if (content != null) 'content': content,
      if (citationsJson != null) 'citations_json': citationsJson,
      if (responseId != null) 'response_id': responseId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? threadId,
    Value<String>? role,
    Value<String>? kind,
    Value<String>? content,
    Value<String?>? citationsJson,
    Value<String?>? responseId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return AiMessagesCompanion(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      role: role ?? this.role,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      citationsJson: citationsJson ?? this.citationsJson,
      responseId: responseId ?? this.responseId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (citationsJson.present) {
      map['citations_json'] = Variable<String>(citationsJson.value);
    }
    if (responseId.present) {
      map['response_id'] = Variable<String>(responseId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiMessagesCompanion(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('role: $role, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('citationsJson: $citationsJson, ')
          ..write('responseId: $responseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GenerationTasksTable extends GenerationTasks
    with TableInfo<$GenerationTasksTable, GenerationTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GenerationTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentFingerprintMeta =
      const VerificationMeta('contentFingerprint');
  @override
  late final GeneratedColumn<String> contentFingerprint =
      GeneratedColumn<String>(
        'content_fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _configFingerprintMeta = const VerificationMeta(
    'configFingerprint',
  );
  @override
  late final GeneratedColumn<String> configFingerprint =
      GeneratedColumn<String>(
        'config_fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    parentId,
    scopeId,
    contentFingerprint,
    configFingerprint,
    configJson,
    status,
    priority,
    createdAt,
    updatedAt,
    startedAt,
    completedAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'generation_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<GenerationTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('content_fingerprint')) {
      context.handle(
        _contentFingerprintMeta,
        contentFingerprint.isAcceptableOrUnknown(
          data['content_fingerprint']!,
          _contentFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentFingerprintMeta);
    }
    if (data.containsKey('config_fingerprint')) {
      context.handle(
        _configFingerprintMeta,
        configFingerprint.isAcceptableOrUnknown(
          data['config_fingerprint']!,
          _configFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_configFingerprintMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GenerationTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GenerationTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      )!,
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_id'],
      )!,
      contentFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_fingerprint'],
      )!,
      configFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_fingerprint'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $GenerationTasksTable createAlias(String alias) {
    return $GenerationTasksTable(attachedDatabase, alias);
  }
}

class GenerationTask extends DataClass implements Insertable<GenerationTask> {
  final String id;
  final String kind;
  final String parentId;
  final String scopeId;
  final String contentFingerprint;
  final String configFingerprint;
  final String configJson;
  final String status;
  final int priority;
  final int createdAt;
  final int updatedAt;
  final int? startedAt;
  final int? completedAt;
  final String? lastError;
  const GenerationTask({
    required this.id,
    required this.kind,
    required this.parentId,
    required this.scopeId,
    required this.contentFingerprint,
    required this.configFingerprint,
    required this.configJson,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['parent_id'] = Variable<String>(parentId);
    map['scope_id'] = Variable<String>(scopeId);
    map['content_fingerprint'] = Variable<String>(contentFingerprint);
    map['config_fingerprint'] = Variable<String>(configFingerprint);
    map['config_json'] = Variable<String>(configJson);
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<int>(priority);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  GenerationTasksCompanion toCompanion(bool nullToAbsent) {
    return GenerationTasksCompanion(
      id: Value(id),
      kind: Value(kind),
      parentId: Value(parentId),
      scopeId: Value(scopeId),
      contentFingerprint: Value(contentFingerprint),
      configFingerprint: Value(configFingerprint),
      configJson: Value(configJson),
      status: Value(status),
      priority: Value(priority),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory GenerationTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GenerationTask(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      parentId: serializer.fromJson<String>(json['parentId']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      contentFingerprint: serializer.fromJson<String>(
        json['contentFingerprint'],
      ),
      configFingerprint: serializer.fromJson<String>(json['configFingerprint']),
      configJson: serializer.fromJson<String>(json['configJson']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<int>(json['priority']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'parentId': serializer.toJson<String>(parentId),
      'scopeId': serializer.toJson<String>(scopeId),
      'contentFingerprint': serializer.toJson<String>(contentFingerprint),
      'configFingerprint': serializer.toJson<String>(configFingerprint),
      'configJson': serializer.toJson<String>(configJson),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<int>(priority),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'startedAt': serializer.toJson<int?>(startedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  GenerationTask copyWith({
    String? id,
    String? kind,
    String? parentId,
    String? scopeId,
    String? contentFingerprint,
    String? configFingerprint,
    String? configJson,
    String? status,
    int? priority,
    int? createdAt,
    int? updatedAt,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => GenerationTask(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    parentId: parentId ?? this.parentId,
    scopeId: scopeId ?? this.scopeId,
    contentFingerprint: contentFingerprint ?? this.contentFingerprint,
    configFingerprint: configFingerprint ?? this.configFingerprint,
    configJson: configJson ?? this.configJson,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  GenerationTask copyWithCompanion(GenerationTasksCompanion data) {
    return GenerationTask(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      contentFingerprint: data.contentFingerprint.present
          ? data.contentFingerprint.value
          : this.contentFingerprint,
      configFingerprint: data.configFingerprint.present
          ? data.configFingerprint.value
          : this.configFingerprint,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GenerationTask(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('parentId: $parentId, ')
          ..write('scopeId: $scopeId, ')
          ..write('contentFingerprint: $contentFingerprint, ')
          ..write('configFingerprint: $configFingerprint, ')
          ..write('configJson: $configJson, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    parentId,
    scopeId,
    contentFingerprint,
    configFingerprint,
    configJson,
    status,
    priority,
    createdAt,
    updatedAt,
    startedAt,
    completedAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GenerationTask &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.parentId == this.parentId &&
          other.scopeId == this.scopeId &&
          other.contentFingerprint == this.contentFingerprint &&
          other.configFingerprint == this.configFingerprint &&
          other.configJson == this.configJson &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.lastError == this.lastError);
}

class GenerationTasksCompanion extends UpdateCompanion<GenerationTask> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> parentId;
  final Value<String> scopeId;
  final Value<String> contentFingerprint;
  final Value<String> configFingerprint;
  final Value<String> configJson;
  final Value<String> status;
  final Value<int> priority;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> startedAt;
  final Value<int?> completedAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const GenerationTasksCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.parentId = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.contentFingerprint = const Value.absent(),
    this.configFingerprint = const Value.absent(),
    this.configJson = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GenerationTasksCompanion.insert({
    required String id,
    required String kind,
    required String parentId,
    required String scopeId,
    required String contentFingerprint,
    required String configFingerprint,
    this.configJson = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       parentId = Value(parentId),
       scopeId = Value(scopeId),
       contentFingerprint = Value(contentFingerprint),
       configFingerprint = Value(configFingerprint),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GenerationTask> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? parentId,
    Expression<String>? scopeId,
    Expression<String>? contentFingerprint,
    Expression<String>? configFingerprint,
    Expression<String>? configJson,
    Expression<String>? status,
    Expression<int>? priority,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? startedAt,
    Expression<int>? completedAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (parentId != null) 'parent_id': parentId,
      if (scopeId != null) 'scope_id': scopeId,
      if (contentFingerprint != null) 'content_fingerprint': contentFingerprint,
      if (configFingerprint != null) 'config_fingerprint': configFingerprint,
      if (configJson != null) 'config_json': configJson,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GenerationTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? parentId,
    Value<String>? scopeId,
    Value<String>? contentFingerprint,
    Value<String>? configFingerprint,
    Value<String>? configJson,
    Value<String>? status,
    Value<int>? priority,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? startedAt,
    Value<int?>? completedAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return GenerationTasksCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      parentId: parentId ?? this.parentId,
      scopeId: scopeId ?? this.scopeId,
      contentFingerprint: contentFingerprint ?? this.contentFingerprint,
      configFingerprint: configFingerprint ?? this.configFingerprint,
      configJson: configJson ?? this.configJson,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (contentFingerprint.present) {
      map['content_fingerprint'] = Variable<String>(contentFingerprint.value);
    }
    if (configFingerprint.present) {
      map['config_fingerprint'] = Variable<String>(configFingerprint.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GenerationTasksCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('parentId: $parentId, ')
          ..write('scopeId: $scopeId, ')
          ..write('contentFingerprint: $contentFingerprint, ')
          ..write('configFingerprint: $configFingerprint, ')
          ..write('configJson: $configJson, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GenerationTaskChunksTable extends GenerationTaskChunks
    with TableInfo<$GenerationTaskChunksTable, GenerationTaskChunk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GenerationTaskChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkIndexMeta = const VerificationMeta(
    'chunkIndex',
  );
  @override
  late final GeneratedColumn<int> chunkIndex = GeneratedColumn<int>(
    'chunk_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inputFingerprintMeta = const VerificationMeta(
    'inputFingerprint',
  );
  @override
  late final GeneratedColumn<String> inputFingerprint = GeneratedColumn<String>(
    'input_fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _resultRefMeta = const VerificationMeta(
    'resultRef',
  );
  @override
  late final GeneratedColumn<String> resultRef = GeneratedColumn<String>(
    'result_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    chunkIndex,
    sourceKey,
    startMs,
    endMs,
    inputFingerprint,
    status,
    attempts,
    priority,
    resultRef,
    resultJson,
    error,
    updatedAt,
    startedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'generation_task_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<GenerationTaskChunk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('chunk_index')) {
      context.handle(
        _chunkIndexMeta,
        chunkIndex.isAcceptableOrUnknown(data['chunk_index']!, _chunkIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIndexMeta);
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    }
    if (data.containsKey('input_fingerprint')) {
      context.handle(
        _inputFingerprintMeta,
        inputFingerprint.isAcceptableOrUnknown(
          data['input_fingerprint']!,
          _inputFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputFingerprintMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('result_ref')) {
      context.handle(
        _resultRefMeta,
        resultRef.isAcceptableOrUnknown(data['result_ref']!, _resultRefMeta),
      );
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {taskId, chunkIndex},
  ];
  @override
  GenerationTaskChunk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GenerationTaskChunk(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      chunkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_index'],
      )!,
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      inputFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_fingerprint'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      resultRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_ref'],
      ),
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $GenerationTaskChunksTable createAlias(String alias) {
    return $GenerationTaskChunksTable(attachedDatabase, alias);
  }
}

class GenerationTaskChunk extends DataClass
    implements Insertable<GenerationTaskChunk> {
  final String id;
  final String taskId;
  final int chunkIndex;
  final String sourceKey;
  final int startMs;
  final int endMs;
  final String inputFingerprint;
  final String status;
  final int attempts;
  final int priority;
  final String? resultRef;
  final String? resultJson;
  final String? error;
  final int updatedAt;
  final int? startedAt;
  final int? completedAt;
  const GenerationTaskChunk({
    required this.id,
    required this.taskId,
    required this.chunkIndex,
    required this.sourceKey,
    required this.startMs,
    required this.endMs,
    required this.inputFingerprint,
    required this.status,
    required this.attempts,
    required this.priority,
    this.resultRef,
    this.resultJson,
    this.error,
    required this.updatedAt,
    this.startedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['chunk_index'] = Variable<int>(chunkIndex);
    map['source_key'] = Variable<String>(sourceKey);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['input_fingerprint'] = Variable<String>(inputFingerprint);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || resultRef != null) {
      map['result_ref'] = Variable<String>(resultRef);
    }
    if (!nullToAbsent || resultJson != null) {
      map['result_json'] = Variable<String>(resultJson);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    return map;
  }

  GenerationTaskChunksCompanion toCompanion(bool nullToAbsent) {
    return GenerationTaskChunksCompanion(
      id: Value(id),
      taskId: Value(taskId),
      chunkIndex: Value(chunkIndex),
      sourceKey: Value(sourceKey),
      startMs: Value(startMs),
      endMs: Value(endMs),
      inputFingerprint: Value(inputFingerprint),
      status: Value(status),
      attempts: Value(attempts),
      priority: Value(priority),
      resultRef: resultRef == null && nullToAbsent
          ? const Value.absent()
          : Value(resultRef),
      resultJson: resultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resultJson),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      updatedAt: Value(updatedAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory GenerationTaskChunk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GenerationTaskChunk(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      chunkIndex: serializer.fromJson<int>(json['chunkIndex']),
      sourceKey: serializer.fromJson<String>(json['sourceKey']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      inputFingerprint: serializer.fromJson<String>(json['inputFingerprint']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      priority: serializer.fromJson<int>(json['priority']),
      resultRef: serializer.fromJson<String?>(json['resultRef']),
      resultJson: serializer.fromJson<String?>(json['resultJson']),
      error: serializer.fromJson<String?>(json['error']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'chunkIndex': serializer.toJson<int>(chunkIndex),
      'sourceKey': serializer.toJson<String>(sourceKey),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'inputFingerprint': serializer.toJson<String>(inputFingerprint),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'priority': serializer.toJson<int>(priority),
      'resultRef': serializer.toJson<String?>(resultRef),
      'resultJson': serializer.toJson<String?>(resultJson),
      'error': serializer.toJson<String?>(error),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'startedAt': serializer.toJson<int?>(startedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
    };
  }

  GenerationTaskChunk copyWith({
    String? id,
    String? taskId,
    int? chunkIndex,
    String? sourceKey,
    int? startMs,
    int? endMs,
    String? inputFingerprint,
    String? status,
    int? attempts,
    int? priority,
    Value<String?> resultRef = const Value.absent(),
    Value<String?> resultJson = const Value.absent(),
    Value<String?> error = const Value.absent(),
    int? updatedAt,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
  }) => GenerationTaskChunk(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    chunkIndex: chunkIndex ?? this.chunkIndex,
    sourceKey: sourceKey ?? this.sourceKey,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    inputFingerprint: inputFingerprint ?? this.inputFingerprint,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    priority: priority ?? this.priority,
    resultRef: resultRef.present ? resultRef.value : this.resultRef,
    resultJson: resultJson.present ? resultJson.value : this.resultJson,
    error: error.present ? error.value : this.error,
    updatedAt: updatedAt ?? this.updatedAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  GenerationTaskChunk copyWithCompanion(GenerationTaskChunksCompanion data) {
    return GenerationTaskChunk(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      chunkIndex: data.chunkIndex.present
          ? data.chunkIndex.value
          : this.chunkIndex,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      inputFingerprint: data.inputFingerprint.present
          ? data.inputFingerprint.value
          : this.inputFingerprint,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      priority: data.priority.present ? data.priority.value : this.priority,
      resultRef: data.resultRef.present ? data.resultRef.value : this.resultRef,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      error: data.error.present ? data.error.value : this.error,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GenerationTaskChunk(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('inputFingerprint: $inputFingerprint, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('priority: $priority, ')
          ..write('resultRef: $resultRef, ')
          ..write('resultJson: $resultJson, ')
          ..write('error: $error, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    chunkIndex,
    sourceKey,
    startMs,
    endMs,
    inputFingerprint,
    status,
    attempts,
    priority,
    resultRef,
    resultJson,
    error,
    updatedAt,
    startedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GenerationTaskChunk &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.chunkIndex == this.chunkIndex &&
          other.sourceKey == this.sourceKey &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.inputFingerprint == this.inputFingerprint &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.priority == this.priority &&
          other.resultRef == this.resultRef &&
          other.resultJson == this.resultJson &&
          other.error == this.error &&
          other.updatedAt == this.updatedAt &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt);
}

class GenerationTaskChunksCompanion
    extends UpdateCompanion<GenerationTaskChunk> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<int> chunkIndex;
  final Value<String> sourceKey;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> inputFingerprint;
  final Value<String> status;
  final Value<int> attempts;
  final Value<int> priority;
  final Value<String?> resultRef;
  final Value<String?> resultJson;
  final Value<String?> error;
  final Value<int> updatedAt;
  final Value<int?> startedAt;
  final Value<int?> completedAt;
  final Value<int> rowid;
  const GenerationTaskChunksCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.chunkIndex = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.inputFingerprint = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.priority = const Value.absent(),
    this.resultRef = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.error = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GenerationTaskChunksCompanion.insert({
    required String id,
    required String taskId,
    required int chunkIndex,
    required String sourceKey,
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    required String inputFingerprint,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.priority = const Value.absent(),
    this.resultRef = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.error = const Value.absent(),
    required int updatedAt,
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       chunkIndex = Value(chunkIndex),
       sourceKey = Value(sourceKey),
       inputFingerprint = Value(inputFingerprint),
       updatedAt = Value(updatedAt);
  static Insertable<GenerationTaskChunk> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<int>? chunkIndex,
    Expression<String>? sourceKey,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? inputFingerprint,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<int>? priority,
    Expression<String>? resultRef,
    Expression<String>? resultJson,
    Expression<String>? error,
    Expression<int>? updatedAt,
    Expression<int>? startedAt,
    Expression<int>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (chunkIndex != null) 'chunk_index': chunkIndex,
      if (sourceKey != null) 'source_key': sourceKey,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (inputFingerprint != null) 'input_fingerprint': inputFingerprint,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (priority != null) 'priority': priority,
      if (resultRef != null) 'result_ref': resultRef,
      if (resultJson != null) 'result_json': resultJson,
      if (error != null) 'error': error,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GenerationTaskChunksCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<int>? chunkIndex,
    Value<String>? sourceKey,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String>? inputFingerprint,
    Value<String>? status,
    Value<int>? attempts,
    Value<int>? priority,
    Value<String?>? resultRef,
    Value<String?>? resultJson,
    Value<String?>? error,
    Value<int>? updatedAt,
    Value<int?>? startedAt,
    Value<int?>? completedAt,
    Value<int>? rowid,
  }) {
    return GenerationTaskChunksCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      sourceKey: sourceKey ?? this.sourceKey,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      inputFingerprint: inputFingerprint ?? this.inputFingerprint,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      priority: priority ?? this.priority,
      resultRef: resultRef ?? this.resultRef,
      resultJson: resultJson ?? this.resultJson,
      error: error ?? this.error,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (chunkIndex.present) {
      map['chunk_index'] = Variable<int>(chunkIndex.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (inputFingerprint.present) {
      map['input_fingerprint'] = Variable<String>(inputFingerprint.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (resultRef.present) {
      map['result_ref'] = Variable<String>(resultRef.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GenerationTaskChunksCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('inputFingerprint: $inputFingerprint, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('priority: $priority, ')
          ..write('resultRef: $resultRef, ')
          ..write('resultJson: $resultJson, ')
          ..write('error: $error, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $ChapterPlaybackProgressesTable chapterPlaybackProgresses =
      $ChapterPlaybackProgressesTable(this);
  late final $ParagraphsTable paragraphs = $ParagraphsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $VoicesTable voices = $VoicesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $CostRecordsTable costRecords = $CostRecordsTable(this);
  late final $ListeningDaysTable listeningDays = $ListeningDaysTable(this);
  late final $DictionaryEntriesTable dictionaryEntries =
      $DictionaryEntriesTable(this);
  late final $FavoriteWordsTable favoriteWords = $FavoriteWordsTable(this);
  late final $PodcastShowsTable podcastShows = $PodcastShowsTable(this);
  late final $PodcastEpisodesTable podcastEpisodes = $PodcastEpisodesTable(
    this,
  );
  late final $AiThreadsTable aiThreads = $AiThreadsTable(this);
  late final $AiMessagesTable aiMessages = $AiMessagesTable(this);
  late final $GenerationTasksTable generationTasks = $GenerationTasksTable(
    this,
  );
  late final $GenerationTaskChunksTable generationTaskChunks =
      $GenerationTaskChunksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    chapters,
    chapterPlaybackProgresses,
    paragraphs,
    bookmarks,
    voices,
    appSettings,
    costRecords,
    listeningDays,
    dictionaryEntries,
    favoriteWords,
    podcastShows,
    podcastEpisodes,
    aiThreads,
    aiMessages,
    generationTasks,
    generationTaskChunks,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      required String id,
      required String title,
      Value<String?> author,
      required String format,
      required String sourcePath,
      Value<String?> coverPath,
      Value<int> chapterCount,
      Value<int> paragraphCount,
      Value<String?> currentChapterId,
      Value<int> currentParagraphIndex,
      Value<int> playbackOffsetMs,
      Value<String?> voiceId,
      required int importedAt,
      Value<int> lastReadAt,
      Value<bool> isRead,
      Value<String> kind,
      Value<String?> externalSource,
      Value<String?> externalId,
      Value<String> rightsStatus,
      Value<String?> externalMetadataJson,
      Value<String?> language,
      Value<String?> readingLevelSystem,
      Value<String?> readingLevelCode,
      Value<String?> readingLevelSource,
      Value<int> rowid,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> author,
      Value<String> format,
      Value<String> sourcePath,
      Value<String?> coverPath,
      Value<int> chapterCount,
      Value<int> paragraphCount,
      Value<String?> currentChapterId,
      Value<int> currentParagraphIndex,
      Value<int> playbackOffsetMs,
      Value<String?> voiceId,
      Value<int> importedAt,
      Value<int> lastReadAt,
      Value<bool> isRead,
      Value<String> kind,
      Value<String?> externalSource,
      Value<String?> externalId,
      Value<String> rightsStatus,
      Value<String?> externalMetadataJson,
      Value<String?> language,
      Value<String?> readingLevelSystem,
      Value<String?> readingLevelCode,
      Value<String?> readingLevelSource,
      Value<int> rowid,
    });

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphCount => $composableBuilder(
    column: $table.paragraphCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentParagraphIndex => $composableBuilder(
    column: $table.currentParagraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playbackOffsetMs => $composableBuilder(
    column: $table.playbackOffsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceId => $composableBuilder(
    column: $table.voiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalSource => $composableBuilder(
    column: $table.externalSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rightsStatus => $composableBuilder(
    column: $table.rightsStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalMetadataJson => $composableBuilder(
    column: $table.externalMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingLevelSystem => $composableBuilder(
    column: $table.readingLevelSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingLevelCode => $composableBuilder(
    column: $table.readingLevelCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingLevelSource => $composableBuilder(
    column: $table.readingLevelSource,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphCount => $composableBuilder(
    column: $table.paragraphCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentParagraphIndex => $composableBuilder(
    column: $table.currentParagraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playbackOffsetMs => $composableBuilder(
    column: $table.playbackOffsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceId => $composableBuilder(
    column: $table.voiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalSource => $composableBuilder(
    column: $table.externalSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rightsStatus => $composableBuilder(
    column: $table.rightsStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalMetadataJson => $composableBuilder(
    column: $table.externalMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingLevelSystem => $composableBuilder(
    column: $table.readingLevelSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingLevelCode => $composableBuilder(
    column: $table.readingLevelCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingLevelSource => $composableBuilder(
    column: $table.readingLevelSource,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paragraphCount => $composableBuilder(
    column: $table.paragraphCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentParagraphIndex => $composableBuilder(
    column: $table.currentParagraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playbackOffsetMs => $composableBuilder(
    column: $table.playbackOffsetMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceId =>
      $composableBuilder(column: $table.voiceId, builder: (column) => column);

  GeneratedColumn<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get externalSource => $composableBuilder(
    column: $table.externalSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rightsStatus => $composableBuilder(
    column: $table.rightsStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalMetadataJson => $composableBuilder(
    column: $table.externalMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get readingLevelSystem => $composableBuilder(
    column: $table.readingLevelSystem,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readingLevelCode => $composableBuilder(
    column: $table.readingLevelCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readingLevelSource => $composableBuilder(
    column: $table.readingLevelSource,
    builder: (column) => column,
  );
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
          Book,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                Value<int> paragraphCount = const Value.absent(),
                Value<String?> currentChapterId = const Value.absent(),
                Value<int> currentParagraphIndex = const Value.absent(),
                Value<int> playbackOffsetMs = const Value.absent(),
                Value<String?> voiceId = const Value.absent(),
                Value<int> importedAt = const Value.absent(),
                Value<int> lastReadAt = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> externalSource = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<String> rightsStatus = const Value.absent(),
                Value<String?> externalMetadataJson = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> readingLevelSystem = const Value.absent(),
                Value<String?> readingLevelCode = const Value.absent(),
                Value<String?> readingLevelSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                author: author,
                format: format,
                sourcePath: sourcePath,
                coverPath: coverPath,
                chapterCount: chapterCount,
                paragraphCount: paragraphCount,
                currentChapterId: currentChapterId,
                currentParagraphIndex: currentParagraphIndex,
                playbackOffsetMs: playbackOffsetMs,
                voiceId: voiceId,
                importedAt: importedAt,
                lastReadAt: lastReadAt,
                isRead: isRead,
                kind: kind,
                externalSource: externalSource,
                externalId: externalId,
                rightsStatus: rightsStatus,
                externalMetadataJson: externalMetadataJson,
                language: language,
                readingLevelSystem: readingLevelSystem,
                readingLevelCode: readingLevelCode,
                readingLevelSource: readingLevelSource,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> author = const Value.absent(),
                required String format,
                required String sourcePath,
                Value<String?> coverPath = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                Value<int> paragraphCount = const Value.absent(),
                Value<String?> currentChapterId = const Value.absent(),
                Value<int> currentParagraphIndex = const Value.absent(),
                Value<int> playbackOffsetMs = const Value.absent(),
                Value<String?> voiceId = const Value.absent(),
                required int importedAt,
                Value<int> lastReadAt = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> externalSource = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<String> rightsStatus = const Value.absent(),
                Value<String?> externalMetadataJson = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> readingLevelSystem = const Value.absent(),
                Value<String?> readingLevelCode = const Value.absent(),
                Value<String?> readingLevelSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                author: author,
                format: format,
                sourcePath: sourcePath,
                coverPath: coverPath,
                chapterCount: chapterCount,
                paragraphCount: paragraphCount,
                currentChapterId: currentChapterId,
                currentParagraphIndex: currentParagraphIndex,
                playbackOffsetMs: playbackOffsetMs,
                voiceId: voiceId,
                importedAt: importedAt,
                lastReadAt: lastReadAt,
                isRead: isRead,
                kind: kind,
                externalSource: externalSource,
                externalId: externalId,
                rightsStatus: rightsStatus,
                externalMetadataJson: externalMetadataJson,
                language: language,
                readingLevelSystem: readingLevelSystem,
                readingLevelCode: readingLevelCode,
                readingLevelSource: readingLevelSource,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
      Book,
      PrefetchHooks Function()
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      required String id,
      required String bookId,
      required int chapterIndex,
      required String title,
      Value<int> textOffset,
      Value<String?> voiceId,
      Value<bool> isHidden,
      Value<int> rowid,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<String> title,
      Value<int> textOffset,
      Value<String?> voiceId,
      Value<bool> isHidden,
      Value<int> rowid,
    });

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceId => $composableBuilder(
    column: $table.voiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceId => $composableBuilder(
    column: $table.voiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceId =>
      $composableBuilder(column: $table.voiceId, builder: (column) => column);

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
          Chapter,
          PrefetchHooks Function()
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> textOffset = const Value.absent(),
                Value<String?> voiceId = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                title: title,
                textOffset: textOffset,
                voiceId: voiceId,
                isHidden: isHidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int chapterIndex,
                required String title,
                Value<int> textOffset = const Value.absent(),
                Value<String?> voiceId = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                title: title,
                textOffset: textOffset,
                voiceId: voiceId,
                isHidden: isHidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, BaseReferences<_$AppDatabase, $ChaptersTable, Chapter>),
      Chapter,
      PrefetchHooks Function()
    >;
typedef $$ChapterPlaybackProgressesTableCreateCompanionBuilder =
    ChapterPlaybackProgressesCompanion Function({
      required String chapterId,
      required String bookId,
      Value<int> positionMs,
      Value<int> paragraphIndex,
      Value<int> paragraphOffsetMs,
      Value<bool> isFinished,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ChapterPlaybackProgressesTableUpdateCompanionBuilder =
    ChapterPlaybackProgressesCompanion Function({
      Value<String> chapterId,
      Value<String> bookId,
      Value<int> positionMs,
      Value<int> paragraphIndex,
      Value<int> paragraphOffsetMs,
      Value<bool> isFinished,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ChapterPlaybackProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $ChapterPlaybackProgressesTable> {
  $$ChapterPlaybackProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphOffsetMs => $composableBuilder(
    column: $table.paragraphOffsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChapterPlaybackProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChapterPlaybackProgressesTable> {
  $$ChapterPlaybackProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphOffsetMs => $composableBuilder(
    column: $table.paragraphOffsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChapterPlaybackProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChapterPlaybackProgressesTable> {
  $$ChapterPlaybackProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paragraphOffsetMs => $composableBuilder(
    column: $table.paragraphOffsetMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChapterPlaybackProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChapterPlaybackProgressesTable,
          ChapterPlaybackProgress,
          $$ChapterPlaybackProgressesTableFilterComposer,
          $$ChapterPlaybackProgressesTableOrderingComposer,
          $$ChapterPlaybackProgressesTableAnnotationComposer,
          $$ChapterPlaybackProgressesTableCreateCompanionBuilder,
          $$ChapterPlaybackProgressesTableUpdateCompanionBuilder,
          (
            ChapterPlaybackProgress,
            BaseReferences<
              _$AppDatabase,
              $ChapterPlaybackProgressesTable,
              ChapterPlaybackProgress
            >,
          ),
          ChapterPlaybackProgress,
          PrefetchHooks Function()
        > {
  $$ChapterPlaybackProgressesTableTableManager(
    _$AppDatabase db,
    $ChapterPlaybackProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterPlaybackProgressesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ChapterPlaybackProgressesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ChapterPlaybackProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> chapterId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<int> paragraphOffsetMs = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChapterPlaybackProgressesCompanion(
                chapterId: chapterId,
                bookId: bookId,
                positionMs: positionMs,
                paragraphIndex: paragraphIndex,
                paragraphOffsetMs: paragraphOffsetMs,
                isFinished: isFinished,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chapterId,
                required String bookId,
                Value<int> positionMs = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<int> paragraphOffsetMs = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChapterPlaybackProgressesCompanion.insert(
                chapterId: chapterId,
                bookId: bookId,
                positionMs: positionMs,
                paragraphIndex: paragraphIndex,
                paragraphOffsetMs: paragraphOffsetMs,
                isFinished: isFinished,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChapterPlaybackProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChapterPlaybackProgressesTable,
      ChapterPlaybackProgress,
      $$ChapterPlaybackProgressesTableFilterComposer,
      $$ChapterPlaybackProgressesTableOrderingComposer,
      $$ChapterPlaybackProgressesTableAnnotationComposer,
      $$ChapterPlaybackProgressesTableCreateCompanionBuilder,
      $$ChapterPlaybackProgressesTableUpdateCompanionBuilder,
      (
        ChapterPlaybackProgress,
        BaseReferences<
          _$AppDatabase,
          $ChapterPlaybackProgressesTable,
          ChapterPlaybackProgress
        >,
      ),
      ChapterPlaybackProgress,
      PrefetchHooks Function()
    >;
typedef $$ParagraphsTableCreateCompanionBuilder =
    ParagraphsCompanion Function({
      required String id,
      required String chapterId,
      required String bookId,
      required int paragraphIndex,
      required String content,
      Value<int> rowid,
    });
typedef $$ParagraphsTableUpdateCompanionBuilder =
    ParagraphsCompanion Function({
      Value<String> id,
      Value<String> chapterId,
      Value<String> bookId,
      Value<int> paragraphIndex,
      Value<String> content,
      Value<int> rowid,
    });

class $$ParagraphsTableFilterComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParagraphsTableOrderingComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParagraphsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$ParagraphsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParagraphsTable,
          Paragraph,
          $$ParagraphsTableFilterComposer,
          $$ParagraphsTableOrderingComposer,
          $$ParagraphsTableAnnotationComposer,
          $$ParagraphsTableCreateCompanionBuilder,
          $$ParagraphsTableUpdateCompanionBuilder,
          (
            Paragraph,
            BaseReferences<_$AppDatabase, $ParagraphsTable, Paragraph>,
          ),
          Paragraph,
          PrefetchHooks Function()
        > {
  $$ParagraphsTableTableManager(_$AppDatabase db, $ParagraphsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParagraphsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParagraphsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParagraphsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParagraphsCompanion(
                id: id,
                chapterId: chapterId,
                bookId: bookId,
                paragraphIndex: paragraphIndex,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chapterId,
                required String bookId,
                required int paragraphIndex,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => ParagraphsCompanion.insert(
                id: id,
                chapterId: chapterId,
                bookId: bookId,
                paragraphIndex: paragraphIndex,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParagraphsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParagraphsTable,
      Paragraph,
      $$ParagraphsTableFilterComposer,
      $$ParagraphsTableOrderingComposer,
      $$ParagraphsTableAnnotationComposer,
      $$ParagraphsTableCreateCompanionBuilder,
      $$ParagraphsTableUpdateCompanionBuilder,
      (Paragraph, BaseReferences<_$AppDatabase, $ParagraphsTable, Paragraph>),
      Paragraph,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required String bookId,
      required String chapterId,
      required int paragraphIndex,
      required String excerpt,
      Value<String?> note,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> chapterId,
      Value<int> paragraphIndex,
      Value<String> excerpt,
      Value<String?> note,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get excerpt =>
      $composableBuilder(column: $table.excerpt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<String> excerpt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                paragraphIndex: paragraphIndex,
                excerpt: excerpt,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String chapterId,
                required int paragraphIndex,
                required String excerpt,
                Value<String?> note = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                paragraphIndex: paragraphIndex,
                excerpt: excerpt,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;
typedef $$VoicesTableCreateCompanionBuilder =
    VoicesCompanion Function({
      required String id,
      required String name,
      required String providerId,
      required String type,
      required String providerVoiceId,
      Value<String?> samplePath,
      Value<String?> description,
      Value<String?> presetDescription,
      Value<String?> previewUrl,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$VoicesTableUpdateCompanionBuilder =
    VoicesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> providerId,
      Value<String> type,
      Value<String> providerVoiceId,
      Value<String?> samplePath,
      Value<String?> description,
      Value<String?> presetDescription,
      Value<String?> previewUrl,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$VoicesTableFilterComposer
    extends Composer<_$AppDatabase, $VoicesTable> {
  $$VoicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerVoiceId => $composableBuilder(
    column: $table.providerVoiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get samplePath => $composableBuilder(
    column: $table.samplePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetDescription => $composableBuilder(
    column: $table.presetDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VoicesTableOrderingComposer
    extends Composer<_$AppDatabase, $VoicesTable> {
  $$VoicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerVoiceId => $composableBuilder(
    column: $table.providerVoiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get samplePath => $composableBuilder(
    column: $table.samplePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetDescription => $composableBuilder(
    column: $table.presetDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VoicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoicesTable> {
  $$VoicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get providerVoiceId => $composableBuilder(
    column: $table.providerVoiceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get samplePath => $composableBuilder(
    column: $table.samplePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get presetDescription => $composableBuilder(
    column: $table.presetDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$VoicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VoicesTable,
          Voice,
          $$VoicesTableFilterComposer,
          $$VoicesTableOrderingComposer,
          $$VoicesTableAnnotationComposer,
          $$VoicesTableCreateCompanionBuilder,
          $$VoicesTableUpdateCompanionBuilder,
          (Voice, BaseReferences<_$AppDatabase, $VoicesTable, Voice>),
          Voice,
          PrefetchHooks Function()
        > {
  $$VoicesTableTableManager(_$AppDatabase db, $VoicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> providerVoiceId = const Value.absent(),
                Value<String?> samplePath = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> presetDescription = const Value.absent(),
                Value<String?> previewUrl = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoicesCompanion(
                id: id,
                name: name,
                providerId: providerId,
                type: type,
                providerVoiceId: providerVoiceId,
                samplePath: samplePath,
                description: description,
                presetDescription: presetDescription,
                previewUrl: previewUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String providerId,
                required String type,
                required String providerVoiceId,
                Value<String?> samplePath = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> presetDescription = const Value.absent(),
                Value<String?> previewUrl = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VoicesCompanion.insert(
                id: id,
                name: name,
                providerId: providerId,
                type: type,
                providerVoiceId: providerVoiceId,
                samplePath: samplePath,
                description: description,
                presetDescription: presetDescription,
                previewUrl: previewUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VoicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VoicesTable,
      Voice,
      $$VoicesTableFilterComposer,
      $$VoicesTableOrderingComposer,
      $$VoicesTableAnnotationComposer,
      $$VoicesTableCreateCompanionBuilder,
      $$VoicesTableUpdateCompanionBuilder,
      (Voice, BaseReferences<_$AppDatabase, $VoicesTable, Voice>),
      Voice,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$CostRecordsTableCreateCompanionBuilder =
    CostRecordsCompanion Function({
      Value<int> id,
      required String bookId,
      required String chapterId,
      required String providerId,
      required int characters,
      required int createdAt,
    });
typedef $$CostRecordsTableUpdateCompanionBuilder =
    CostRecordsCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<String> chapterId,
      Value<String> providerId,
      Value<int> characters,
      Value<int> createdAt,
    });

class $$CostRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $CostRecordsTable> {
  $$CostRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get characters => $composableBuilder(
    column: $table.characters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CostRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $CostRecordsTable> {
  $$CostRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get characters => $composableBuilder(
    column: $table.characters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CostRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CostRecordsTable> {
  $$CostRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get characters => $composableBuilder(
    column: $table.characters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CostRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CostRecordsTable,
          CostRecord,
          $$CostRecordsTableFilterComposer,
          $$CostRecordsTableOrderingComposer,
          $$CostRecordsTableAnnotationComposer,
          $$CostRecordsTableCreateCompanionBuilder,
          $$CostRecordsTableUpdateCompanionBuilder,
          (
            CostRecord,
            BaseReferences<_$AppDatabase, $CostRecordsTable, CostRecord>,
          ),
          CostRecord,
          PrefetchHooks Function()
        > {
  $$CostRecordsTableTableManager(_$AppDatabase db, $CostRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CostRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CostRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CostRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<int> characters = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => CostRecordsCompanion(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                providerId: providerId,
                characters: characters,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required String chapterId,
                required String providerId,
                required int characters,
                required int createdAt,
              }) => CostRecordsCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                providerId: providerId,
                characters: characters,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CostRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CostRecordsTable,
      CostRecord,
      $$CostRecordsTableFilterComposer,
      $$CostRecordsTableOrderingComposer,
      $$CostRecordsTableAnnotationComposer,
      $$CostRecordsTableCreateCompanionBuilder,
      $$CostRecordsTableUpdateCompanionBuilder,
      (
        CostRecord,
        BaseReferences<_$AppDatabase, $CostRecordsTable, CostRecord>,
      ),
      CostRecord,
      PrefetchHooks Function()
    >;
typedef $$ListeningDaysTableCreateCompanionBuilder =
    ListeningDaysCompanion Function({
      required String dateKey,
      Value<int> listenedMs,
      Value<int> sessions,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ListeningDaysTableUpdateCompanionBuilder =
    ListeningDaysCompanion Function({
      Value<String> dateKey,
      Value<int> listenedMs,
      Value<int> sessions,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ListeningDaysTableFilterComposer
    extends Composer<_$AppDatabase, $ListeningDaysTable> {
  $$ListeningDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessions => $composableBuilder(
    column: $table.sessions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ListeningDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $ListeningDaysTable> {
  $$ListeningDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessions => $composableBuilder(
    column: $table.sessions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListeningDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListeningDaysTable> {
  $$ListeningDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get listenedMs => $composableBuilder(
    column: $table.listenedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sessions =>
      $composableBuilder(column: $table.sessions, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ListeningDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListeningDaysTable,
          ListeningDay,
          $$ListeningDaysTableFilterComposer,
          $$ListeningDaysTableOrderingComposer,
          $$ListeningDaysTableAnnotationComposer,
          $$ListeningDaysTableCreateCompanionBuilder,
          $$ListeningDaysTableUpdateCompanionBuilder,
          (
            ListeningDay,
            BaseReferences<_$AppDatabase, $ListeningDaysTable, ListeningDay>,
          ),
          ListeningDay,
          PrefetchHooks Function()
        > {
  $$ListeningDaysTableTableManager(_$AppDatabase db, $ListeningDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListeningDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListeningDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListeningDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dateKey = const Value.absent(),
                Value<int> listenedMs = const Value.absent(),
                Value<int> sessions = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListeningDaysCompanion(
                dateKey: dateKey,
                listenedMs: listenedMs,
                sessions: sessions,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dateKey,
                Value<int> listenedMs = const Value.absent(),
                Value<int> sessions = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ListeningDaysCompanion.insert(
                dateKey: dateKey,
                listenedMs: listenedMs,
                sessions: sessions,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ListeningDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListeningDaysTable,
      ListeningDay,
      $$ListeningDaysTableFilterComposer,
      $$ListeningDaysTableOrderingComposer,
      $$ListeningDaysTableAnnotationComposer,
      $$ListeningDaysTableCreateCompanionBuilder,
      $$ListeningDaysTableUpdateCompanionBuilder,
      (
        ListeningDay,
        BaseReferences<_$AppDatabase, $ListeningDaysTable, ListeningDay>,
      ),
      ListeningDay,
      PrefetchHooks Function()
    >;
typedef $$DictionaryEntriesTableCreateCompanionBuilder =
    DictionaryEntriesCompanion Function({
      required String id,
      required String provider,
      required String language,
      required String normalizedTerm,
      required String displayWord,
      required String status,
      Value<String?> usPhonetic,
      Value<String?> ukPhonetic,
      Value<String?> definitionsJson,
      Value<String?> otherFormsJson,
      Value<String?> shortExplanation,
      Value<String?> longExplanation,
      required String sourceUrl,
      Value<String?> readingLevelSystem,
      Value<String?> readingLevelCode,
      Value<String?> readingLevelSource,
      required int fetchedAt,
      Value<int?> expiresAt,
      required int lastAccessedAt,
      Value<int> accessCount,
      Value<int> rowid,
    });
typedef $$DictionaryEntriesTableUpdateCompanionBuilder =
    DictionaryEntriesCompanion Function({
      Value<String> id,
      Value<String> provider,
      Value<String> language,
      Value<String> normalizedTerm,
      Value<String> displayWord,
      Value<String> status,
      Value<String?> usPhonetic,
      Value<String?> ukPhonetic,
      Value<String?> definitionsJson,
      Value<String?> otherFormsJson,
      Value<String?> shortExplanation,
      Value<String?> longExplanation,
      Value<String> sourceUrl,
      Value<String?> readingLevelSystem,
      Value<String?> readingLevelCode,
      Value<String?> readingLevelSource,
      Value<int> fetchedAt,
      Value<int?> expiresAt,
      Value<int> lastAccessedAt,
      Value<int> accessCount,
      Value<int> rowid,
    });

class $$DictionaryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTable> {
  $$DictionaryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedTerm => $composableBuilder(
    column: $table.normalizedTerm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayWord => $composableBuilder(
    column: $table.displayWord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usPhonetic => $composableBuilder(
    column: $table.usPhonetic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ukPhonetic => $composableBuilder(
    column: $table.ukPhonetic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionsJson => $composableBuilder(
    column: $table.definitionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherFormsJson => $composableBuilder(
    column: $table.otherFormsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortExplanation => $composableBuilder(
    column: $table.shortExplanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get longExplanation => $composableBuilder(
    column: $table.longExplanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingLevelSystem => $composableBuilder(
    column: $table.readingLevelSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingLevelCode => $composableBuilder(
    column: $table.readingLevelCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingLevelSource => $composableBuilder(
    column: $table.readingLevelSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DictionaryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTable> {
  $$DictionaryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedTerm => $composableBuilder(
    column: $table.normalizedTerm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayWord => $composableBuilder(
    column: $table.displayWord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usPhonetic => $composableBuilder(
    column: $table.usPhonetic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ukPhonetic => $composableBuilder(
    column: $table.ukPhonetic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionsJson => $composableBuilder(
    column: $table.definitionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherFormsJson => $composableBuilder(
    column: $table.otherFormsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortExplanation => $composableBuilder(
    column: $table.shortExplanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get longExplanation => $composableBuilder(
    column: $table.longExplanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingLevelSystem => $composableBuilder(
    column: $table.readingLevelSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingLevelCode => $composableBuilder(
    column: $table.readingLevelCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingLevelSource => $composableBuilder(
    column: $table.readingLevelSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DictionaryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DictionaryEntriesTable> {
  $$DictionaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get normalizedTerm => $composableBuilder(
    column: $table.normalizedTerm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayWord => $composableBuilder(
    column: $table.displayWord,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get usPhonetic => $composableBuilder(
    column: $table.usPhonetic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ukPhonetic => $composableBuilder(
    column: $table.ukPhonetic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definitionsJson => $composableBuilder(
    column: $table.definitionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get otherFormsJson => $composableBuilder(
    column: $table.otherFormsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shortExplanation => $composableBuilder(
    column: $table.shortExplanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get longExplanation => $composableBuilder(
    column: $table.longExplanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get readingLevelSystem => $composableBuilder(
    column: $table.readingLevelSystem,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readingLevelCode => $composableBuilder(
    column: $table.readingLevelCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readingLevelSource => $composableBuilder(
    column: $table.readingLevelSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => column,
  );
}

class $$DictionaryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DictionaryEntriesTable,
          DictionaryEntry,
          $$DictionaryEntriesTableFilterComposer,
          $$DictionaryEntriesTableOrderingComposer,
          $$DictionaryEntriesTableAnnotationComposer,
          $$DictionaryEntriesTableCreateCompanionBuilder,
          $$DictionaryEntriesTableUpdateCompanionBuilder,
          (
            DictionaryEntry,
            BaseReferences<
              _$AppDatabase,
              $DictionaryEntriesTable,
              DictionaryEntry
            >,
          ),
          DictionaryEntry,
          PrefetchHooks Function()
        > {
  $$DictionaryEntriesTableTableManager(
    _$AppDatabase db,
    $DictionaryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionaryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictionaryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictionaryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> normalizedTerm = const Value.absent(),
                Value<String> displayWord = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> usPhonetic = const Value.absent(),
                Value<String?> ukPhonetic = const Value.absent(),
                Value<String?> definitionsJson = const Value.absent(),
                Value<String?> otherFormsJson = const Value.absent(),
                Value<String?> shortExplanation = const Value.absent(),
                Value<String?> longExplanation = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String?> readingLevelSystem = const Value.absent(),
                Value<String?> readingLevelCode = const Value.absent(),
                Value<String?> readingLevelSource = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<int> lastAccessedAt = const Value.absent(),
                Value<int> accessCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DictionaryEntriesCompanion(
                id: id,
                provider: provider,
                language: language,
                normalizedTerm: normalizedTerm,
                displayWord: displayWord,
                status: status,
                usPhonetic: usPhonetic,
                ukPhonetic: ukPhonetic,
                definitionsJson: definitionsJson,
                otherFormsJson: otherFormsJson,
                shortExplanation: shortExplanation,
                longExplanation: longExplanation,
                sourceUrl: sourceUrl,
                readingLevelSystem: readingLevelSystem,
                readingLevelCode: readingLevelCode,
                readingLevelSource: readingLevelSource,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
                lastAccessedAt: lastAccessedAt,
                accessCount: accessCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String provider,
                required String language,
                required String normalizedTerm,
                required String displayWord,
                required String status,
                Value<String?> usPhonetic = const Value.absent(),
                Value<String?> ukPhonetic = const Value.absent(),
                Value<String?> definitionsJson = const Value.absent(),
                Value<String?> otherFormsJson = const Value.absent(),
                Value<String?> shortExplanation = const Value.absent(),
                Value<String?> longExplanation = const Value.absent(),
                required String sourceUrl,
                Value<String?> readingLevelSystem = const Value.absent(),
                Value<String?> readingLevelCode = const Value.absent(),
                Value<String?> readingLevelSource = const Value.absent(),
                required int fetchedAt,
                Value<int?> expiresAt = const Value.absent(),
                required int lastAccessedAt,
                Value<int> accessCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DictionaryEntriesCompanion.insert(
                id: id,
                provider: provider,
                language: language,
                normalizedTerm: normalizedTerm,
                displayWord: displayWord,
                status: status,
                usPhonetic: usPhonetic,
                ukPhonetic: ukPhonetic,
                definitionsJson: definitionsJson,
                otherFormsJson: otherFormsJson,
                shortExplanation: shortExplanation,
                longExplanation: longExplanation,
                sourceUrl: sourceUrl,
                readingLevelSystem: readingLevelSystem,
                readingLevelCode: readingLevelCode,
                readingLevelSource: readingLevelSource,
                fetchedAt: fetchedAt,
                expiresAt: expiresAt,
                lastAccessedAt: lastAccessedAt,
                accessCount: accessCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DictionaryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DictionaryEntriesTable,
      DictionaryEntry,
      $$DictionaryEntriesTableFilterComposer,
      $$DictionaryEntriesTableOrderingComposer,
      $$DictionaryEntriesTableAnnotationComposer,
      $$DictionaryEntriesTableCreateCompanionBuilder,
      $$DictionaryEntriesTableUpdateCompanionBuilder,
      (
        DictionaryEntry,
        BaseReferences<_$AppDatabase, $DictionaryEntriesTable, DictionaryEntry>,
      ),
      DictionaryEntry,
      PrefetchHooks Function()
    >;
typedef $$FavoriteWordsTableCreateCompanionBuilder =
    FavoriteWordsCompanion Function({
      required String id,
      required String dictionaryEntryId,
      Value<String?> contextText,
      Value<int?> selectionStart,
      Value<int?> selectionEnd,
      Value<String?> sourceBookId,
      Value<String?> sourceBookTitle,
      Value<String?> sourceChapterId,
      Value<String?> sourceChapterTitle,
      Value<String?> sourceParagraphId,
      Value<String?> sourceLineId,
      Value<int?> audioStartMs,
      Value<int?> audioEndMs,
      required int favoritedAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$FavoriteWordsTableUpdateCompanionBuilder =
    FavoriteWordsCompanion Function({
      Value<String> id,
      Value<String> dictionaryEntryId,
      Value<String?> contextText,
      Value<int?> selectionStart,
      Value<int?> selectionEnd,
      Value<String?> sourceBookId,
      Value<String?> sourceBookTitle,
      Value<String?> sourceChapterId,
      Value<String?> sourceChapterTitle,
      Value<String?> sourceParagraphId,
      Value<String?> sourceLineId,
      Value<int?> audioStartMs,
      Value<int?> audioEndMs,
      Value<int> favoritedAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$FavoriteWordsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteWordsTable> {
  $$FavoriteWordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dictionaryEntryId => $composableBuilder(
    column: $table.dictionaryEntryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get selectionStart => $composableBuilder(
    column: $table.selectionStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get selectionEnd => $composableBuilder(
    column: $table.selectionEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceBookTitle => $composableBuilder(
    column: $table.sourceBookTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceChapterTitle => $composableBuilder(
    column: $table.sourceChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceParagraphId => $composableBuilder(
    column: $table.sourceParagraphId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLineId => $composableBuilder(
    column: $table.sourceLineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioStartMs => $composableBuilder(
    column: $table.audioStartMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioEndMs => $composableBuilder(
    column: $table.audioEndMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoriteWordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteWordsTable> {
  $$FavoriteWordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dictionaryEntryId => $composableBuilder(
    column: $table.dictionaryEntryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selectionStart => $composableBuilder(
    column: $table.selectionStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selectionEnd => $composableBuilder(
    column: $table.selectionEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceBookTitle => $composableBuilder(
    column: $table.sourceBookTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceChapterTitle => $composableBuilder(
    column: $table.sourceChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceParagraphId => $composableBuilder(
    column: $table.sourceParagraphId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLineId => $composableBuilder(
    column: $table.sourceLineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioStartMs => $composableBuilder(
    column: $table.audioStartMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioEndMs => $composableBuilder(
    column: $table.audioEndMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteWordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteWordsTable> {
  $$FavoriteWordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dictionaryEntryId => $composableBuilder(
    column: $table.dictionaryEntryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contextText => $composableBuilder(
    column: $table.contextText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get selectionStart => $composableBuilder(
    column: $table.selectionStart,
    builder: (column) => column,
  );

  GeneratedColumn<int> get selectionEnd => $composableBuilder(
    column: $table.selectionEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceBookId => $composableBuilder(
    column: $table.sourceBookId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceBookTitle => $composableBuilder(
    column: $table.sourceBookTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceChapterTitle => $composableBuilder(
    column: $table.sourceChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceParagraphId => $composableBuilder(
    column: $table.sourceParagraphId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceLineId => $composableBuilder(
    column: $table.sourceLineId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioStartMs => $composableBuilder(
    column: $table.audioStartMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioEndMs => $composableBuilder(
    column: $table.audioEndMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FavoriteWordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteWordsTable,
          FavoriteWord,
          $$FavoriteWordsTableFilterComposer,
          $$FavoriteWordsTableOrderingComposer,
          $$FavoriteWordsTableAnnotationComposer,
          $$FavoriteWordsTableCreateCompanionBuilder,
          $$FavoriteWordsTableUpdateCompanionBuilder,
          (
            FavoriteWord,
            BaseReferences<_$AppDatabase, $FavoriteWordsTable, FavoriteWord>,
          ),
          FavoriteWord,
          PrefetchHooks Function()
        > {
  $$FavoriteWordsTableTableManager(_$AppDatabase db, $FavoriteWordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteWordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteWordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteWordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dictionaryEntryId = const Value.absent(),
                Value<String?> contextText = const Value.absent(),
                Value<int?> selectionStart = const Value.absent(),
                Value<int?> selectionEnd = const Value.absent(),
                Value<String?> sourceBookId = const Value.absent(),
                Value<String?> sourceBookTitle = const Value.absent(),
                Value<String?> sourceChapterId = const Value.absent(),
                Value<String?> sourceChapterTitle = const Value.absent(),
                Value<String?> sourceParagraphId = const Value.absent(),
                Value<String?> sourceLineId = const Value.absent(),
                Value<int?> audioStartMs = const Value.absent(),
                Value<int?> audioEndMs = const Value.absent(),
                Value<int> favoritedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteWordsCompanion(
                id: id,
                dictionaryEntryId: dictionaryEntryId,
                contextText: contextText,
                selectionStart: selectionStart,
                selectionEnd: selectionEnd,
                sourceBookId: sourceBookId,
                sourceBookTitle: sourceBookTitle,
                sourceChapterId: sourceChapterId,
                sourceChapterTitle: sourceChapterTitle,
                sourceParagraphId: sourceParagraphId,
                sourceLineId: sourceLineId,
                audioStartMs: audioStartMs,
                audioEndMs: audioEndMs,
                favoritedAt: favoritedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dictionaryEntryId,
                Value<String?> contextText = const Value.absent(),
                Value<int?> selectionStart = const Value.absent(),
                Value<int?> selectionEnd = const Value.absent(),
                Value<String?> sourceBookId = const Value.absent(),
                Value<String?> sourceBookTitle = const Value.absent(),
                Value<String?> sourceChapterId = const Value.absent(),
                Value<String?> sourceChapterTitle = const Value.absent(),
                Value<String?> sourceParagraphId = const Value.absent(),
                Value<String?> sourceLineId = const Value.absent(),
                Value<int?> audioStartMs = const Value.absent(),
                Value<int?> audioEndMs = const Value.absent(),
                required int favoritedAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteWordsCompanion.insert(
                id: id,
                dictionaryEntryId: dictionaryEntryId,
                contextText: contextText,
                selectionStart: selectionStart,
                selectionEnd: selectionEnd,
                sourceBookId: sourceBookId,
                sourceBookTitle: sourceBookTitle,
                sourceChapterId: sourceChapterId,
                sourceChapterTitle: sourceChapterTitle,
                sourceParagraphId: sourceParagraphId,
                sourceLineId: sourceLineId,
                audioStartMs: audioStartMs,
                audioEndMs: audioEndMs,
                favoritedAt: favoritedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoriteWordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteWordsTable,
      FavoriteWord,
      $$FavoriteWordsTableFilterComposer,
      $$FavoriteWordsTableOrderingComposer,
      $$FavoriteWordsTableAnnotationComposer,
      $$FavoriteWordsTableCreateCompanionBuilder,
      $$FavoriteWordsTableUpdateCompanionBuilder,
      (
        FavoriteWord,
        BaseReferences<_$AppDatabase, $FavoriteWordsTable, FavoriteWord>,
      ),
      FavoriteWord,
      PrefetchHooks Function()
    >;
typedef $$PodcastShowsTableCreateCompanionBuilder =
    PodcastShowsCompanion Function({
      required String id,
      required String feedUrl,
      required String title,
      Value<String?> author,
      Value<String> description,
      Value<String?> imageUrl,
      Value<String?> language,
      Value<String?> websiteUrl,
      Value<String?> categoriesJson,
      required int subscribedAt,
      required int lastRefreshedAt,
      Value<int> rowid,
    });
typedef $$PodcastShowsTableUpdateCompanionBuilder =
    PodcastShowsCompanion Function({
      Value<String> id,
      Value<String> feedUrl,
      Value<String> title,
      Value<String?> author,
      Value<String> description,
      Value<String?> imageUrl,
      Value<String?> language,
      Value<String?> websiteUrl,
      Value<String?> categoriesJson,
      Value<int> subscribedAt,
      Value<int> lastRefreshedAt,
      Value<int> rowid,
    });

class $$PodcastShowsTableFilterComposer
    extends Composer<_$AppDatabase, $PodcastShowsTable> {
  $$PodcastShowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedUrl => $composableBuilder(
    column: $table.feedUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get websiteUrl => $composableBuilder(
    column: $table.websiteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRefreshedAt => $composableBuilder(
    column: $table.lastRefreshedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PodcastShowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PodcastShowsTable> {
  $$PodcastShowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedUrl => $composableBuilder(
    column: $table.feedUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get websiteUrl => $composableBuilder(
    column: $table.websiteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRefreshedAt => $composableBuilder(
    column: $table.lastRefreshedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PodcastShowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PodcastShowsTable> {
  $$PodcastShowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get feedUrl =>
      $composableBuilder(column: $table.feedUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get websiteUrl => $composableBuilder(
    column: $table.websiteUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastRefreshedAt => $composableBuilder(
    column: $table.lastRefreshedAt,
    builder: (column) => column,
  );
}

class $$PodcastShowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PodcastShowsTable,
          PodcastShow,
          $$PodcastShowsTableFilterComposer,
          $$PodcastShowsTableOrderingComposer,
          $$PodcastShowsTableAnnotationComposer,
          $$PodcastShowsTableCreateCompanionBuilder,
          $$PodcastShowsTableUpdateCompanionBuilder,
          (
            PodcastShow,
            BaseReferences<_$AppDatabase, $PodcastShowsTable, PodcastShow>,
          ),
          PodcastShow,
          PrefetchHooks Function()
        > {
  $$PodcastShowsTableTableManager(_$AppDatabase db, $PodcastShowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PodcastShowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PodcastShowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastShowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> feedUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> websiteUrl = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                Value<int> subscribedAt = const Value.absent(),
                Value<int> lastRefreshedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PodcastShowsCompanion(
                id: id,
                feedUrl: feedUrl,
                title: title,
                author: author,
                description: description,
                imageUrl: imageUrl,
                language: language,
                websiteUrl: websiteUrl,
                categoriesJson: categoriesJson,
                subscribedAt: subscribedAt,
                lastRefreshedAt: lastRefreshedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String feedUrl,
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> websiteUrl = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                required int subscribedAt,
                required int lastRefreshedAt,
                Value<int> rowid = const Value.absent(),
              }) => PodcastShowsCompanion.insert(
                id: id,
                feedUrl: feedUrl,
                title: title,
                author: author,
                description: description,
                imageUrl: imageUrl,
                language: language,
                websiteUrl: websiteUrl,
                categoriesJson: categoriesJson,
                subscribedAt: subscribedAt,
                lastRefreshedAt: lastRefreshedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PodcastShowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PodcastShowsTable,
      PodcastShow,
      $$PodcastShowsTableFilterComposer,
      $$PodcastShowsTableOrderingComposer,
      $$PodcastShowsTableAnnotationComposer,
      $$PodcastShowsTableCreateCompanionBuilder,
      $$PodcastShowsTableUpdateCompanionBuilder,
      (
        PodcastShow,
        BaseReferences<_$AppDatabase, $PodcastShowsTable, PodcastShow>,
      ),
      PodcastShow,
      PrefetchHooks Function()
    >;
typedef $$PodcastEpisodesTableCreateCompanionBuilder =
    PodcastEpisodesCompanion Function({
      required String id,
      required String showId,
      required String guid,
      required String title,
      Value<String> description,
      required String audioUrl,
      Value<String?> imageUrl,
      Value<int> publishedAt,
      Value<int> durationMs,
      Value<int> playbackPositionMs,
      Value<int> lastPlayedAt,
      Value<bool> isPlayed,
      Value<String?> localAudioPath,
      Value<String?> transcriptJson,
      Value<String?> transcriptLanguage,
      Value<String> transcriptStatus,
      Value<String?> transcriptError,
      Value<int> transcriptProgressMs,
      Value<String?> sourceTranscriptUrl,
      Value<int> rowid,
    });
typedef $$PodcastEpisodesTableUpdateCompanionBuilder =
    PodcastEpisodesCompanion Function({
      Value<String> id,
      Value<String> showId,
      Value<String> guid,
      Value<String> title,
      Value<String> description,
      Value<String> audioUrl,
      Value<String?> imageUrl,
      Value<int> publishedAt,
      Value<int> durationMs,
      Value<int> playbackPositionMs,
      Value<int> lastPlayedAt,
      Value<bool> isPlayed,
      Value<String?> localAudioPath,
      Value<String?> transcriptJson,
      Value<String?> transcriptLanguage,
      Value<String> transcriptStatus,
      Value<String?> transcriptError,
      Value<int> transcriptProgressMs,
      Value<String?> sourceTranscriptUrl,
      Value<int> rowid,
    });

class $$PodcastEpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get showId => $composableBuilder(
    column: $table.showId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playbackPositionMs => $composableBuilder(
    column: $table.playbackPositionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlayed => $composableBuilder(
    column: $table.isPlayed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localAudioPath => $composableBuilder(
    column: $table.localAudioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptStatus => $composableBuilder(
    column: $table.transcriptStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcriptError => $composableBuilder(
    column: $table.transcriptError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transcriptProgressMs => $composableBuilder(
    column: $table.transcriptProgressMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTranscriptUrl => $composableBuilder(
    column: $table.sourceTranscriptUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PodcastEpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get showId => $composableBuilder(
    column: $table.showId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playbackPositionMs => $composableBuilder(
    column: $table.playbackPositionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlayed => $composableBuilder(
    column: $table.isPlayed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localAudioPath => $composableBuilder(
    column: $table.localAudioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptStatus => $composableBuilder(
    column: $table.transcriptStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcriptError => $composableBuilder(
    column: $table.transcriptError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transcriptProgressMs => $composableBuilder(
    column: $table.transcriptProgressMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTranscriptUrl => $composableBuilder(
    column: $table.sourceTranscriptUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PodcastEpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get showId =>
      $composableBuilder(column: $table.showId, builder: (column) => column);

  GeneratedColumn<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playbackPositionMs => $composableBuilder(
    column: $table.playbackPositionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPlayed =>
      $composableBuilder(column: $table.isPlayed, builder: (column) => column);

  GeneratedColumn<String> get localAudioPath => $composableBuilder(
    column: $table.localAudioPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptJson => $composableBuilder(
    column: $table.transcriptJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptLanguage => $composableBuilder(
    column: $table.transcriptLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptStatus => $composableBuilder(
    column: $table.transcriptStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcriptError => $composableBuilder(
    column: $table.transcriptError,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transcriptProgressMs => $composableBuilder(
    column: $table.transcriptProgressMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTranscriptUrl => $composableBuilder(
    column: $table.sourceTranscriptUrl,
    builder: (column) => column,
  );
}

class $$PodcastEpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PodcastEpisodesTable,
          PodcastEpisode,
          $$PodcastEpisodesTableFilterComposer,
          $$PodcastEpisodesTableOrderingComposer,
          $$PodcastEpisodesTableAnnotationComposer,
          $$PodcastEpisodesTableCreateCompanionBuilder,
          $$PodcastEpisodesTableUpdateCompanionBuilder,
          (
            PodcastEpisode,
            BaseReferences<
              _$AppDatabase,
              $PodcastEpisodesTable,
              PodcastEpisode
            >,
          ),
          PodcastEpisode,
          PrefetchHooks Function()
        > {
  $$PodcastEpisodesTableTableManager(
    _$AppDatabase db,
    $PodcastEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PodcastEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PodcastEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> showId = const Value.absent(),
                Value<String> guid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> audioUrl = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int> publishedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> playbackPositionMs = const Value.absent(),
                Value<int> lastPlayedAt = const Value.absent(),
                Value<bool> isPlayed = const Value.absent(),
                Value<String?> localAudioPath = const Value.absent(),
                Value<String?> transcriptJson = const Value.absent(),
                Value<String?> transcriptLanguage = const Value.absent(),
                Value<String> transcriptStatus = const Value.absent(),
                Value<String?> transcriptError = const Value.absent(),
                Value<int> transcriptProgressMs = const Value.absent(),
                Value<String?> sourceTranscriptUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PodcastEpisodesCompanion(
                id: id,
                showId: showId,
                guid: guid,
                title: title,
                description: description,
                audioUrl: audioUrl,
                imageUrl: imageUrl,
                publishedAt: publishedAt,
                durationMs: durationMs,
                playbackPositionMs: playbackPositionMs,
                lastPlayedAt: lastPlayedAt,
                isPlayed: isPlayed,
                localAudioPath: localAudioPath,
                transcriptJson: transcriptJson,
                transcriptLanguage: transcriptLanguage,
                transcriptStatus: transcriptStatus,
                transcriptError: transcriptError,
                transcriptProgressMs: transcriptProgressMs,
                sourceTranscriptUrl: sourceTranscriptUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String showId,
                required String guid,
                required String title,
                Value<String> description = const Value.absent(),
                required String audioUrl,
                Value<String?> imageUrl = const Value.absent(),
                Value<int> publishedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> playbackPositionMs = const Value.absent(),
                Value<int> lastPlayedAt = const Value.absent(),
                Value<bool> isPlayed = const Value.absent(),
                Value<String?> localAudioPath = const Value.absent(),
                Value<String?> transcriptJson = const Value.absent(),
                Value<String?> transcriptLanguage = const Value.absent(),
                Value<String> transcriptStatus = const Value.absent(),
                Value<String?> transcriptError = const Value.absent(),
                Value<int> transcriptProgressMs = const Value.absent(),
                Value<String?> sourceTranscriptUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PodcastEpisodesCompanion.insert(
                id: id,
                showId: showId,
                guid: guid,
                title: title,
                description: description,
                audioUrl: audioUrl,
                imageUrl: imageUrl,
                publishedAt: publishedAt,
                durationMs: durationMs,
                playbackPositionMs: playbackPositionMs,
                lastPlayedAt: lastPlayedAt,
                isPlayed: isPlayed,
                localAudioPath: localAudioPath,
                transcriptJson: transcriptJson,
                transcriptLanguage: transcriptLanguage,
                transcriptStatus: transcriptStatus,
                transcriptError: transcriptError,
                transcriptProgressMs: transcriptProgressMs,
                sourceTranscriptUrl: sourceTranscriptUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PodcastEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PodcastEpisodesTable,
      PodcastEpisode,
      $$PodcastEpisodesTableFilterComposer,
      $$PodcastEpisodesTableOrderingComposer,
      $$PodcastEpisodesTableAnnotationComposer,
      $$PodcastEpisodesTableCreateCompanionBuilder,
      $$PodcastEpisodesTableUpdateCompanionBuilder,
      (
        PodcastEpisode,
        BaseReferences<_$AppDatabase, $PodcastEpisodesTable, PodcastEpisode>,
      ),
      PodcastEpisode,
      PrefetchHooks Function()
    >;
typedef $$AiThreadsTableCreateCompanionBuilder =
    AiThreadsCompanion Function({
      required String id,
      required String scopeType,
      required String scopeId,
      required String scopeParentId,
      required String contentFingerprint,
      Value<String?> summaryText,
      Value<String?> remoteConversationId,
      Value<String?> lastResponseId,
      Value<String?> modelId,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AiThreadsTableUpdateCompanionBuilder =
    AiThreadsCompanion Function({
      Value<String> id,
      Value<String> scopeType,
      Value<String> scopeId,
      Value<String> scopeParentId,
      Value<String> contentFingerprint,
      Value<String?> summaryText,
      Value<String?> remoteConversationId,
      Value<String?> lastResponseId,
      Value<String?> modelId,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AiThreadsTableFilterComposer
    extends Composer<_$AppDatabase, $AiThreadsTable> {
  $$AiThreadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeType => $composableBuilder(
    column: $table.scopeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeParentId => $composableBuilder(
    column: $table.scopeParentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentFingerprint => $composableBuilder(
    column: $table.contentFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteConversationId => $composableBuilder(
    column: $table.remoteConversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastResponseId => $composableBuilder(
    column: $table.lastResponseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiThreadsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiThreadsTable> {
  $$AiThreadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeType => $composableBuilder(
    column: $table.scopeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeParentId => $composableBuilder(
    column: $table.scopeParentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentFingerprint => $composableBuilder(
    column: $table.contentFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteConversationId => $composableBuilder(
    column: $table.remoteConversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastResponseId => $composableBuilder(
    column: $table.lastResponseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiThreadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiThreadsTable> {
  $$AiThreadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scopeType =>
      $composableBuilder(column: $table.scopeType, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get scopeParentId => $composableBuilder(
    column: $table.scopeParentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentFingerprint => $composableBuilder(
    column: $table.contentFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summaryText => $composableBuilder(
    column: $table.summaryText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteConversationId => $composableBuilder(
    column: $table.remoteConversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastResponseId => $composableBuilder(
    column: $table.lastResponseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiThreadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiThreadsTable,
          AiThread,
          $$AiThreadsTableFilterComposer,
          $$AiThreadsTableOrderingComposer,
          $$AiThreadsTableAnnotationComposer,
          $$AiThreadsTableCreateCompanionBuilder,
          $$AiThreadsTableUpdateCompanionBuilder,
          (AiThread, BaseReferences<_$AppDatabase, $AiThreadsTable, AiThread>),
          AiThread,
          PrefetchHooks Function()
        > {
  $$AiThreadsTableTableManager(_$AppDatabase db, $AiThreadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiThreadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiThreadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiThreadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scopeType = const Value.absent(),
                Value<String> scopeId = const Value.absent(),
                Value<String> scopeParentId = const Value.absent(),
                Value<String> contentFingerprint = const Value.absent(),
                Value<String?> summaryText = const Value.absent(),
                Value<String?> remoteConversationId = const Value.absent(),
                Value<String?> lastResponseId = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiThreadsCompanion(
                id: id,
                scopeType: scopeType,
                scopeId: scopeId,
                scopeParentId: scopeParentId,
                contentFingerprint: contentFingerprint,
                summaryText: summaryText,
                remoteConversationId: remoteConversationId,
                lastResponseId: lastResponseId,
                modelId: modelId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scopeType,
                required String scopeId,
                required String scopeParentId,
                required String contentFingerprint,
                Value<String?> summaryText = const Value.absent(),
                Value<String?> remoteConversationId = const Value.absent(),
                Value<String?> lastResponseId = const Value.absent(),
                Value<String?> modelId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AiThreadsCompanion.insert(
                id: id,
                scopeType: scopeType,
                scopeId: scopeId,
                scopeParentId: scopeParentId,
                contentFingerprint: contentFingerprint,
                summaryText: summaryText,
                remoteConversationId: remoteConversationId,
                lastResponseId: lastResponseId,
                modelId: modelId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiThreadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiThreadsTable,
      AiThread,
      $$AiThreadsTableFilterComposer,
      $$AiThreadsTableOrderingComposer,
      $$AiThreadsTableAnnotationComposer,
      $$AiThreadsTableCreateCompanionBuilder,
      $$AiThreadsTableUpdateCompanionBuilder,
      (AiThread, BaseReferences<_$AppDatabase, $AiThreadsTable, AiThread>),
      AiThread,
      PrefetchHooks Function()
    >;
typedef $$AiMessagesTableCreateCompanionBuilder =
    AiMessagesCompanion Function({
      required String id,
      required String threadId,
      required String role,
      Value<String> kind,
      required String content,
      Value<String?> citationsJson,
      Value<String?> responseId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$AiMessagesTableUpdateCompanionBuilder =
    AiMessagesCompanion Function({
      Value<String> id,
      Value<String> threadId,
      Value<String> role,
      Value<String> kind,
      Value<String> content,
      Value<String?> citationsJson,
      Value<String?> responseId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$AiMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get citationsJson => $composableBuilder(
    column: $table.citationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get citationsJson => $composableBuilder(
    column: $table.citationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get citationsJson => $composableBuilder(
    column: $table.citationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get responseId => $composableBuilder(
    column: $table.responseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AiMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiMessagesTable,
          AiMessage,
          $$AiMessagesTableFilterComposer,
          $$AiMessagesTableOrderingComposer,
          $$AiMessagesTableAnnotationComposer,
          $$AiMessagesTableCreateCompanionBuilder,
          $$AiMessagesTableUpdateCompanionBuilder,
          (
            AiMessage,
            BaseReferences<_$AppDatabase, $AiMessagesTable, AiMessage>,
          ),
          AiMessage,
          PrefetchHooks Function()
        > {
  $$AiMessagesTableTableManager(_$AppDatabase db, $AiMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> threadId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> citationsJson = const Value.absent(),
                Value<String?> responseId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiMessagesCompanion(
                id: id,
                threadId: threadId,
                role: role,
                kind: kind,
                content: content,
                citationsJson: citationsJson,
                responseId: responseId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String threadId,
                required String role,
                Value<String> kind = const Value.absent(),
                required String content,
                Value<String?> citationsJson = const Value.absent(),
                Value<String?> responseId = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AiMessagesCompanion.insert(
                id: id,
                threadId: threadId,
                role: role,
                kind: kind,
                content: content,
                citationsJson: citationsJson,
                responseId: responseId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiMessagesTable,
      AiMessage,
      $$AiMessagesTableFilterComposer,
      $$AiMessagesTableOrderingComposer,
      $$AiMessagesTableAnnotationComposer,
      $$AiMessagesTableCreateCompanionBuilder,
      $$AiMessagesTableUpdateCompanionBuilder,
      (AiMessage, BaseReferences<_$AppDatabase, $AiMessagesTable, AiMessage>),
      AiMessage,
      PrefetchHooks Function()
    >;
typedef $$GenerationTasksTableCreateCompanionBuilder =
    GenerationTasksCompanion Function({
      required String id,
      required String kind,
      required String parentId,
      required String scopeId,
      required String contentFingerprint,
      required String configFingerprint,
      Value<String> configJson,
      Value<String> status,
      Value<int> priority,
      required int createdAt,
      required int updatedAt,
      Value<int?> startedAt,
      Value<int?> completedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$GenerationTasksTableUpdateCompanionBuilder =
    GenerationTasksCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> parentId,
      Value<String> scopeId,
      Value<String> contentFingerprint,
      Value<String> configFingerprint,
      Value<String> configJson,
      Value<String> status,
      Value<int> priority,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> startedAt,
      Value<int?> completedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$GenerationTasksTableFilterComposer
    extends Composer<_$AppDatabase, $GenerationTasksTable> {
  $$GenerationTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentFingerprint => $composableBuilder(
    column: $table.contentFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configFingerprint => $composableBuilder(
    column: $table.configFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GenerationTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $GenerationTasksTable> {
  $$GenerationTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentFingerprint => $composableBuilder(
    column: $table.contentFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configFingerprint => $composableBuilder(
    column: $table.configFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GenerationTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $GenerationTasksTable> {
  $$GenerationTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get contentFingerprint => $composableBuilder(
    column: $table.contentFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configFingerprint => $composableBuilder(
    column: $table.configFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$GenerationTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GenerationTasksTable,
          GenerationTask,
          $$GenerationTasksTableFilterComposer,
          $$GenerationTasksTableOrderingComposer,
          $$GenerationTasksTableAnnotationComposer,
          $$GenerationTasksTableCreateCompanionBuilder,
          $$GenerationTasksTableUpdateCompanionBuilder,
          (
            GenerationTask,
            BaseReferences<
              _$AppDatabase,
              $GenerationTasksTable,
              GenerationTask
            >,
          ),
          GenerationTask,
          PrefetchHooks Function()
        > {
  $$GenerationTasksTableTableManager(
    _$AppDatabase db,
    $GenerationTasksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GenerationTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GenerationTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GenerationTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> parentId = const Value.absent(),
                Value<String> scopeId = const Value.absent(),
                Value<String> contentFingerprint = const Value.absent(),
                Value<String> configFingerprint = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenerationTasksCompanion(
                id: id,
                kind: kind,
                parentId: parentId,
                scopeId: scopeId,
                contentFingerprint: contentFingerprint,
                configFingerprint: configFingerprint,
                configJson: configJson,
                status: status,
                priority: priority,
                createdAt: createdAt,
                updatedAt: updatedAt,
                startedAt: startedAt,
                completedAt: completedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String parentId,
                required String scopeId,
                required String contentFingerprint,
                required String configFingerprint,
                Value<String> configJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> priority = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> startedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenerationTasksCompanion.insert(
                id: id,
                kind: kind,
                parentId: parentId,
                scopeId: scopeId,
                contentFingerprint: contentFingerprint,
                configFingerprint: configFingerprint,
                configJson: configJson,
                status: status,
                priority: priority,
                createdAt: createdAt,
                updatedAt: updatedAt,
                startedAt: startedAt,
                completedAt: completedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GenerationTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GenerationTasksTable,
      GenerationTask,
      $$GenerationTasksTableFilterComposer,
      $$GenerationTasksTableOrderingComposer,
      $$GenerationTasksTableAnnotationComposer,
      $$GenerationTasksTableCreateCompanionBuilder,
      $$GenerationTasksTableUpdateCompanionBuilder,
      (
        GenerationTask,
        BaseReferences<_$AppDatabase, $GenerationTasksTable, GenerationTask>,
      ),
      GenerationTask,
      PrefetchHooks Function()
    >;
typedef $$GenerationTaskChunksTableCreateCompanionBuilder =
    GenerationTaskChunksCompanion Function({
      required String id,
      required String taskId,
      required int chunkIndex,
      required String sourceKey,
      Value<int> startMs,
      Value<int> endMs,
      required String inputFingerprint,
      Value<String> status,
      Value<int> attempts,
      Value<int> priority,
      Value<String?> resultRef,
      Value<String?> resultJson,
      Value<String?> error,
      required int updatedAt,
      Value<int?> startedAt,
      Value<int?> completedAt,
      Value<int> rowid,
    });
typedef $$GenerationTaskChunksTableUpdateCompanionBuilder =
    GenerationTaskChunksCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<int> chunkIndex,
      Value<String> sourceKey,
      Value<int> startMs,
      Value<int> endMs,
      Value<String> inputFingerprint,
      Value<String> status,
      Value<int> attempts,
      Value<int> priority,
      Value<String?> resultRef,
      Value<String?> resultJson,
      Value<String?> error,
      Value<int> updatedAt,
      Value<int?> startedAt,
      Value<int?> completedAt,
      Value<int> rowid,
    });

class $$GenerationTaskChunksTableFilterComposer
    extends Composer<_$AppDatabase, $GenerationTaskChunksTable> {
  $$GenerationTaskChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputFingerprint => $composableBuilder(
    column: $table.inputFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultRef => $composableBuilder(
    column: $table.resultRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GenerationTaskChunksTableOrderingComposer
    extends Composer<_$AppDatabase, $GenerationTaskChunksTable> {
  $$GenerationTaskChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputFingerprint => $composableBuilder(
    column: $table.inputFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultRef => $composableBuilder(
    column: $table.resultRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GenerationTaskChunksTableAnnotationComposer
    extends Composer<_$AppDatabase, $GenerationTaskChunksTable> {
  $$GenerationTaskChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get inputFingerprint => $composableBuilder(
    column: $table.inputFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get resultRef =>
      $composableBuilder(column: $table.resultRef, builder: (column) => column);

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$GenerationTaskChunksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GenerationTaskChunksTable,
          GenerationTaskChunk,
          $$GenerationTaskChunksTableFilterComposer,
          $$GenerationTaskChunksTableOrderingComposer,
          $$GenerationTaskChunksTableAnnotationComposer,
          $$GenerationTaskChunksTableCreateCompanionBuilder,
          $$GenerationTaskChunksTableUpdateCompanionBuilder,
          (
            GenerationTaskChunk,
            BaseReferences<
              _$AppDatabase,
              $GenerationTaskChunksTable,
              GenerationTaskChunk
            >,
          ),
          GenerationTaskChunk,
          PrefetchHooks Function()
        > {
  $$GenerationTaskChunksTableTableManager(
    _$AppDatabase db,
    $GenerationTaskChunksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GenerationTaskChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GenerationTaskChunksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GenerationTaskChunksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<int> chunkIndex = const Value.absent(),
                Value<String> sourceKey = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String> inputFingerprint = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> resultRef = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenerationTaskChunksCompanion(
                id: id,
                taskId: taskId,
                chunkIndex: chunkIndex,
                sourceKey: sourceKey,
                startMs: startMs,
                endMs: endMs,
                inputFingerprint: inputFingerprint,
                status: status,
                attempts: attempts,
                priority: priority,
                resultRef: resultRef,
                resultJson: resultJson,
                error: error,
                updatedAt: updatedAt,
                startedAt: startedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required int chunkIndex,
                required String sourceKey,
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                required String inputFingerprint,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> resultRef = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required int updatedAt,
                Value<int?> startedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenerationTaskChunksCompanion.insert(
                id: id,
                taskId: taskId,
                chunkIndex: chunkIndex,
                sourceKey: sourceKey,
                startMs: startMs,
                endMs: endMs,
                inputFingerprint: inputFingerprint,
                status: status,
                attempts: attempts,
                priority: priority,
                resultRef: resultRef,
                resultJson: resultJson,
                error: error,
                updatedAt: updatedAt,
                startedAt: startedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GenerationTaskChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GenerationTaskChunksTable,
      GenerationTaskChunk,
      $$GenerationTaskChunksTableFilterComposer,
      $$GenerationTaskChunksTableOrderingComposer,
      $$GenerationTaskChunksTableAnnotationComposer,
      $$GenerationTaskChunksTableCreateCompanionBuilder,
      $$GenerationTaskChunksTableUpdateCompanionBuilder,
      (
        GenerationTaskChunk,
        BaseReferences<
          _$AppDatabase,
          $GenerationTaskChunksTable,
          GenerationTaskChunk
        >,
      ),
      GenerationTaskChunk,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$ChapterPlaybackProgressesTableTableManager get chapterPlaybackProgresses =>
      $$ChapterPlaybackProgressesTableTableManager(
        _db,
        _db.chapterPlaybackProgresses,
      );
  $$ParagraphsTableTableManager get paragraphs =>
      $$ParagraphsTableTableManager(_db, _db.paragraphs);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$VoicesTableTableManager get voices =>
      $$VoicesTableTableManager(_db, _db.voices);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$CostRecordsTableTableManager get costRecords =>
      $$CostRecordsTableTableManager(_db, _db.costRecords);
  $$ListeningDaysTableTableManager get listeningDays =>
      $$ListeningDaysTableTableManager(_db, _db.listeningDays);
  $$DictionaryEntriesTableTableManager get dictionaryEntries =>
      $$DictionaryEntriesTableTableManager(_db, _db.dictionaryEntries);
  $$FavoriteWordsTableTableManager get favoriteWords =>
      $$FavoriteWordsTableTableManager(_db, _db.favoriteWords);
  $$PodcastShowsTableTableManager get podcastShows =>
      $$PodcastShowsTableTableManager(_db, _db.podcastShows);
  $$PodcastEpisodesTableTableManager get podcastEpisodes =>
      $$PodcastEpisodesTableTableManager(_db, _db.podcastEpisodes);
  $$AiThreadsTableTableManager get aiThreads =>
      $$AiThreadsTableTableManager(_db, _db.aiThreads);
  $$AiMessagesTableTableManager get aiMessages =>
      $$AiMessagesTableTableManager(_db, _db.aiMessages);
  $$GenerationTasksTableTableManager get generationTasks =>
      $$GenerationTasksTableTableManager(_db, _db.generationTasks);
  $$GenerationTaskChunksTableTableManager get generationTaskChunks =>
      $$GenerationTaskChunksTableTableManager(_db, _db.generationTaskChunks);
}
