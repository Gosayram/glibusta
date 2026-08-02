// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SavedBooksTable extends SavedBooks with TableInfo<$SavedBooksTable, SavedBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedBooksTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> authorIds =
      GeneratedColumn<String>(
        'author_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($SavedBooksTable.$converterauthorIds);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> genreIds =
      GeneratedColumn<String>(
        'genre_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($SavedBooksTable.$convertergenreIds);
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
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _coverStatusMeta = const VerificationMeta(
    'coverStatus',
  );
  @override
  late final GeneratedColumn<String> coverStatus = GeneratedColumn<String>(
    'cover_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _publishDateMeta = const VerificationMeta(
    'publishDate',
  );
  @override
  late final GeneratedColumn<DateTime> publishDate = GeneratedColumn<DateTime>(
    'publish_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _readingStatusMeta = const VerificationMeta(
    'readingStatus',
  );
  @override
  late final GeneratedColumn<String> readingStatus = GeneratedColumn<String>(
    'reading_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _detectedEncodingMeta = const VerificationMeta(
    'detectedEncoding',
  );
  @override
  late final GeneratedColumn<String> detectedEncoding = GeneratedColumn<String>(
    'detected_encoding',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encodingConfidenceMeta = const VerificationMeta(
    'encodingConfidence',
  );
  @override
  late final GeneratedColumn<double> encodingConfidence = GeneratedColumn<double>(
    'encoding_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encodingSourceMeta = const VerificationMeta(
    'encodingSource',
  );
  @override
  late final GeneratedColumn<String> encodingSource = GeneratedColumn<String>(
    'encoding_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userForcedEncodingMeta = const VerificationMeta(
    'userForcedEncoding',
  );
  @override
  late final GeneratedColumn<String> userForcedEncoding = GeneratedColumn<String>(
    'user_forced_encoding',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storageModeMeta = const VerificationMeta(
    'storageMode',
  );
  @override
  late final GeneratedColumn<String> storageMode = GeneratedColumn<String>(
    'storage_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('internal'),
  );
  static const VerificationMeta _externalUriMeta = const VerificationMeta(
    'externalUri',
  );
  @override
  late final GeneratedColumn<String> externalUri = GeneratedColumn<String>(
    'external_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    authorIds,
    genreIds,
    description,
    coverUrl,
    coverPath,
    coverStatus,
    publishDate,
    sourceId,
    sourceUrl,
    addedAt,
    contentHash,
    fileSize,
    filePath,
    readingStatus,
    detectedEncoding,
    encodingConfidence,
    encodingSource,
    userForcedEncoding,
    storageMode,
    externalUri,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedBook> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('cover_status')) {
      context.handle(
        _coverStatusMeta,
        coverStatus.isAcceptableOrUnknown(
          data['cover_status']!,
          _coverStatusMeta,
        ),
      );
    }
    if (data.containsKey('publish_date')) {
      context.handle(
        _publishDateMeta,
        publishDate.isAcceptableOrUnknown(
          data['publish_date']!,
          _publishDateMeta,
        ),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('reading_status')) {
      context.handle(
        _readingStatusMeta,
        readingStatus.isAcceptableOrUnknown(
          data['reading_status']!,
          _readingStatusMeta,
        ),
      );
    }
    if (data.containsKey('detected_encoding')) {
      context.handle(
        _detectedEncodingMeta,
        detectedEncoding.isAcceptableOrUnknown(
          data['detected_encoding']!,
          _detectedEncodingMeta,
        ),
      );
    }
    if (data.containsKey('encoding_confidence')) {
      context.handle(
        _encodingConfidenceMeta,
        encodingConfidence.isAcceptableOrUnknown(
          data['encoding_confidence']!,
          _encodingConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('encoding_source')) {
      context.handle(
        _encodingSourceMeta,
        encodingSource.isAcceptableOrUnknown(
          data['encoding_source']!,
          _encodingSourceMeta,
        ),
      );
    }
    if (data.containsKey('user_forced_encoding')) {
      context.handle(
        _userForcedEncodingMeta,
        userForcedEncoding.isAcceptableOrUnknown(
          data['user_forced_encoding']!,
          _userForcedEncodingMeta,
        ),
      );
    }
    if (data.containsKey('storage_mode')) {
      context.handle(
        _storageModeMeta,
        storageMode.isAcceptableOrUnknown(
          data['storage_mode']!,
          _storageModeMeta,
        ),
      );
    }
    if (data.containsKey('external_uri')) {
      context.handle(
        _externalUriMeta,
        externalUri.isAcceptableOrUnknown(
          data['external_uri']!,
          _externalUriMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedBook(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      authorIds: $SavedBooksTable.$converterauthorIds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}author_ids'],
        )!,
      ),
      genreIds: $SavedBooksTable.$convertergenreIds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}genre_ids'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      coverStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_status'],
      )!,
      publishDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}publish_date'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      readingStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_status'],
      )!,
      detectedEncoding: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detected_encoding'],
      ),
      encodingConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}encoding_confidence'],
      ),
      encodingSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encoding_source'],
      ),
      userForcedEncoding: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_forced_encoding'],
      ),
      storageMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_mode'],
      )!,
      externalUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_uri'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SavedBooksTable createAlias(String alias) {
    return $SavedBooksTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterauthorIds = const StringListConverter();
  static TypeConverter<List<String>, String> $convertergenreIds = const StringListConverter();
}

class SavedBook extends DataClass implements Insertable<SavedBook> {
  final String id;
  final String title;
  final List<String> authorIds;
  final List<String> genreIds;
  final String? description;
  final String? coverUrl;
  final String? coverPath;
  final String coverStatus;
  final DateTime? publishDate;
  final String? sourceId;
  final String? sourceUrl;
  final DateTime addedAt;
  final String? contentHash;
  final int? fileSize;
  final String filePath;
  final String readingStatus;
  final String? detectedEncoding;
  final double? encodingConfidence;
  final String? encodingSource;
  final String? userForcedEncoding;
  final String storageMode;
  final String? externalUri;
  final DateTime? deletedAt;
  const SavedBook({
    required this.id,
    required this.title,
    required this.authorIds,
    required this.genreIds,
    this.description,
    this.coverUrl,
    this.coverPath,
    required this.coverStatus,
    this.publishDate,
    this.sourceId,
    this.sourceUrl,
    required this.addedAt,
    this.contentHash,
    this.fileSize,
    required this.filePath,
    required this.readingStatus,
    this.detectedEncoding,
    this.encodingConfidence,
    this.encodingSource,
    this.userForcedEncoding,
    required this.storageMode,
    this.externalUri,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['author_ids'] = Variable<String>(
        $SavedBooksTable.$converterauthorIds.toSql(authorIds),
      );
    }
    {
      map['genre_ids'] = Variable<String>(
        $SavedBooksTable.$convertergenreIds.toSql(genreIds),
      );
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['cover_status'] = Variable<String>(coverStatus);
    if (!nullToAbsent || publishDate != null) {
      map['publish_date'] = Variable<DateTime>(publishDate);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    map['file_path'] = Variable<String>(filePath);
    map['reading_status'] = Variable<String>(readingStatus);
    if (!nullToAbsent || detectedEncoding != null) {
      map['detected_encoding'] = Variable<String>(detectedEncoding);
    }
    if (!nullToAbsent || encodingConfidence != null) {
      map['encoding_confidence'] = Variable<double>(encodingConfidence);
    }
    if (!nullToAbsent || encodingSource != null) {
      map['encoding_source'] = Variable<String>(encodingSource);
    }
    if (!nullToAbsent || userForcedEncoding != null) {
      map['user_forced_encoding'] = Variable<String>(userForcedEncoding);
    }
    map['storage_mode'] = Variable<String>(storageMode);
    if (!nullToAbsent || externalUri != null) {
      map['external_uri'] = Variable<String>(externalUri);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SavedBooksCompanion toCompanion(bool nullToAbsent) {
    return SavedBooksCompanion(
      id: Value(id),
      title: Value(title),
      authorIds: Value(authorIds),
      genreIds: Value(genreIds),
      description: description == null && nullToAbsent ? const Value.absent() : Value(description),
      coverUrl: coverUrl == null && nullToAbsent ? const Value.absent() : Value(coverUrl),
      coverPath: coverPath == null && nullToAbsent ? const Value.absent() : Value(coverPath),
      coverStatus: Value(coverStatus),
      publishDate: publishDate == null && nullToAbsent ? const Value.absent() : Value(publishDate),
      sourceId: sourceId == null && nullToAbsent ? const Value.absent() : Value(sourceId),
      sourceUrl: sourceUrl == null && nullToAbsent ? const Value.absent() : Value(sourceUrl),
      addedAt: Value(addedAt),
      contentHash: contentHash == null && nullToAbsent ? const Value.absent() : Value(contentHash),
      fileSize: fileSize == null && nullToAbsent ? const Value.absent() : Value(fileSize),
      filePath: Value(filePath),
      readingStatus: Value(readingStatus),
      detectedEncoding: detectedEncoding == null && nullToAbsent
          ? const Value.absent()
          : Value(detectedEncoding),
      encodingConfidence: encodingConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(encodingConfidence),
      encodingSource: encodingSource == null && nullToAbsent
          ? const Value.absent()
          : Value(encodingSource),
      userForcedEncoding: userForcedEncoding == null && nullToAbsent
          ? const Value.absent()
          : Value(userForcedEncoding),
      storageMode: Value(storageMode),
      externalUri: externalUri == null && nullToAbsent ? const Value.absent() : Value(externalUri),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
    );
  }

  factory SavedBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedBook(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      authorIds: serializer.fromJson<List<String>>(json['authorIds']),
      genreIds: serializer.fromJson<List<String>>(json['genreIds']),
      description: serializer.fromJson<String?>(json['description']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      coverStatus: serializer.fromJson<String>(json['coverStatus']),
      publishDate: serializer.fromJson<DateTime?>(json['publishDate']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      filePath: serializer.fromJson<String>(json['filePath']),
      readingStatus: serializer.fromJson<String>(json['readingStatus']),
      detectedEncoding: serializer.fromJson<String?>(json['detectedEncoding']),
      encodingConfidence: serializer.fromJson<double?>(
        json['encodingConfidence'],
      ),
      encodingSource: serializer.fromJson<String?>(json['encodingSource']),
      userForcedEncoding: serializer.fromJson<String?>(
        json['userForcedEncoding'],
      ),
      storageMode: serializer.fromJson<String>(json['storageMode']),
      externalUri: serializer.fromJson<String?>(json['externalUri']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'authorIds': serializer.toJson<List<String>>(authorIds),
      'genreIds': serializer.toJson<List<String>>(genreIds),
      'description': serializer.toJson<String?>(description),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'coverPath': serializer.toJson<String?>(coverPath),
      'coverStatus': serializer.toJson<String>(coverStatus),
      'publishDate': serializer.toJson<DateTime?>(publishDate),
      'sourceId': serializer.toJson<String?>(sourceId),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'contentHash': serializer.toJson<String?>(contentHash),
      'fileSize': serializer.toJson<int?>(fileSize),
      'filePath': serializer.toJson<String>(filePath),
      'readingStatus': serializer.toJson<String>(readingStatus),
      'detectedEncoding': serializer.toJson<String?>(detectedEncoding),
      'encodingConfidence': serializer.toJson<double?>(encodingConfidence),
      'encodingSource': serializer.toJson<String?>(encodingSource),
      'userForcedEncoding': serializer.toJson<String?>(userForcedEncoding),
      'storageMode': serializer.toJson<String>(storageMode),
      'externalUri': serializer.toJson<String?>(externalUri),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SavedBook copyWith({
    String? id,
    String? title,
    List<String>? authorIds,
    List<String>? genreIds,
    Value<String?> description = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    String? coverStatus,
    Value<DateTime?> publishDate = const Value.absent(),
    Value<String?> sourceId = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
    DateTime? addedAt,
    Value<String?> contentHash = const Value.absent(),
    Value<int?> fileSize = const Value.absent(),
    String? filePath,
    String? readingStatus,
    Value<String?> detectedEncoding = const Value.absent(),
    Value<double?> encodingConfidence = const Value.absent(),
    Value<String?> encodingSource = const Value.absent(),
    Value<String?> userForcedEncoding = const Value.absent(),
    String? storageMode,
    Value<String?> externalUri = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => SavedBook(
    id: id ?? this.id,
    title: title ?? this.title,
    authorIds: authorIds ?? this.authorIds,
    genreIds: genreIds ?? this.genreIds,
    description: description.present ? description.value : this.description,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    coverStatus: coverStatus ?? this.coverStatus,
    publishDate: publishDate.present ? publishDate.value : this.publishDate,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    addedAt: addedAt ?? this.addedAt,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    filePath: filePath ?? this.filePath,
    readingStatus: readingStatus ?? this.readingStatus,
    detectedEncoding: detectedEncoding.present ? detectedEncoding.value : this.detectedEncoding,
    encodingConfidence: encodingConfidence.present
        ? encodingConfidence.value
        : this.encodingConfidence,
    encodingSource: encodingSource.present ? encodingSource.value : this.encodingSource,
    userForcedEncoding: userForcedEncoding.present
        ? userForcedEncoding.value
        : this.userForcedEncoding,
    storageMode: storageMode ?? this.storageMode,
    externalUri: externalUri.present ? externalUri.value : this.externalUri,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  SavedBook copyWithCompanion(SavedBooksCompanion data) {
    return SavedBook(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      authorIds: data.authorIds.present ? data.authorIds.value : this.authorIds,
      genreIds: data.genreIds.present ? data.genreIds.value : this.genreIds,
      description: data.description.present ? data.description.value : this.description,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      coverStatus: data.coverStatus.present ? data.coverStatus.value : this.coverStatus,
      publishDate: data.publishDate.present ? data.publishDate.value : this.publishDate,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      contentHash: data.contentHash.present ? data.contentHash.value : this.contentHash,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      readingStatus: data.readingStatus.present ? data.readingStatus.value : this.readingStatus,
      detectedEncoding: data.detectedEncoding.present
          ? data.detectedEncoding.value
          : this.detectedEncoding,
      encodingConfidence: data.encodingConfidence.present
          ? data.encodingConfidence.value
          : this.encodingConfidence,
      encodingSource: data.encodingSource.present ? data.encodingSource.value : this.encodingSource,
      userForcedEncoding: data.userForcedEncoding.present
          ? data.userForcedEncoding.value
          : this.userForcedEncoding,
      storageMode: data.storageMode.present ? data.storageMode.value : this.storageMode,
      externalUri: data.externalUri.present ? data.externalUri.value : this.externalUri,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedBook(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('authorIds: $authorIds, ')
          ..write('genreIds: $genreIds, ')
          ..write('description: $description, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverStatus: $coverStatus, ')
          ..write('publishDate: $publishDate, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('addedAt: $addedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('fileSize: $fileSize, ')
          ..write('filePath: $filePath, ')
          ..write('readingStatus: $readingStatus, ')
          ..write('detectedEncoding: $detectedEncoding, ')
          ..write('encodingConfidence: $encodingConfidence, ')
          ..write('encodingSource: $encodingSource, ')
          ..write('userForcedEncoding: $userForcedEncoding, ')
          ..write('storageMode: $storageMode, ')
          ..write('externalUri: $externalUri, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    authorIds,
    genreIds,
    description,
    coverUrl,
    coverPath,
    coverStatus,
    publishDate,
    sourceId,
    sourceUrl,
    addedAt,
    contentHash,
    fileSize,
    filePath,
    readingStatus,
    detectedEncoding,
    encodingConfidence,
    encodingSource,
    userForcedEncoding,
    storageMode,
    externalUri,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedBook &&
          other.id == this.id &&
          other.title == this.title &&
          other.authorIds == this.authorIds &&
          other.genreIds == this.genreIds &&
          other.description == this.description &&
          other.coverUrl == this.coverUrl &&
          other.coverPath == this.coverPath &&
          other.coverStatus == this.coverStatus &&
          other.publishDate == this.publishDate &&
          other.sourceId == this.sourceId &&
          other.sourceUrl == this.sourceUrl &&
          other.addedAt == this.addedAt &&
          other.contentHash == this.contentHash &&
          other.fileSize == this.fileSize &&
          other.filePath == this.filePath &&
          other.readingStatus == this.readingStatus &&
          other.detectedEncoding == this.detectedEncoding &&
          other.encodingConfidence == this.encodingConfidence &&
          other.encodingSource == this.encodingSource &&
          other.userForcedEncoding == this.userForcedEncoding &&
          other.storageMode == this.storageMode &&
          other.externalUri == this.externalUri &&
          other.deletedAt == this.deletedAt);
}

class SavedBooksCompanion extends UpdateCompanion<SavedBook> {
  final Value<String> id;
  final Value<String> title;
  final Value<List<String>> authorIds;
  final Value<List<String>> genreIds;
  final Value<String?> description;
  final Value<String?> coverUrl;
  final Value<String?> coverPath;
  final Value<String> coverStatus;
  final Value<DateTime?> publishDate;
  final Value<String?> sourceId;
  final Value<String?> sourceUrl;
  final Value<DateTime> addedAt;
  final Value<String?> contentHash;
  final Value<int?> fileSize;
  final Value<String> filePath;
  final Value<String> readingStatus;
  final Value<String?> detectedEncoding;
  final Value<double?> encodingConfidence;
  final Value<String?> encodingSource;
  final Value<String?> userForcedEncoding;
  final Value<String> storageMode;
  final Value<String?> externalUri;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SavedBooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.authorIds = const Value.absent(),
    this.genreIds = const Value.absent(),
    this.description = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverStatus = const Value.absent(),
    this.publishDate = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.filePath = const Value.absent(),
    this.readingStatus = const Value.absent(),
    this.detectedEncoding = const Value.absent(),
    this.encodingConfidence = const Value.absent(),
    this.encodingSource = const Value.absent(),
    this.userForcedEncoding = const Value.absent(),
    this.storageMode = const Value.absent(),
    this.externalUri = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedBooksCompanion.insert({
    required String id,
    required String title,
    this.authorIds = const Value.absent(),
    this.genreIds = const Value.absent(),
    this.description = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.coverStatus = const Value.absent(),
    this.publishDate = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.filePath = const Value.absent(),
    this.readingStatus = const Value.absent(),
    this.detectedEncoding = const Value.absent(),
    this.encodingConfidence = const Value.absent(),
    this.encodingSource = const Value.absent(),
    this.userForcedEncoding = const Value.absent(),
    this.storageMode = const Value.absent(),
    this.externalUri = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title);
  static Insertable<SavedBook> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? authorIds,
    Expression<String>? genreIds,
    Expression<String>? description,
    Expression<String>? coverUrl,
    Expression<String>? coverPath,
    Expression<String>? coverStatus,
    Expression<DateTime>? publishDate,
    Expression<String>? sourceId,
    Expression<String>? sourceUrl,
    Expression<DateTime>? addedAt,
    Expression<String>? contentHash,
    Expression<int>? fileSize,
    Expression<String>? filePath,
    Expression<String>? readingStatus,
    Expression<String>? detectedEncoding,
    Expression<double>? encodingConfidence,
    Expression<String>? encodingSource,
    Expression<String>? userForcedEncoding,
    Expression<String>? storageMode,
    Expression<String>? externalUri,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (authorIds != null) 'author_ids': authorIds,
      if (genreIds != null) 'genre_ids': genreIds,
      if (description != null) 'description': description,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (coverPath != null) 'cover_path': coverPath,
      if (coverStatus != null) 'cover_status': coverStatus,
      if (publishDate != null) 'publish_date': publishDate,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (addedAt != null) 'added_at': addedAt,
      if (contentHash != null) 'content_hash': contentHash,
      if (fileSize != null) 'file_size': fileSize,
      if (filePath != null) 'file_path': filePath,
      if (readingStatus != null) 'reading_status': readingStatus,
      if (detectedEncoding != null) 'detected_encoding': detectedEncoding,
      if (encodingConfidence != null) 'encoding_confidence': encodingConfidence,
      if (encodingSource != null) 'encoding_source': encodingSource,
      if (userForcedEncoding != null) 'user_forced_encoding': userForcedEncoding,
      if (storageMode != null) 'storage_mode': storageMode,
      if (externalUri != null) 'external_uri': externalUri,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedBooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<List<String>>? authorIds,
    Value<List<String>>? genreIds,
    Value<String?>? description,
    Value<String?>? coverUrl,
    Value<String?>? coverPath,
    Value<String>? coverStatus,
    Value<DateTime?>? publishDate,
    Value<String?>? sourceId,
    Value<String?>? sourceUrl,
    Value<DateTime>? addedAt,
    Value<String?>? contentHash,
    Value<int?>? fileSize,
    Value<String>? filePath,
    Value<String>? readingStatus,
    Value<String?>? detectedEncoding,
    Value<double?>? encodingConfidence,
    Value<String?>? encodingSource,
    Value<String?>? userForcedEncoding,
    Value<String>? storageMode,
    Value<String?>? externalUri,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SavedBooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      authorIds: authorIds ?? this.authorIds,
      genreIds: genreIds ?? this.genreIds,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath: coverPath ?? this.coverPath,
      coverStatus: coverStatus ?? this.coverStatus,
      publishDate: publishDate ?? this.publishDate,
      sourceId: sourceId ?? this.sourceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      addedAt: addedAt ?? this.addedAt,
      contentHash: contentHash ?? this.contentHash,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      readingStatus: readingStatus ?? this.readingStatus,
      detectedEncoding: detectedEncoding ?? this.detectedEncoding,
      encodingConfidence: encodingConfidence ?? this.encodingConfidence,
      encodingSource: encodingSource ?? this.encodingSource,
      userForcedEncoding: userForcedEncoding ?? this.userForcedEncoding,
      storageMode: storageMode ?? this.storageMode,
      externalUri: externalUri ?? this.externalUri,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (authorIds.present) {
      map['author_ids'] = Variable<String>(
        $SavedBooksTable.$converterauthorIds.toSql(authorIds.value),
      );
    }
    if (genreIds.present) {
      map['genre_ids'] = Variable<String>(
        $SavedBooksTable.$convertergenreIds.toSql(genreIds.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (coverStatus.present) {
      map['cover_status'] = Variable<String>(coverStatus.value);
    }
    if (publishDate.present) {
      map['publish_date'] = Variable<DateTime>(publishDate.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (readingStatus.present) {
      map['reading_status'] = Variable<String>(readingStatus.value);
    }
    if (detectedEncoding.present) {
      map['detected_encoding'] = Variable<String>(detectedEncoding.value);
    }
    if (encodingConfidence.present) {
      map['encoding_confidence'] = Variable<double>(encodingConfidence.value);
    }
    if (encodingSource.present) {
      map['encoding_source'] = Variable<String>(encodingSource.value);
    }
    if (userForcedEncoding.present) {
      map['user_forced_encoding'] = Variable<String>(userForcedEncoding.value);
    }
    if (storageMode.present) {
      map['storage_mode'] = Variable<String>(storageMode.value);
    }
    if (externalUri.present) {
      map['external_uri'] = Variable<String>(externalUri.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedBooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('authorIds: $authorIds, ')
          ..write('genreIds: $genreIds, ')
          ..write('description: $description, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('coverPath: $coverPath, ')
          ..write('coverStatus: $coverStatus, ')
          ..write('publishDate: $publishDate, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('addedAt: $addedAt, ')
          ..write('contentHash: $contentHash, ')
          ..write('fileSize: $fileSize, ')
          ..write('filePath: $filePath, ')
          ..write('readingStatus: $readingStatus, ')
          ..write('detectedEncoding: $detectedEncoding, ')
          ..write('encodingConfidence: $encodingConfidence, ')
          ..write('encodingSource: $encodingSource, ')
          ..write('userForcedEncoding: $userForcedEncoding, ')
          ..write('storageMode: $storageMode, ')
          ..write('externalUri: $externalUri, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuthorsTable extends Authors with TableInfo<$AuthorsTable, Author> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuthorsTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> bookIds =
      GeneratedColumn<String>(
        'book_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($AuthorsTable.$converterbookIds);
  @override
  List<GeneratedColumn> get $columns => [id, name, bookIds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'authors';
  @override
  VerificationContext validateIntegrity(
    Insertable<Author> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Author map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Author(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      bookIds: $AuthorsTable.$converterbookIds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}book_ids'],
        )!,
      ),
    );
  }

  @override
  $AuthorsTable createAlias(String alias) {
    return $AuthorsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterbookIds = const StringListConverter();
}

class Author extends DataClass implements Insertable<Author> {
  final String id;
  final String name;
  final List<String> bookIds;
  const Author({required this.id, required this.name, required this.bookIds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['book_ids'] = Variable<String>(
        $AuthorsTable.$converterbookIds.toSql(bookIds),
      );
    }
    return map;
  }

  AuthorsCompanion toCompanion(bool nullToAbsent) {
    return AuthorsCompanion(
      id: Value(id),
      name: Value(name),
      bookIds: Value(bookIds),
    );
  }

  factory Author.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Author(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      bookIds: serializer.fromJson<List<String>>(json['bookIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'bookIds': serializer.toJson<List<String>>(bookIds),
    };
  }

  Author copyWith({String? id, String? name, List<String>? bookIds}) => Author(
    id: id ?? this.id,
    name: name ?? this.name,
    bookIds: bookIds ?? this.bookIds,
  );
  Author copyWithCompanion(AuthorsCompanion data) {
    return Author(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      bookIds: data.bookIds.present ? data.bookIds.value : this.bookIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Author(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bookIds: $bookIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, bookIds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Author &&
          other.id == this.id &&
          other.name == this.name &&
          other.bookIds == this.bookIds);
}

class AuthorsCompanion extends UpdateCompanion<Author> {
  final Value<String> id;
  final Value<String> name;
  final Value<List<String>> bookIds;
  final Value<int> rowid;
  const AuthorsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.bookIds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuthorsCompanion.insert({
    required String id,
    required String name,
    this.bookIds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Author> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? bookIds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (bookIds != null) 'book_ids': bookIds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuthorsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<List<String>>? bookIds,
    Value<int>? rowid,
  }) {
    return AuthorsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      bookIds: bookIds ?? this.bookIds,
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
    if (bookIds.present) {
      map['book_ids'] = Variable<String>(
        $AuthorsTable.$converterbookIds.toSql(bookIds.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuthorsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('bookIds: $bookIds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesTable extends Series with TableInfo<$SeriesTable, Sery> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> bookIds =
      GeneratedColumn<String>(
        'book_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($SeriesTable.$converterbookIds);
  @override
  List<GeneratedColumn> get $columns => [id, name, description, bookIds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sery> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sery map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sery(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      bookIds: $SeriesTable.$converterbookIds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}book_ids'],
        )!,
      ),
    );
  }

  @override
  $SeriesTable createAlias(String alias) {
    return $SeriesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterbookIds = const StringListConverter();
}

class Sery extends DataClass implements Insertable<Sery> {
  final String id;
  final String name;
  final String? description;
  final List<String> bookIds;
  const Sery({
    required this.id,
    required this.name,
    this.description,
    required this.bookIds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['book_ids'] = Variable<String>(
        $SeriesTable.$converterbookIds.toSql(bookIds),
      );
    }
    return map;
  }

  SeriesCompanion toCompanion(bool nullToAbsent) {
    return SeriesCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent ? const Value.absent() : Value(description),
      bookIds: Value(bookIds),
    );
  }

  factory Sery.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sery(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      bookIds: serializer.fromJson<List<String>>(json['bookIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'bookIds': serializer.toJson<List<String>>(bookIds),
    };
  }

  Sery copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    List<String>? bookIds,
  }) => Sery(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    bookIds: bookIds ?? this.bookIds,
  );
  Sery copyWithCompanion(SeriesCompanion data) {
    return Sery(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present ? data.description.value : this.description,
      bookIds: data.bookIds.present ? data.bookIds.value : this.bookIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sery(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('bookIds: $bookIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, bookIds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sery &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.bookIds == this.bookIds);
}

class SeriesCompanion extends UpdateCompanion<Sery> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<List<String>> bookIds;
  final Value<int> rowid;
  const SeriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.bookIds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.bookIds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Sery> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? bookIds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (bookIds != null) 'book_ids': bookIds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<List<String>>? bookIds,
    Value<int>? rowid,
  }) {
    return SeriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      bookIds: bookIds ?? this.bookIds,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (bookIds.present) {
      map['book_ids'] = Variable<String>(
        $SeriesTable.$converterbookIds.toSql(bookIds.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('bookIds: $bookIds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookSeriesTable extends BookSeries with TableInfo<$BookSeriesTable, BookSery> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookSeriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceNumberMeta = const VerificationMeta(
    'sequenceNumber',
  );
  @override
  late final GeneratedColumn<int> sequenceNumber = GeneratedColumn<int>(
    'sequence_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, seriesId, sequenceNumber];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_series';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookSery> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('sequence_number')) {
      context.handle(
        _sequenceNumberMeta,
        sequenceNumber.isAcceptableOrUnknown(
          data['sequence_number']!,
          _sequenceNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, seriesId};
  @override
  BookSery map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookSery(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      sequenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_number'],
      ),
    );
  }

  @override
  $BookSeriesTable createAlias(String alias) {
    return $BookSeriesTable(attachedDatabase, alias);
  }
}

class BookSery extends DataClass implements Insertable<BookSery> {
  final String bookId;
  final String seriesId;
  final int? sequenceNumber;
  const BookSery({
    required this.bookId,
    required this.seriesId,
    this.sequenceNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['series_id'] = Variable<String>(seriesId);
    if (!nullToAbsent || sequenceNumber != null) {
      map['sequence_number'] = Variable<int>(sequenceNumber);
    }
    return map;
  }

  BookSeriesCompanion toCompanion(bool nullToAbsent) {
    return BookSeriesCompanion(
      bookId: Value(bookId),
      seriesId: Value(seriesId),
      sequenceNumber: sequenceNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(sequenceNumber),
    );
  }

  factory BookSery.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookSery(
      bookId: serializer.fromJson<String>(json['bookId']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      sequenceNumber: serializer.fromJson<int?>(json['sequenceNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'seriesId': serializer.toJson<String>(seriesId),
      'sequenceNumber': serializer.toJson<int?>(sequenceNumber),
    };
  }

  BookSery copyWith({
    String? bookId,
    String? seriesId,
    Value<int?> sequenceNumber = const Value.absent(),
  }) => BookSery(
    bookId: bookId ?? this.bookId,
    seriesId: seriesId ?? this.seriesId,
    sequenceNumber: sequenceNumber.present ? sequenceNumber.value : this.sequenceNumber,
  );
  BookSery copyWithCompanion(BookSeriesCompanion data) {
    return BookSery(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      sequenceNumber: data.sequenceNumber.present ? data.sequenceNumber.value : this.sequenceNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookSery(')
          ..write('bookId: $bookId, ')
          ..write('seriesId: $seriesId, ')
          ..write('sequenceNumber: $sequenceNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, seriesId, sequenceNumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookSery &&
          other.bookId == this.bookId &&
          other.seriesId == this.seriesId &&
          other.sequenceNumber == this.sequenceNumber);
}

class BookSeriesCompanion extends UpdateCompanion<BookSery> {
  final Value<String> bookId;
  final Value<String> seriesId;
  final Value<int?> sequenceNumber;
  final Value<int> rowid;
  const BookSeriesCompanion({
    this.bookId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookSeriesCompanion.insert({
    required String bookId,
    required String seriesId,
    this.sequenceNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       seriesId = Value(seriesId);
  static Insertable<BookSery> custom({
    Expression<String>? bookId,
    Expression<String>? seriesId,
    Expression<int>? sequenceNumber,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (seriesId != null) 'series_id': seriesId,
      if (sequenceNumber != null) 'sequence_number': sequenceNumber,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookSeriesCompanion copyWith({
    Value<String>? bookId,
    Value<String>? seriesId,
    Value<int?>? sequenceNumber,
    Value<int>? rowid,
  }) {
    return BookSeriesCompanion(
      bookId: bookId ?? this.bookId,
      seriesId: seriesId ?? this.seriesId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (sequenceNumber.present) {
      map['sequence_number'] = Variable<int>(sequenceNumber.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookSeriesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('seriesId: $seriesId, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GenresTable extends Genres with TableInfo<$GenresTable, Genre> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GenresTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, parentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'genres';
  @override
  VerificationContext validateIntegrity(
    Insertable<Genre> instance, {
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Genre map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Genre(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $GenresTable createAlias(String alias) {
    return $GenresTable(attachedDatabase, alias);
  }
}

class Genre extends DataClass implements Insertable<Genre> {
  final String id;
  final String name;
  final String? parentId;
  const Genre({required this.id, required this.name, this.parentId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    return map;
  }

  GenresCompanion toCompanion(bool nullToAbsent) {
    return GenresCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent ? const Value.absent() : Value(parentId),
    );
  }

  factory Genre.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Genre(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
    };
  }

  Genre copyWith({
    String? id,
    String? name,
    Value<String?> parentId = const Value.absent(),
  }) => Genre(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  Genre copyWithCompanion(GenresCompanion data) {
    return Genre(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Genre(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, parentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Genre &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId);
}

class GenresCompanion extends UpdateCompanion<Genre> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<int> rowid;
  const GenresCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GenresCompanion.insert({
    required String id,
    required String name,
    this.parentId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Genre> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GenresCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? parentId,
    Value<int>? rowid,
  }) {
    return GenresCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
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
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GenresCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bookTitleMeta = const VerificationMeta(
    'bookTitle',
  );
  @override
  late final GeneratedColumn<String> bookTitle = GeneratedColumn<String>(
    'book_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _targetPathMeta = const VerificationMeta(
    'targetPath',
  );
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
    'target_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStatusDb, int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<DownloadStatusDb>($DownloadsTable.$converterstatus);
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
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
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    bookTitle,
    format,
    sourceUrl,
    targetPath,
    status,
    downloadedBytes,
    totalBytes,
    createdAt,
    startedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Download> instance, {
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
    if (data.containsKey('book_title')) {
      context.handle(
        _bookTitleMeta,
        bookTitle.isAcceptableOrUnknown(data['book_title']!, _bookTitleMeta),
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
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('target_path')) {
      context.handle(
        _targetPathMeta,
        targetPath.isAcceptableOrUnknown(data['target_path']!, _targetPathMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
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
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      bookTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_title'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      targetPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_path'],
      ),
      status: $DownloadsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadStatusDb, int, int> $converterstatus =
      const EnumIndexConverter<DownloadStatusDb>(DownloadStatusDb.values);
}

class Download extends DataClass implements Insertable<Download> {
  final String id;
  final String bookId;
  final String bookTitle;
  final String format;
  final String sourceUrl;
  final String? targetPath;
  final DownloadStatusDb status;
  final int downloadedBytes;
  final int totalBytes;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  const Download({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.format,
    required this.sourceUrl,
    this.targetPath,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['book_title'] = Variable<String>(bookTitle);
    map['format'] = Variable<String>(format);
    map['source_url'] = Variable<String>(sourceUrl);
    if (!nullToAbsent || targetPath != null) {
      map['target_path'] = Variable<String>(targetPath);
    }
    {
      map['status'] = Variable<int>(
        $DownloadsTable.$converterstatus.toSql(status),
      );
    }
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['total_bytes'] = Variable<int>(totalBytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      bookTitle: Value(bookTitle),
      format: Value(format),
      sourceUrl: Value(sourceUrl),
      targetPath: targetPath == null && nullToAbsent ? const Value.absent() : Value(targetPath),
      status: Value(status),
      downloadedBytes: Value(downloadedBytes),
      totalBytes: Value(totalBytes),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent ? const Value.absent() : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent ? const Value.absent() : Value(completedAt),
    );
  }

  factory Download.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      bookTitle: serializer.fromJson<String>(json['bookTitle']),
      format: serializer.fromJson<String>(json['format']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      targetPath: serializer.fromJson<String?>(json['targetPath']),
      status: $DownloadsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'bookTitle': serializer.toJson<String>(bookTitle),
      'format': serializer.toJson<String>(format),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'targetPath': serializer.toJson<String?>(targetPath),
      'status': serializer.toJson<int>(
        $DownloadsTable.$converterstatus.toJson(status),
      ),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Download copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    String? format,
    String? sourceUrl,
    Value<String?> targetPath = const Value.absent(),
    DownloadStatusDb? status,
    int? downloadedBytes,
    int? totalBytes,
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
  }) => Download(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    bookTitle: bookTitle ?? this.bookTitle,
    format: format ?? this.format,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    targetPath: targetPath.present ? targetPath.value : this.targetPath,
    status: status ?? this.status,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      bookTitle: data.bookTitle.present ? data.bookTitle.value : this.bookTitle,
      format: data.format.present ? data.format.value : this.format,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      targetPath: data.targetPath.present ? data.targetPath.value : this.targetPath,
      status: data.status.present ? data.status.value : this.status,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      totalBytes: data.totalBytes.present ? data.totalBytes.value : this.totalBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('format: $format, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('targetPath: $targetPath, ')
          ..write('status: $status, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    bookTitle,
    format,
    sourceUrl,
    targetPath,
    status,
    downloadedBytes,
    totalBytes,
    createdAt,
    startedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.bookTitle == this.bookTitle &&
          other.format == this.format &&
          other.sourceUrl == this.sourceUrl &&
          other.targetPath == this.targetPath &&
          other.status == this.status &&
          other.downloadedBytes == this.downloadedBytes &&
          other.totalBytes == this.totalBytes &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> bookTitle;
  final Value<String> format;
  final Value<String> sourceUrl;
  final Value<String?> targetPath;
  final Value<DownloadStatusDb> status;
  final Value<int> downloadedBytes;
  final Value<int> totalBytes;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.bookTitle = const Value.absent(),
    this.format = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.status = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String id,
    required String bookId,
    this.bookTitle = const Value.absent(),
    required String format,
    required String sourceUrl,
    this.targetPath = const Value.absent(),
    required DownloadStatusDb status,
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       format = Value(format),
       sourceUrl = Value(sourceUrl),
       status = Value(status);
  static Insertable<Download> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? bookTitle,
    Expression<String>? format,
    Expression<String>? sourceUrl,
    Expression<String>? targetPath,
    Expression<int>? status,
    Expression<int>? downloadedBytes,
    Expression<int>? totalBytes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (bookTitle != null) 'book_title': bookTitle,
      if (format != null) 'format': format,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (targetPath != null) 'target_path': targetPath,
      if (status != null) 'status': status,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? bookTitle,
    Value<String>? format,
    Value<String>? sourceUrl,
    Value<String?>? targetPath,
    Value<DownloadStatusDb>? status,
    Value<int>? downloadedBytes,
    Value<int>? totalBytes,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      format: format ?? this.format,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      targetPath: targetPath ?? this.targetPath,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt ?? this.createdAt,
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
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (bookTitle.present) {
      map['book_title'] = Variable<String>(bookTitle.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $DownloadsTable.$converterstatus.toSql(status.value),
      );
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('format: $format, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('targetPath: $targetPath, ')
          ..write('status: $status, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentPositionMeta = const VerificationMeta(
    'currentPosition',
  );
  @override
  late final GeneratedColumn<int> currentPosition = GeneratedColumn<int>(
    'current_position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _localOffsetMeta = const VerificationMeta(
    'localOffset',
  );
  @override
  late final GeneratedColumn<double> localOffset = GeneratedColumn<double>(
    'local_offset',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _progressPercentMeta = const VerificationMeta(
    'progressPercent',
  );
  @override
  late final GeneratedColumn<double> progressPercent = GeneratedColumn<double>(
    'progress_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _totalPagesMeta = const VerificationMeta(
    'totalPages',
  );
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
    'total_pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReadMeta = const VerificationMeta(
    'lastRead',
  );
  @override
  late final GeneratedColumn<DateTime> lastRead = GeneratedColumn<DateTime>(
    'last_read',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    currentPosition,
    chapterIndex,
    paragraphIndex,
    localOffset,
    progressPercent,
    chapterId,
    textOffset,
    totalPages,
    lastRead,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('current_position')) {
      context.handle(
        _currentPositionMeta,
        currentPosition.isAcceptableOrUnknown(
          data['current_position']!,
          _currentPositionMeta,
        ),
      );
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
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
    if (data.containsKey('local_offset')) {
      context.handle(
        _localOffsetMeta,
        localOffset.isAcceptableOrUnknown(
          data['local_offset']!,
          _localOffsetMeta,
        ),
      );
    }
    if (data.containsKey('progress_percent')) {
      context.handle(
        _progressPercentMeta,
        progressPercent.isAcceptableOrUnknown(
          data['progress_percent']!,
          _progressPercentMeta,
        ),
      );
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    }
    if (data.containsKey('text_offset')) {
      context.handle(
        _textOffsetMeta,
        textOffset.isAcceptableOrUnknown(data['text_offset']!, _textOffsetMeta),
      );
    }
    if (data.containsKey('total_pages')) {
      context.handle(
        _totalPagesMeta,
        totalPages.isAcceptableOrUnknown(data['total_pages']!, _totalPagesMeta),
      );
    }
    if (data.containsKey('last_read')) {
      context.handle(
        _lastReadMeta,
        lastRead.isAcceptableOrUnknown(data['last_read']!, _lastReadMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressData(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      currentPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_position'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      localOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}local_offset'],
      )!,
      progressPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_percent'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      textOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}text_offset'],
      )!,
      totalPages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_pages'],
      )!,
      lastRead: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressData extends DataClass implements Insertable<ReadingProgressData> {
  final String bookId;
  final int currentPosition;
  final int chapterIndex;
  final int paragraphIndex;
  final double localOffset;
  final double progressPercent;
  final String chapterId;
  final int textOffset;
  final int totalPages;
  final DateTime lastRead;
  final DateTime updatedAt;
  const ReadingProgressData({
    required this.bookId,
    required this.currentPosition,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.localOffset,
    required this.progressPercent,
    required this.chapterId,
    required this.textOffset,
    required this.totalPages,
    required this.lastRead,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['current_position'] = Variable<int>(currentPosition);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['local_offset'] = Variable<double>(localOffset);
    map['progress_percent'] = Variable<double>(progressPercent);
    map['chapter_id'] = Variable<String>(chapterId);
    map['text_offset'] = Variable<int>(textOffset);
    map['total_pages'] = Variable<int>(totalPages);
    map['last_read'] = Variable<DateTime>(lastRead);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      bookId: Value(bookId),
      currentPosition: Value(currentPosition),
      chapterIndex: Value(chapterIndex),
      paragraphIndex: Value(paragraphIndex),
      localOffset: Value(localOffset),
      progressPercent: Value(progressPercent),
      chapterId: Value(chapterId),
      textOffset: Value(textOffset),
      totalPages: Value(totalPages),
      lastRead: Value(lastRead),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressData(
      bookId: serializer.fromJson<String>(json['bookId']),
      currentPosition: serializer.fromJson<int>(json['currentPosition']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      localOffset: serializer.fromJson<double>(json['localOffset']),
      progressPercent: serializer.fromJson<double>(json['progressPercent']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      textOffset: serializer.fromJson<int>(json['textOffset']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      lastRead: serializer.fromJson<DateTime>(json['lastRead']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'currentPosition': serializer.toJson<int>(currentPosition),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'localOffset': serializer.toJson<double>(localOffset),
      'progressPercent': serializer.toJson<double>(progressPercent),
      'chapterId': serializer.toJson<String>(chapterId),
      'textOffset': serializer.toJson<int>(textOffset),
      'totalPages': serializer.toJson<int>(totalPages),
      'lastRead': serializer.toJson<DateTime>(lastRead),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressData copyWith({
    String? bookId,
    int? currentPosition,
    int? chapterIndex,
    int? paragraphIndex,
    double? localOffset,
    double? progressPercent,
    String? chapterId,
    int? textOffset,
    int? totalPages,
    DateTime? lastRead,
    DateTime? updatedAt,
  }) => ReadingProgressData(
    bookId: bookId ?? this.bookId,
    currentPosition: currentPosition ?? this.currentPosition,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    localOffset: localOffset ?? this.localOffset,
    progressPercent: progressPercent ?? this.progressPercent,
    chapterId: chapterId ?? this.chapterId,
    textOffset: textOffset ?? this.textOffset,
    totalPages: totalPages ?? this.totalPages,
    lastRead: lastRead ?? this.lastRead,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressData copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      currentPosition: data.currentPosition.present
          ? data.currentPosition.value
          : this.currentPosition,
      chapterIndex: data.chapterIndex.present ? data.chapterIndex.value : this.chapterIndex,
      paragraphIndex: data.paragraphIndex.present ? data.paragraphIndex.value : this.paragraphIndex,
      localOffset: data.localOffset.present ? data.localOffset.value : this.localOffset,
      progressPercent: data.progressPercent.present
          ? data.progressPercent.value
          : this.progressPercent,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      textOffset: data.textOffset.present ? data.textOffset.value : this.textOffset,
      totalPages: data.totalPages.present ? data.totalPages.value : this.totalPages,
      lastRead: data.lastRead.present ? data.lastRead.value : this.lastRead,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressData(')
          ..write('bookId: $bookId, ')
          ..write('currentPosition: $currentPosition, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('localOffset: $localOffset, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('chapterId: $chapterId, ')
          ..write('textOffset: $textOffset, ')
          ..write('totalPages: $totalPages, ')
          ..write('lastRead: $lastRead, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    currentPosition,
    chapterIndex,
    paragraphIndex,
    localOffset,
    progressPercent,
    chapterId,
    textOffset,
    totalPages,
    lastRead,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressData &&
          other.bookId == this.bookId &&
          other.currentPosition == this.currentPosition &&
          other.chapterIndex == this.chapterIndex &&
          other.paragraphIndex == this.paragraphIndex &&
          other.localOffset == this.localOffset &&
          other.progressPercent == this.progressPercent &&
          other.chapterId == this.chapterId &&
          other.textOffset == this.textOffset &&
          other.totalPages == this.totalPages &&
          other.lastRead == this.lastRead &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressData> {
  final Value<String> bookId;
  final Value<int> currentPosition;
  final Value<int> chapterIndex;
  final Value<int> paragraphIndex;
  final Value<double> localOffset;
  final Value<double> progressPercent;
  final Value<String> chapterId;
  final Value<int> textOffset;
  final Value<int> totalPages;
  final Value<DateTime> lastRead;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingProgressCompanion({
    this.bookId = const Value.absent(),
    this.currentPosition = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.localOffset = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.textOffset = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.lastRead = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    required String bookId,
    this.currentPosition = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.localOffset = const Value.absent(),
    this.progressPercent = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.textOffset = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.lastRead = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId);
  static Insertable<ReadingProgressData> custom({
    Expression<String>? bookId,
    Expression<int>? currentPosition,
    Expression<int>? chapterIndex,
    Expression<int>? paragraphIndex,
    Expression<double>? localOffset,
    Expression<double>? progressPercent,
    Expression<String>? chapterId,
    Expression<int>? textOffset,
    Expression<int>? totalPages,
    Expression<DateTime>? lastRead,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (currentPosition != null) 'current_position': currentPosition,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (localOffset != null) 'local_offset': localOffset,
      if (progressPercent != null) 'progress_percent': progressPercent,
      if (chapterId != null) 'chapter_id': chapterId,
      if (textOffset != null) 'text_offset': textOffset,
      if (totalPages != null) 'total_pages': totalPages,
      if (lastRead != null) 'last_read': lastRead,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<String>? bookId,
    Value<int>? currentPosition,
    Value<int>? chapterIndex,
    Value<int>? paragraphIndex,
    Value<double>? localOffset,
    Value<double>? progressPercent,
    Value<String>? chapterId,
    Value<int>? textOffset,
    Value<int>? totalPages,
    Value<DateTime>? lastRead,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReadingProgressCompanion(
      bookId: bookId ?? this.bookId,
      currentPosition: currentPosition ?? this.currentPosition,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      localOffset: localOffset ?? this.localOffset,
      progressPercent: progressPercent ?? this.progressPercent,
      chapterId: chapterId ?? this.chapterId,
      textOffset: textOffset ?? this.textOffset,
      totalPages: totalPages ?? this.totalPages,
      lastRead: lastRead ?? this.lastRead,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (currentPosition.present) {
      map['current_position'] = Variable<int>(currentPosition.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (localOffset.present) {
      map['local_offset'] = Variable<double>(localOffset.value);
    }
    if (progressPercent.present) {
      map['progress_percent'] = Variable<double>(progressPercent.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (textOffset.present) {
      map['text_offset'] = Variable<int>(textOffset.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (lastRead.present) {
      map['last_read'] = Variable<DateTime>(lastRead.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('bookId: $bookId, ')
          ..write('currentPosition: $currentPosition, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('localOffset: $localOffset, ')
          ..write('progressPercent: $progressPercent, ')
          ..write('chapterId: $chapterId, ')
          ..write('textOffset: $textOffset, ')
          ..write('totalPages: $totalPages, ')
          ..write('lastRead: $lastRead, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks with TableInfo<$BookmarksTable, Bookmark> {
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
  static const VerificationMeta _localOffsetMeta = const VerificationMeta(
    'localOffset',
  );
  @override
  late final GeneratedColumn<double> localOffset = GeneratedColumn<double>(
    'local_offset',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _selectedTextMeta = const VerificationMeta(
    'selectedText',
  );
  @override
  late final GeneratedColumn<String> selectedText = GeneratedColumn<String>(
    'selected_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _highlightStyleMeta = const VerificationMeta(
    'highlightStyle',
  );
  @override
  late final GeneratedColumn<String> highlightStyle = GeneratedColumn<String>(
    'highlight_style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highlightColorMeta = const VerificationMeta(
    'highlightColor',
  );
  @override
  late final GeneratedColumn<String> highlightColor = GeneratedColumn<String>(
    'highlight_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    paragraphIndex,
    localOffset,
    selectedText,
    note,
    highlightStyle,
    highlightColor,
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
    if (data.containsKey('local_offset')) {
      context.handle(
        _localOffsetMeta,
        localOffset.isAcceptableOrUnknown(
          data['local_offset']!,
          _localOffsetMeta,
        ),
      );
    }
    if (data.containsKey('selected_text')) {
      context.handle(
        _selectedTextMeta,
        selectedText.isAcceptableOrUnknown(
          data['selected_text']!,
          _selectedTextMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('highlight_style')) {
      context.handle(
        _highlightStyleMeta,
        highlightStyle.isAcceptableOrUnknown(
          data['highlight_style']!,
          _highlightStyleMeta,
        ),
      );
    }
    if (data.containsKey('highlight_color')) {
      context.handle(
        _highlightColorMeta,
        highlightColor.isAcceptableOrUnknown(
          data['highlight_color']!,
          _highlightColorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
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
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      localOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}local_offset'],
      )!,
      selectedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_text'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      highlightStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}highlight_style'],
      ),
      highlightColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}highlight_color'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
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
  final int chapterIndex;
  final int paragraphIndex;
  final double localOffset;
  final String? selectedText;
  final String? note;
  final String? highlightStyle;
  final String? highlightColor;
  final DateTime createdAt;
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.localOffset,
    this.selectedText,
    this.note,
    this.highlightStyle,
    this.highlightColor,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['local_offset'] = Variable<double>(localOffset);
    if (!nullToAbsent || selectedText != null) {
      map['selected_text'] = Variable<String>(selectedText);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || highlightStyle != null) {
      map['highlight_style'] = Variable<String>(highlightStyle);
    }
    if (!nullToAbsent || highlightColor != null) {
      map['highlight_color'] = Variable<String>(highlightColor);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      paragraphIndex: Value(paragraphIndex),
      localOffset: Value(localOffset),
      selectedText: selectedText == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedText),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      highlightStyle: highlightStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(highlightStyle),
      highlightColor: highlightColor == null && nullToAbsent
          ? const Value.absent()
          : Value(highlightColor),
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
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      localOffset: serializer.fromJson<double>(json['localOffset']),
      selectedText: serializer.fromJson<String?>(json['selectedText']),
      note: serializer.fromJson<String?>(json['note']),
      highlightStyle: serializer.fromJson<String?>(json['highlightStyle']),
      highlightColor: serializer.fromJson<String?>(json['highlightColor']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'localOffset': serializer.toJson<double>(localOffset),
      'selectedText': serializer.toJson<String?>(selectedText),
      'note': serializer.toJson<String?>(note),
      'highlightStyle': serializer.toJson<String?>(highlightStyle),
      'highlightColor': serializer.toJson<String?>(highlightColor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Bookmark copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    int? paragraphIndex,
    double? localOffset,
    Value<String?> selectedText = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> highlightStyle = const Value.absent(),
    Value<String?> highlightColor = const Value.absent(),
    DateTime? createdAt,
  }) => Bookmark(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    localOffset: localOffset ?? this.localOffset,
    selectedText: selectedText.present ? selectedText.value : this.selectedText,
    note: note.present ? note.value : this.note,
    highlightStyle: highlightStyle.present ? highlightStyle.value : this.highlightStyle,
    highlightColor: highlightColor.present ? highlightColor.value : this.highlightColor,
    createdAt: createdAt ?? this.createdAt,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present ? data.chapterIndex.value : this.chapterIndex,
      paragraphIndex: data.paragraphIndex.present ? data.paragraphIndex.value : this.paragraphIndex,
      localOffset: data.localOffset.present ? data.localOffset.value : this.localOffset,
      selectedText: data.selectedText.present ? data.selectedText.value : this.selectedText,
      note: data.note.present ? data.note.value : this.note,
      highlightStyle: data.highlightStyle.present ? data.highlightStyle.value : this.highlightStyle,
      highlightColor: data.highlightColor.present ? data.highlightColor.value : this.highlightColor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('localOffset: $localOffset, ')
          ..write('selectedText: $selectedText, ')
          ..write('note: $note, ')
          ..write('highlightStyle: $highlightStyle, ')
          ..write('highlightColor: $highlightColor, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    paragraphIndex,
    localOffset,
    selectedText,
    note,
    highlightStyle,
    highlightColor,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.paragraphIndex == this.paragraphIndex &&
          other.localOffset == this.localOffset &&
          other.selectedText == this.selectedText &&
          other.note == this.note &&
          other.highlightStyle == this.highlightStyle &&
          other.highlightColor == this.highlightColor &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> paragraphIndex;
  final Value<double> localOffset;
  final Value<String?> selectedText;
  final Value<String?> note;
  final Value<String?> highlightStyle;
  final Value<String?> highlightColor;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.localOffset = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.note = const Value.absent(),
    this.highlightStyle = const Value.absent(),
    this.highlightColor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String bookId,
    required int chapterIndex,
    required int paragraphIndex,
    this.localOffset = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.note = const Value.absent(),
    this.highlightStyle = const Value.absent(),
    this.highlightColor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       paragraphIndex = Value(paragraphIndex);
  static Insertable<Bookmark> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? paragraphIndex,
    Expression<double>? localOffset,
    Expression<String>? selectedText,
    Expression<String>? note,
    Expression<String>? highlightStyle,
    Expression<String>? highlightColor,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (localOffset != null) 'local_offset': localOffset,
      if (selectedText != null) 'selected_text': selectedText,
      if (note != null) 'note': note,
      if (highlightStyle != null) 'highlight_style': highlightStyle,
      if (highlightColor != null) 'highlight_color': highlightColor,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<int>? paragraphIndex,
    Value<double>? localOffset,
    Value<String?>? selectedText,
    Value<String?>? note,
    Value<String?>? highlightStyle,
    Value<String?>? highlightColor,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      localOffset: localOffset ?? this.localOffset,
      selectedText: selectedText ?? this.selectedText,
      note: note ?? this.note,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      highlightColor: highlightColor ?? this.highlightColor,
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
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (localOffset.present) {
      map['local_offset'] = Variable<double>(localOffset.value);
    }
    if (selectedText.present) {
      map['selected_text'] = Variable<String>(selectedText.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (highlightStyle.present) {
      map['highlight_style'] = Variable<String>(highlightStyle.value);
    }
    if (highlightColor.present) {
      map['highlight_color'] = Variable<String>(highlightColor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
          ..write('chapterIndex: $chapterIndex, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('localOffset: $localOffset, ')
          ..write('selectedText: $selectedText, ')
          ..write('note: $note, ')
          ..write('highlightStyle: $highlightStyle, ')
          ..write('highlightColor: $highlightColor, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _localOffsetMeta = const VerificationMeta(
    'localOffset',
  );
  @override
  late final GeneratedColumn<double> localOffset = GeneratedColumn<double>(
    'local_offset',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
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
  static const VerificationMeta _highlightColorMeta = const VerificationMeta(
    'highlightColor',
  );
  @override
  late final GeneratedColumn<String> highlightColor = GeneratedColumn<String>(
    'highlight_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#FFEB3B'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    paragraphIndex,
    localOffset,
    content,
    highlightColor,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
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
    if (data.containsKey('local_offset')) {
      context.handle(
        _localOffsetMeta,
        localOffset.isAcceptableOrUnknown(
          data['local_offset']!,
          _localOffsetMeta,
        ),
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
    if (data.containsKey('highlight_color')) {
      context.handle(
        _highlightColorMeta,
        highlightColor.isAcceptableOrUnknown(
          data['highlight_color']!,
          _highlightColorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
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
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      localOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}local_offset'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      highlightColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}highlight_color'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final double localOffset;
  final String content;
  final String highlightColor;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const Note({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.localOffset,
    required this.content,
    required this.highlightColor,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['local_offset'] = Variable<double>(localOffset);
    map['content'] = Variable<String>(content);
    map['highlight_color'] = Variable<String>(highlightColor);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      paragraphIndex: Value(paragraphIndex),
      localOffset: Value(localOffset),
      content: Value(content),
      highlightColor: Value(highlightColor),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      localOffset: serializer.fromJson<double>(json['localOffset']),
      content: serializer.fromJson<String>(json['content']),
      highlightColor: serializer.fromJson<String>(json['highlightColor']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'localOffset': serializer.toJson<double>(localOffset),
      'content': serializer.toJson<String>(content),
      'highlightColor': serializer.toJson<String>(highlightColor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Note copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    int? paragraphIndex,
    double? localOffset,
    String? content,
    String? highlightColor,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => Note(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    localOffset: localOffset ?? this.localOffset,
    content: content ?? this.content,
    highlightColor: highlightColor ?? this.highlightColor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present ? data.chapterIndex.value : this.chapterIndex,
      paragraphIndex: data.paragraphIndex.present ? data.paragraphIndex.value : this.paragraphIndex,
      localOffset: data.localOffset.present ? data.localOffset.value : this.localOffset,
      content: data.content.present ? data.content.value : this.content,
      highlightColor: data.highlightColor.present ? data.highlightColor.value : this.highlightColor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('localOffset: $localOffset, ')
          ..write('content: $content, ')
          ..write('highlightColor: $highlightColor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    paragraphIndex,
    localOffset,
    content,
    highlightColor,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.paragraphIndex == this.paragraphIndex &&
          other.localOffset == this.localOffset &&
          other.content == this.content &&
          other.highlightColor == this.highlightColor &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> paragraphIndex;
  final Value<double> localOffset;
  final Value<String> content;
  final Value<String> highlightColor;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.localOffset = const Value.absent(),
    this.content = const Value.absent(),
    this.highlightColor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String bookId,
    required int chapterIndex,
    required int paragraphIndex,
    this.localOffset = const Value.absent(),
    required String content,
    this.highlightColor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       paragraphIndex = Value(paragraphIndex),
       content = Value(content);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? paragraphIndex,
    Expression<double>? localOffset,
    Expression<String>? content,
    Expression<String>? highlightColor,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (localOffset != null) 'local_offset': localOffset,
      if (content != null) 'content': content,
      if (highlightColor != null) 'highlight_color': highlightColor,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<int>? paragraphIndex,
    Value<double>? localOffset,
    Value<String>? content,
    Value<String>? highlightColor,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      localOffset: localOffset ?? this.localOffset,
      content: content ?? this.content,
      highlightColor: highlightColor ?? this.highlightColor,
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
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (localOffset.present) {
      map['local_offset'] = Variable<double>(localOffset.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (highlightColor.present) {
      map['highlight_color'] = Variable<String>(highlightColor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('localOffset: $localOffset, ')
          ..write('content: $content, ')
          ..write('highlightColor: $highlightColor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuotesTable extends Quotes with TableInfo<$QuotesTable, Quote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuotesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _selectedTextMeta = const VerificationMeta(
    'selectedText',
  );
  @override
  late final GeneratedColumn<String> selectedText = GeneratedColumn<String>(
    'selected_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeContextMeta = const VerificationMeta(
    'beforeContext',
  );
  @override
  late final GeneratedColumn<String> beforeContext = GeneratedColumn<String>(
    'before_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterContextMeta = const VerificationMeta(
    'afterContext',
  );
  @override
  late final GeneratedColumn<String> afterContext = GeneratedColumn<String>(
    'after_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    paragraphIndex,
    selectedText,
    beforeContext,
    afterContext,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quotes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Quote> instance, {
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
    if (data.containsKey('selected_text')) {
      context.handle(
        _selectedTextMeta,
        selectedText.isAcceptableOrUnknown(
          data['selected_text']!,
          _selectedTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedTextMeta);
    }
    if (data.containsKey('before_context')) {
      context.handle(
        _beforeContextMeta,
        beforeContext.isAcceptableOrUnknown(
          data['before_context']!,
          _beforeContextMeta,
        ),
      );
    }
    if (data.containsKey('after_context')) {
      context.handle(
        _afterContextMeta,
        afterContext.isAcceptableOrUnknown(
          data['after_context']!,
          _afterContextMeta,
        ),
      );
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
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Quote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Quote(
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
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      selectedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_text'],
      )!,
      beforeContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_context'],
      ),
      afterContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_context'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $QuotesTable createAlias(String alias) {
    return $QuotesTable(attachedDatabase, alias);
  }
}

class Quote extends DataClass implements Insertable<Quote> {
  final String id;
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final String selectedText;
  final String? beforeContext;
  final String? afterContext;
  final String? note;
  final DateTime createdAt;
  const Quote({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.selectedText,
    this.beforeContext,
    this.afterContext,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['selected_text'] = Variable<String>(selectedText);
    if (!nullToAbsent || beforeContext != null) {
      map['before_context'] = Variable<String>(beforeContext);
    }
    if (!nullToAbsent || afterContext != null) {
      map['after_context'] = Variable<String>(afterContext);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QuotesCompanion toCompanion(bool nullToAbsent) {
    return QuotesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      paragraphIndex: Value(paragraphIndex),
      selectedText: Value(selectedText),
      beforeContext: beforeContext == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeContext),
      afterContext: afterContext == null && nullToAbsent
          ? const Value.absent()
          : Value(afterContext),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory Quote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Quote(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      selectedText: serializer.fromJson<String>(json['selectedText']),
      beforeContext: serializer.fromJson<String?>(json['beforeContext']),
      afterContext: serializer.fromJson<String?>(json['afterContext']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'selectedText': serializer.toJson<String>(selectedText),
      'beforeContext': serializer.toJson<String?>(beforeContext),
      'afterContext': serializer.toJson<String?>(afterContext),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Quote copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    int? paragraphIndex,
    String? selectedText,
    Value<String?> beforeContext = const Value.absent(),
    Value<String?> afterContext = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => Quote(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    selectedText: selectedText ?? this.selectedText,
    beforeContext: beforeContext.present ? beforeContext.value : this.beforeContext,
    afterContext: afterContext.present ? afterContext.value : this.afterContext,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  Quote copyWithCompanion(QuotesCompanion data) {
    return Quote(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present ? data.chapterIndex.value : this.chapterIndex,
      paragraphIndex: data.paragraphIndex.present ? data.paragraphIndex.value : this.paragraphIndex,
      selectedText: data.selectedText.present ? data.selectedText.value : this.selectedText,
      beforeContext: data.beforeContext.present ? data.beforeContext.value : this.beforeContext,
      afterContext: data.afterContext.present ? data.afterContext.value : this.afterContext,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Quote(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('selectedText: $selectedText, ')
          ..write('beforeContext: $beforeContext, ')
          ..write('afterContext: $afterContext, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    paragraphIndex,
    selectedText,
    beforeContext,
    afterContext,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Quote &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.paragraphIndex == this.paragraphIndex &&
          other.selectedText == this.selectedText &&
          other.beforeContext == this.beforeContext &&
          other.afterContext == this.afterContext &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class QuotesCompanion extends UpdateCompanion<Quote> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<int> paragraphIndex;
  final Value<String> selectedText;
  final Value<String?> beforeContext;
  final Value<String?> afterContext;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const QuotesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.beforeContext = const Value.absent(),
    this.afterContext = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuotesCompanion.insert({
    required String id,
    required String bookId,
    required int chapterIndex,
    required int paragraphIndex,
    required String selectedText,
    this.beforeContext = const Value.absent(),
    this.afterContext = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       paragraphIndex = Value(paragraphIndex),
       selectedText = Value(selectedText);
  static Insertable<Quote> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<int>? paragraphIndex,
    Expression<String>? selectedText,
    Expression<String>? beforeContext,
    Expression<String>? afterContext,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (selectedText != null) 'selected_text': selectedText,
      if (beforeContext != null) 'before_context': beforeContext,
      if (afterContext != null) 'after_context': afterContext,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuotesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<int>? paragraphIndex,
    Value<String>? selectedText,
    Value<String?>? beforeContext,
    Value<String?>? afterContext,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return QuotesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      selectedText: selectedText ?? this.selectedText,
      beforeContext: beforeContext ?? this.beforeContext,
      afterContext: afterContext ?? this.afterContext,
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
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (selectedText.present) {
      map['selected_text'] = Variable<String>(selectedText.value);
    }
    if (beforeContext.present) {
      map['before_context'] = Variable<String>(beforeContext.value);
    }
    if (afterContext.present) {
      map['after_context'] = Variable<String>(afterContext.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuotesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('selectedText: $selectedText, ')
          ..write('beforeContext: $beforeContext, ')
          ..write('afterContext: $afterContext, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTable extends SearchHistory
    with TableInfo<$SearchHistoryTable, SearchHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
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
  static const VerificationMeta _searchedAtMeta = const VerificationMeta(
    'searchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> searchedAt = GeneratedColumn<DateTime>(
    'searched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [id, query, type, searchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('searched_at')) {
      context.handle(
        _searchedAtMeta,
        searchedAt.isAcceptableOrUnknown(data['searched_at']!, _searchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      searchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}searched_at'],
      )!,
    );
  }

  @override
  $SearchHistoryTable createAlias(String alias) {
    return $SearchHistoryTable(attachedDatabase, alias);
  }
}

class SearchHistoryData extends DataClass implements Insertable<SearchHistoryData> {
  final int id;
  final String query;
  final String type;
  final DateTime searchedAt;
  const SearchHistoryData({
    required this.id,
    required this.query,
    required this.type,
    required this.searchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['query'] = Variable<String>(query);
    map['type'] = Variable<String>(type);
    map['searched_at'] = Variable<DateTime>(searchedAt);
    return map;
  }

  SearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryCompanion(
      id: Value(id),
      query: Value(query),
      type: Value(type),
      searchedAt: Value(searchedAt),
    );
  }

  factory SearchHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryData(
      id: serializer.fromJson<int>(json['id']),
      query: serializer.fromJson<String>(json['query']),
      type: serializer.fromJson<String>(json['type']),
      searchedAt: serializer.fromJson<DateTime>(json['searchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'query': serializer.toJson<String>(query),
      'type': serializer.toJson<String>(type),
      'searchedAt': serializer.toJson<DateTime>(searchedAt),
    };
  }

  SearchHistoryData copyWith({
    int? id,
    String? query,
    String? type,
    DateTime? searchedAt,
  }) => SearchHistoryData(
    id: id ?? this.id,
    query: query ?? this.query,
    type: type ?? this.type,
    searchedAt: searchedAt ?? this.searchedAt,
  );
  SearchHistoryData copyWithCompanion(SearchHistoryCompanion data) {
    return SearchHistoryData(
      id: data.id.present ? data.id.value : this.id,
      query: data.query.present ? data.query.value : this.query,
      type: data.type.present ? data.type.value : this.type,
      searchedAt: data.searchedAt.present ? data.searchedAt.value : this.searchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryData(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('type: $type, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, query, type, searchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryData &&
          other.id == this.id &&
          other.query == this.query &&
          other.type == this.type &&
          other.searchedAt == this.searchedAt);
}

class SearchHistoryCompanion extends UpdateCompanion<SearchHistoryData> {
  final Value<int> id;
  final Value<String> query;
  final Value<String> type;
  final Value<DateTime> searchedAt;
  const SearchHistoryCompanion({
    this.id = const Value.absent(),
    this.query = const Value.absent(),
    this.type = const Value.absent(),
    this.searchedAt = const Value.absent(),
  });
  SearchHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String query,
    required String type,
    this.searchedAt = const Value.absent(),
  }) : query = Value(query),
       type = Value(type);
  static Insertable<SearchHistoryData> custom({
    Expression<int>? id,
    Expression<String>? query,
    Expression<String>? type,
    Expression<DateTime>? searchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (query != null) 'query': query,
      if (type != null) 'type': type,
      if (searchedAt != null) 'searched_at': searchedAt,
    });
  }

  SearchHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? query,
    Value<String>? type,
    Value<DateTime>? searchedAt,
  }) {
    return SearchHistoryCompanion(
      id: id ?? this.id,
      query: query ?? this.query,
      type: type ?? this.type,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (searchedAt.present) {
      map['searched_at'] = Variable<DateTime>(searchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryCompanion(')
          ..write('id: $id, ')
          ..write('query: $query, ')
          ..write('type: $type, ')
          ..write('searchedAt: $searchedAt')
          ..write(')'))
        .toString();
  }
}

class $CollectionsTable extends Collections with TableInfo<$CollectionsTable, Collection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionsTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> bookIds =
      GeneratedColumn<String>(
        'book_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($CollectionsTable.$converterbookIds);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    bookIds,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Collection> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Collection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Collection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      bookIds: $CollectionsTable.$converterbookIds.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}book_ids'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CollectionsTable createAlias(String alias) {
    return $CollectionsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterbookIds = const StringListConverter();
}

class Collection extends DataClass implements Insertable<Collection> {
  final String id;
  final String name;
  final String? description;
  final List<String> bookIds;
  final DateTime createdAt;
  const Collection({
    required this.id,
    required this.name,
    this.description,
    required this.bookIds,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['book_ids'] = Variable<String>(
        $CollectionsTable.$converterbookIds.toSql(bookIds),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CollectionsCompanion toCompanion(bool nullToAbsent) {
    return CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent ? const Value.absent() : Value(description),
      bookIds: Value(bookIds),
      createdAt: Value(createdAt),
    );
  }

  factory Collection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Collection(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      bookIds: serializer.fromJson<List<String>>(json['bookIds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'bookIds': serializer.toJson<List<String>>(bookIds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Collection copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    List<String>? bookIds,
    DateTime? createdAt,
  }) => Collection(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    bookIds: bookIds ?? this.bookIds,
    createdAt: createdAt ?? this.createdAt,
  );
  Collection copyWithCompanion(CollectionsCompanion data) {
    return Collection(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present ? data.description.value : this.description,
      bookIds: data.bookIds.present ? data.bookIds.value : this.bookIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Collection(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('bookIds: $bookIds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, bookIds, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Collection &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.bookIds == this.bookIds &&
          other.createdAt == this.createdAt);
}

class CollectionsCompanion extends UpdateCompanion<Collection> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<List<String>> bookIds;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.bookIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.bookIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Collection> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? bookIds,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (bookIds != null) 'book_ids': bookIds,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<List<String>>? bookIds,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      bookIds: bookIds ?? this.bookIds,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (bookIds.present) {
      map['book_ids'] = Variable<String>(
        $CollectionsTable.$converterbookIds.toSql(bookIds.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('bookIds: $bookIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookCollectionsTable extends BookCollections
    with TableInfo<$BookCollectionsTable, BookCollection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, collectionId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookCollection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, collectionId};
  @override
  BookCollection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookCollection(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $BookCollectionsTable createAlias(String alias) {
    return $BookCollectionsTable(attachedDatabase, alias);
  }
}

class BookCollection extends DataClass implements Insertable<BookCollection> {
  final String bookId;
  final String collectionId;
  final DateTime addedAt;
  const BookCollection({
    required this.bookId,
    required this.collectionId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['collection_id'] = Variable<String>(collectionId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  BookCollectionsCompanion toCompanion(bool nullToAbsent) {
    return BookCollectionsCompanion(
      bookId: Value(bookId),
      collectionId: Value(collectionId),
      addedAt: Value(addedAt),
    );
  }

  factory BookCollection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookCollection(
      bookId: serializer.fromJson<String>(json['bookId']),
      collectionId: serializer.fromJson<String>(json['collectionId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'collectionId': serializer.toJson<String>(collectionId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  BookCollection copyWith({
    String? bookId,
    String? collectionId,
    DateTime? addedAt,
  }) => BookCollection(
    bookId: bookId ?? this.bookId,
    collectionId: collectionId ?? this.collectionId,
    addedAt: addedAt ?? this.addedAt,
  );
  BookCollection copyWithCompanion(BookCollectionsCompanion data) {
    return BookCollection(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      collectionId: data.collectionId.present ? data.collectionId.value : this.collectionId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookCollection(')
          ..write('bookId: $bookId, ')
          ..write('collectionId: $collectionId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, collectionId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookCollection &&
          other.bookId == this.bookId &&
          other.collectionId == this.collectionId &&
          other.addedAt == this.addedAt);
}

class BookCollectionsCompanion extends UpdateCompanion<BookCollection> {
  final Value<String> bookId;
  final Value<String> collectionId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const BookCollectionsCompanion({
    this.bookId = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookCollectionsCompanion.insert({
    required String bookId,
    required String collectionId,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       collectionId = Value(collectionId);
  static Insertable<BookCollection> custom({
    Expression<String>? bookId,
    Expression<String>? collectionId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (collectionId != null) 'collection_id': collectionId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookCollectionsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? collectionId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return BookCollectionsCompanion(
      bookId: bookId ?? this.bookId,
      collectionId: collectionId ?? this.collectionId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookCollectionsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('collectionId: $collectionId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingSessionsTable extends ReadingSessions
    with TableInfo<$ReadingSessionsTable, ReadingSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chaptersReadMeta = const VerificationMeta(
    'chaptersRead',
  );
  @override
  late final GeneratedColumn<int> chaptersRead = GeneratedColumn<int>(
    'chapters_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    startedAt,
    endedAt,
    chaptersRead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingSession> instance, {
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
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('chapters_read')) {
      context.handle(
        _chaptersReadMeta,
        chaptersRead.isAcceptableOrUnknown(
          data['chapters_read']!,
          _chaptersReadMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      chaptersRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapters_read'],
      )!,
    );
  }

  @override
  $ReadingSessionsTable createAlias(String alias) {
    return $ReadingSessionsTable(attachedDatabase, alias);
  }
}

class ReadingSession extends DataClass implements Insertable<ReadingSession> {
  final int id;
  final String bookId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int chaptersRead;
  const ReadingSession({
    required this.id,
    required this.bookId,
    required this.startedAt,
    this.endedAt,
    required this.chaptersRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['chapters_read'] = Variable<int>(chaptersRead);
    return map;
  }

  ReadingSessionsCompanion toCompanion(bool nullToAbsent) {
    return ReadingSessionsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent ? const Value.absent() : Value(endedAt),
      chaptersRead: Value(chaptersRead),
    );
  }

  factory ReadingSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingSession(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      chaptersRead: serializer.fromJson<int>(json['chaptersRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'chaptersRead': serializer.toJson<int>(chaptersRead),
    };
  }

  ReadingSession copyWith({
    int? id,
    String? bookId,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? chaptersRead,
  }) => ReadingSession(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    chaptersRead: chaptersRead ?? this.chaptersRead,
  );
  ReadingSession copyWithCompanion(ReadingSessionsCompanion data) {
    return ReadingSession(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      chaptersRead: data.chaptersRead.present ? data.chaptersRead.value : this.chaptersRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSession(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('chaptersRead: $chaptersRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, startedAt, endedAt, chaptersRead);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingSession &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.chaptersRead == this.chaptersRead);
}

class ReadingSessionsCompanion extends UpdateCompanion<ReadingSession> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> chaptersRead;
  const ReadingSessionsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.chaptersRead = const Value.absent(),
  });
  ReadingSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.chaptersRead = const Value.absent(),
  }) : bookId = Value(bookId);
  static Insertable<ReadingSession> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? chaptersRead,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (chaptersRead != null) 'chapters_read': chaptersRead,
    });
  }

  ReadingSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? chaptersRead,
  }) {
    return ReadingSessionsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      chaptersRead: chaptersRead ?? this.chaptersRead,
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
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (chaptersRead.present) {
      map['chapters_read'] = Variable<int>(chaptersRead.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('chaptersRead: $chaptersRead')
          ..write(')'))
        .toString();
  }
}

class $PerBookSettingsTable extends PerBookSettings
    with TableInfo<$PerBookSettingsTable, PerBookSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PerBookSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingsJsonMeta = const VerificationMeta(
    'settingsJson',
  );
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
    'settings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, settingsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'per_book_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PerBookSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('settings_json')) {
      context.handle(
        _settingsJsonMeta,
        settingsJson.isAcceptableOrUnknown(
          data['settings_json']!,
          _settingsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_settingsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  PerBookSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PerBookSetting(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      settingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PerBookSettingsTable createAlias(String alias) {
    return $PerBookSettingsTable(attachedDatabase, alias);
  }
}

class PerBookSetting extends DataClass implements Insertable<PerBookSetting> {
  final String bookId;
  final String settingsJson;
  final DateTime updatedAt;
  const PerBookSetting({
    required this.bookId,
    required this.settingsJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['settings_json'] = Variable<String>(settingsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PerBookSettingsCompanion toCompanion(bool nullToAbsent) {
    return PerBookSettingsCompanion(
      bookId: Value(bookId),
      settingsJson: Value(settingsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory PerBookSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PerBookSetting(
      bookId: serializer.fromJson<String>(json['bookId']),
      settingsJson: serializer.fromJson<String>(json['settingsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'settingsJson': serializer.toJson<String>(settingsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PerBookSetting copyWith({
    String? bookId,
    String? settingsJson,
    DateTime? updatedAt,
  }) => PerBookSetting(
    bookId: bookId ?? this.bookId,
    settingsJson: settingsJson ?? this.settingsJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PerBookSetting copyWithCompanion(PerBookSettingsCompanion data) {
    return PerBookSetting(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      settingsJson: data.settingsJson.present ? data.settingsJson.value : this.settingsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PerBookSetting(')
          ..write('bookId: $bookId, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, settingsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PerBookSetting &&
          other.bookId == this.bookId &&
          other.settingsJson == this.settingsJson &&
          other.updatedAt == this.updatedAt);
}

class PerBookSettingsCompanion extends UpdateCompanion<PerBookSetting> {
  final Value<String> bookId;
  final Value<String> settingsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PerBookSettingsCompanion({
    this.bookId = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PerBookSettingsCompanion.insert({
    required String bookId,
    required String settingsJson,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       settingsJson = Value(settingsJson);
  static Insertable<PerBookSetting> custom({
    Expression<String>? bookId,
    Expression<String>? settingsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PerBookSettingsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? settingsJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PerBookSettingsCompanion(
      bookId: bookId ?? this.bookId,
      settingsJson: settingsJson ?? this.settingsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PerBookSettingsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#2196F3'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
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
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;
  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      createdAt: Value(createdAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.createdAt == this.createdAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> color;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? color,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
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
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookTagsTable extends BookTags with TableInfo<$BookTagsTable, BookTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, tagId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, tagId};
  @override
  BookTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookTag(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $BookTagsTable createAlias(String alias) {
    return $BookTagsTable(attachedDatabase, alias);
  }
}

class BookTag extends DataClass implements Insertable<BookTag> {
  final String bookId;
  final String tagId;
  final DateTime addedAt;
  const BookTag({
    required this.bookId,
    required this.tagId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['tag_id'] = Variable<String>(tagId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  BookTagsCompanion toCompanion(bool nullToAbsent) {
    return BookTagsCompanion(
      bookId: Value(bookId),
      tagId: Value(tagId),
      addedAt: Value(addedAt),
    );
  }

  factory BookTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookTag(
      bookId: serializer.fromJson<String>(json['bookId']),
      tagId: serializer.fromJson<String>(json['tagId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'tagId': serializer.toJson<String>(tagId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  BookTag copyWith({String? bookId, String? tagId, DateTime? addedAt}) => BookTag(
    bookId: bookId ?? this.bookId,
    tagId: tagId ?? this.tagId,
    addedAt: addedAt ?? this.addedAt,
  );
  BookTag copyWithCompanion(BookTagsCompanion data) {
    return BookTag(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookTag(')
          ..write('bookId: $bookId, ')
          ..write('tagId: $tagId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, tagId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookTag &&
          other.bookId == this.bookId &&
          other.tagId == this.tagId &&
          other.addedAt == this.addedAt);
}

class BookTagsCompanion extends UpdateCompanion<BookTag> {
  final Value<String> bookId;
  final Value<String> tagId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const BookTagsCompanion({
    this.bookId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookTagsCompanion.insert({
    required String bookId,
    required String tagId,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       tagId = Value(tagId);
  static Insertable<BookTag> custom({
    Expression<String>? bookId,
    Expression<String>? tagId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (tagId != null) 'tag_id': tagId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookTagsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? tagId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return BookTagsCompanion(
      bookId: bookId ?? this.bookId,
      tagId: tagId ?? this.tagId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookTagsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('tagId: $tagId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingTimeTable extends ReadingTime with TableInfo<$ReadingTimeTable, ReadingTimeData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingTimeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingTimeSecondsMeta = const VerificationMeta(
    'readingTimeSeconds',
  );
  @override
  late final GeneratedColumn<int> readingTimeSeconds = GeneratedColumn<int>(
    'reading_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pagesReadMeta = const VerificationMeta(
    'pagesRead',
  );
  @override
  late final GeneratedColumn<int> pagesRead = GeneratedColumn<int>(
    'pages_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wpmMeta = const VerificationMeta('wpm');
  @override
  late final GeneratedColumn<double> wpm = GeneratedColumn<double>(
    'wpm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wpmSessionCountMeta = const VerificationMeta(
    'wpmSessionCount',
  );
  @override
  late final GeneratedColumn<int> wpmSessionCount = GeneratedColumn<int>(
    'wpm_session_count',
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
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    date,
    readingTimeSeconds,
    pagesRead,
    wpm,
    wpmSessionCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_time';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingTimeData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('reading_time_seconds')) {
      context.handle(
        _readingTimeSecondsMeta,
        readingTimeSeconds.isAcceptableOrUnknown(
          data['reading_time_seconds']!,
          _readingTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('pages_read')) {
      context.handle(
        _pagesReadMeta,
        pagesRead.isAcceptableOrUnknown(data['pages_read']!, _pagesReadMeta),
      );
    }
    if (data.containsKey('wpm')) {
      context.handle(
        _wpmMeta,
        wpm.isAcceptableOrUnknown(data['wpm']!, _wpmMeta),
      );
    }
    if (data.containsKey('wpm_session_count')) {
      context.handle(
        _wpmSessionCountMeta,
        wpmSessionCount.isAcceptableOrUnknown(
          data['wpm_session_count']!,
          _wpmSessionCountMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, date};
  @override
  ReadingTimeData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingTimeData(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      readingTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reading_time_seconds'],
      )!,
      pagesRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages_read'],
      )!,
      wpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wpm'],
      )!,
      wpmSessionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wpm_session_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingTimeTable createAlias(String alias) {
    return $ReadingTimeTable(attachedDatabase, alias);
  }
}

class ReadingTimeData extends DataClass implements Insertable<ReadingTimeData> {
  final String bookId;
  final DateTime date;
  final int readingTimeSeconds;
  final int pagesRead;
  final double wpm;
  final int wpmSessionCount;
  final DateTime updatedAt;
  const ReadingTimeData({
    required this.bookId,
    required this.date,
    required this.readingTimeSeconds,
    required this.pagesRead,
    required this.wpm,
    required this.wpmSessionCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['date'] = Variable<DateTime>(date);
    map['reading_time_seconds'] = Variable<int>(readingTimeSeconds);
    map['pages_read'] = Variable<int>(pagesRead);
    map['wpm'] = Variable<double>(wpm);
    map['wpm_session_count'] = Variable<int>(wpmSessionCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingTimeCompanion toCompanion(bool nullToAbsent) {
    return ReadingTimeCompanion(
      bookId: Value(bookId),
      date: Value(date),
      readingTimeSeconds: Value(readingTimeSeconds),
      pagesRead: Value(pagesRead),
      wpm: Value(wpm),
      wpmSessionCount: Value(wpmSessionCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingTimeData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingTimeData(
      bookId: serializer.fromJson<String>(json['bookId']),
      date: serializer.fromJson<DateTime>(json['date']),
      readingTimeSeconds: serializer.fromJson<int>(json['readingTimeSeconds']),
      pagesRead: serializer.fromJson<int>(json['pagesRead']),
      wpm: serializer.fromJson<double>(json['wpm']),
      wpmSessionCount: serializer.fromJson<int>(json['wpmSessionCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'date': serializer.toJson<DateTime>(date),
      'readingTimeSeconds': serializer.toJson<int>(readingTimeSeconds),
      'pagesRead': serializer.toJson<int>(pagesRead),
      'wpm': serializer.toJson<double>(wpm),
      'wpmSessionCount': serializer.toJson<int>(wpmSessionCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingTimeData copyWith({
    String? bookId,
    DateTime? date,
    int? readingTimeSeconds,
    int? pagesRead,
    double? wpm,
    int? wpmSessionCount,
    DateTime? updatedAt,
  }) => ReadingTimeData(
    bookId: bookId ?? this.bookId,
    date: date ?? this.date,
    readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
    pagesRead: pagesRead ?? this.pagesRead,
    wpm: wpm ?? this.wpm,
    wpmSessionCount: wpmSessionCount ?? this.wpmSessionCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingTimeData copyWithCompanion(ReadingTimeCompanion data) {
    return ReadingTimeData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      date: data.date.present ? data.date.value : this.date,
      readingTimeSeconds: data.readingTimeSeconds.present
          ? data.readingTimeSeconds.value
          : this.readingTimeSeconds,
      pagesRead: data.pagesRead.present ? data.pagesRead.value : this.pagesRead,
      wpm: data.wpm.present ? data.wpm.value : this.wpm,
      wpmSessionCount: data.wpmSessionCount.present
          ? data.wpmSessionCount.value
          : this.wpmSessionCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingTimeData(')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('readingTimeSeconds: $readingTimeSeconds, ')
          ..write('pagesRead: $pagesRead, ')
          ..write('wpm: $wpm, ')
          ..write('wpmSessionCount: $wpmSessionCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    date,
    readingTimeSeconds,
    pagesRead,
    wpm,
    wpmSessionCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingTimeData &&
          other.bookId == this.bookId &&
          other.date == this.date &&
          other.readingTimeSeconds == this.readingTimeSeconds &&
          other.pagesRead == this.pagesRead &&
          other.wpm == this.wpm &&
          other.wpmSessionCount == this.wpmSessionCount &&
          other.updatedAt == this.updatedAt);
}

class ReadingTimeCompanion extends UpdateCompanion<ReadingTimeData> {
  final Value<String> bookId;
  final Value<DateTime> date;
  final Value<int> readingTimeSeconds;
  final Value<int> pagesRead;
  final Value<double> wpm;
  final Value<int> wpmSessionCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingTimeCompanion({
    this.bookId = const Value.absent(),
    this.date = const Value.absent(),
    this.readingTimeSeconds = const Value.absent(),
    this.pagesRead = const Value.absent(),
    this.wpm = const Value.absent(),
    this.wpmSessionCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingTimeCompanion.insert({
    required String bookId,
    required DateTime date,
    this.readingTimeSeconds = const Value.absent(),
    this.pagesRead = const Value.absent(),
    this.wpm = const Value.absent(),
    this.wpmSessionCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       date = Value(date);
  static Insertable<ReadingTimeData> custom({
    Expression<String>? bookId,
    Expression<DateTime>? date,
    Expression<int>? readingTimeSeconds,
    Expression<int>? pagesRead,
    Expression<double>? wpm,
    Expression<int>? wpmSessionCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (date != null) 'date': date,
      if (readingTimeSeconds != null) 'reading_time_seconds': readingTimeSeconds,
      if (pagesRead != null) 'pages_read': pagesRead,
      if (wpm != null) 'wpm': wpm,
      if (wpmSessionCount != null) 'wpm_session_count': wpmSessionCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingTimeCompanion copyWith({
    Value<String>? bookId,
    Value<DateTime>? date,
    Value<int>? readingTimeSeconds,
    Value<int>? pagesRead,
    Value<double>? wpm,
    Value<int>? wpmSessionCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReadingTimeCompanion(
      bookId: bookId ?? this.bookId,
      date: date ?? this.date,
      readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
      pagesRead: pagesRead ?? this.pagesRead,
      wpm: wpm ?? this.wpm,
      wpmSessionCount: wpmSessionCount ?? this.wpmSessionCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (readingTimeSeconds.present) {
      map['reading_time_seconds'] = Variable<int>(readingTimeSeconds.value);
    }
    if (pagesRead.present) {
      map['pages_read'] = Variable<int>(pagesRead.value);
    }
    if (wpm.present) {
      map['wpm'] = Variable<double>(wpm.value);
    }
    if (wpmSessionCount.present) {
      map['wpm_session_count'] = Variable<int>(wpmSessionCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingTimeCompanion(')
          ..write('bookId: $bookId, ')
          ..write('date: $date, ')
          ..write('readingTimeSeconds: $readingTimeSeconds, ')
          ..write('pagesRead: $pagesRead, ')
          ..write('wpm: $wpm, ')
          ..write('wpmSessionCount: $wpmSessionCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TextHighlightsTable extends TextHighlights
    with TableInfo<$TextHighlightsTable, TextHighlight> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TextHighlightsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _blockIndexMeta = const VerificationMeta(
    'blockIndex',
  );
  @override
  late final GeneratedColumn<int> blockIndex = GeneratedColumn<int>(
    'block_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _selectedTextMeta = const VerificationMeta(
    'selectedText',
  );
  @override
  late final GeneratedColumn<String> selectedText = GeneratedColumn<String>(
    'selected_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('yellow'),
  );
  static const VerificationMeta _decorationMeta = const VerificationMeta(
    'decoration',
  );
  @override
  late final GeneratedColumn<String> decoration = GeneratedColumn<String>(
    'decoration',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _noteTextMeta = const VerificationMeta(
    'noteText',
  );
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
    'note_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOrphanedMeta = const VerificationMeta(
    'isOrphaned',
  );
  @override
  late final GeneratedColumn<bool> isOrphaned = GeneratedColumn<bool>(
    'is_orphaned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_orphaned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterId,
    chapterIndex,
    blockIndex,
    startOffset,
    endOffset,
    selectedText,
    color,
    decoration,
    noteText,
    isOrphaned,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'text_highlights';
  @override
  VerificationContext validateIntegrity(
    Insertable<TextHighlight> instance, {
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
    if (data.containsKey('block_index')) {
      context.handle(
        _blockIndexMeta,
        blockIndex.isAcceptableOrUnknown(data['block_index']!, _blockIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIndexMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('selected_text')) {
      context.handle(
        _selectedTextMeta,
        selectedText.isAcceptableOrUnknown(
          data['selected_text']!,
          _selectedTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_selectedTextMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('decoration')) {
      context.handle(
        _decorationMeta,
        decoration.isAcceptableOrUnknown(data['decoration']!, _decorationMeta),
      );
    }
    if (data.containsKey('note_text')) {
      context.handle(
        _noteTextMeta,
        noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta),
      );
    }
    if (data.containsKey('is_orphaned')) {
      context.handle(
        _isOrphanedMeta,
        isOrphaned.isAcceptableOrUnknown(data['is_orphaned']!, _isOrphanedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TextHighlight map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TextHighlight(
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
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      blockIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}block_index'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      )!,
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
      )!,
      selectedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_text'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      decoration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decoration'],
      )!,
      noteText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_text'],
      ),
      isOrphaned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_orphaned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $TextHighlightsTable createAlias(String alias) {
    return $TextHighlightsTable(attachedDatabase, alias);
  }
}

class TextHighlight extends DataClass implements Insertable<TextHighlight> {
  final String id;
  final String bookId;
  final String chapterId;
  final int chapterIndex;
  final int blockIndex;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final String color;
  final String decoration;
  final String? noteText;
  final bool isOrphaned;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const TextHighlight({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.chapterIndex,
    required this.blockIndex,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    required this.color,
    required this.decoration,
    this.noteText,
    required this.isOrphaned,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<String>(chapterId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['block_index'] = Variable<int>(blockIndex);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['selected_text'] = Variable<String>(selectedText);
    map['color'] = Variable<String>(color);
    map['decoration'] = Variable<String>(decoration);
    if (!nullToAbsent || noteText != null) {
      map['note_text'] = Variable<String>(noteText);
    }
    map['is_orphaned'] = Variable<bool>(isOrphaned);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  TextHighlightsCompanion toCompanion(bool nullToAbsent) {
    return TextHighlightsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      chapterIndex: Value(chapterIndex),
      blockIndex: Value(blockIndex),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      selectedText: Value(selectedText),
      color: Value(color),
      decoration: Value(decoration),
      noteText: noteText == null && nullToAbsent ? const Value.absent() : Value(noteText),
      isOrphaned: Value(isOrphaned),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
    );
  }

  factory TextHighlight.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TextHighlight(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      blockIndex: serializer.fromJson<int>(json['blockIndex']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      selectedText: serializer.fromJson<String>(json['selectedText']),
      color: serializer.fromJson<String>(json['color']),
      decoration: serializer.fromJson<String>(json['decoration']),
      noteText: serializer.fromJson<String?>(json['noteText']),
      isOrphaned: serializer.fromJson<bool>(json['isOrphaned']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterId': serializer.toJson<String>(chapterId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'blockIndex': serializer.toJson<int>(blockIndex),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'selectedText': serializer.toJson<String>(selectedText),
      'color': serializer.toJson<String>(color),
      'decoration': serializer.toJson<String>(decoration),
      'noteText': serializer.toJson<String?>(noteText),
      'isOrphaned': serializer.toJson<bool>(isOrphaned),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  TextHighlight copyWith({
    String? id,
    String? bookId,
    String? chapterId,
    int? chapterIndex,
    int? blockIndex,
    int? startOffset,
    int? endOffset,
    String? selectedText,
    String? color,
    String? decoration,
    Value<String?> noteText = const Value.absent(),
    bool? isOrphaned,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => TextHighlight(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    blockIndex: blockIndex ?? this.blockIndex,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    selectedText: selectedText ?? this.selectedText,
    color: color ?? this.color,
    decoration: decoration ?? this.decoration,
    noteText: noteText.present ? noteText.value : this.noteText,
    isOrphaned: isOrphaned ?? this.isOrphaned,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  TextHighlight copyWithCompanion(TextHighlightsCompanion data) {
    return TextHighlight(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      chapterIndex: data.chapterIndex.present ? data.chapterIndex.value : this.chapterIndex,
      blockIndex: data.blockIndex.present ? data.blockIndex.value : this.blockIndex,
      startOffset: data.startOffset.present ? data.startOffset.value : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      selectedText: data.selectedText.present ? data.selectedText.value : this.selectedText,
      color: data.color.present ? data.color.value : this.color,
      decoration: data.decoration.present ? data.decoration.value : this.decoration,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      isOrphaned: data.isOrphaned.present ? data.isOrphaned.value : this.isOrphaned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TextHighlight(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('blockIndex: $blockIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('selectedText: $selectedText, ')
          ..write('color: $color, ')
          ..write('decoration: $decoration, ')
          ..write('noteText: $noteText, ')
          ..write('isOrphaned: $isOrphaned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterId,
    chapterIndex,
    blockIndex,
    startOffset,
    endOffset,
    selectedText,
    color,
    decoration,
    noteText,
    isOrphaned,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextHighlight &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.chapterIndex == this.chapterIndex &&
          other.blockIndex == this.blockIndex &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.selectedText == this.selectedText &&
          other.color == this.color &&
          other.decoration == this.decoration &&
          other.noteText == this.noteText &&
          other.isOrphaned == this.isOrphaned &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TextHighlightsCompanion extends UpdateCompanion<TextHighlight> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> chapterId;
  final Value<int> chapterIndex;
  final Value<int> blockIndex;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<String> selectedText;
  final Value<String> color;
  final Value<String> decoration;
  final Value<String?> noteText;
  final Value<bool> isOrphaned;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const TextHighlightsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.blockIndex = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.selectedText = const Value.absent(),
    this.color = const Value.absent(),
    this.decoration = const Value.absent(),
    this.noteText = const Value.absent(),
    this.isOrphaned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TextHighlightsCompanion.insert({
    required String id,
    required String bookId,
    required String chapterId,
    required int chapterIndex,
    required int blockIndex,
    required int startOffset,
    required int endOffset,
    required String selectedText,
    this.color = const Value.absent(),
    this.decoration = const Value.absent(),
    this.noteText = const Value.absent(),
    this.isOrphaned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterId = Value(chapterId),
       chapterIndex = Value(chapterIndex),
       blockIndex = Value(blockIndex),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       selectedText = Value(selectedText);
  static Insertable<TextHighlight> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? chapterId,
    Expression<int>? chapterIndex,
    Expression<int>? blockIndex,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<String>? selectedText,
    Expression<String>? color,
    Expression<String>? decoration,
    Expression<String>? noteText,
    Expression<bool>? isOrphaned,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (blockIndex != null) 'block_index': blockIndex,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (selectedText != null) 'selected_text': selectedText,
      if (color != null) 'color': color,
      if (decoration != null) 'decoration': decoration,
      if (noteText != null) 'note_text': noteText,
      if (isOrphaned != null) 'is_orphaned': isOrphaned,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TextHighlightsCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? chapterId,
    Value<int>? chapterIndex,
    Value<int>? blockIndex,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<String>? selectedText,
    Value<String>? color,
    Value<String>? decoration,
    Value<String?>? noteText,
    Value<bool>? isOrphaned,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return TextHighlightsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      blockIndex: blockIndex ?? this.blockIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      selectedText: selectedText ?? this.selectedText,
      color: color ?? this.color,
      decoration: decoration ?? this.decoration,
      noteText: noteText ?? this.noteText,
      isOrphaned: isOrphaned ?? this.isOrphaned,
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
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (blockIndex.present) {
      map['block_index'] = Variable<int>(blockIndex.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (selectedText.present) {
      map['selected_text'] = Variable<String>(selectedText.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (decoration.present) {
      map['decoration'] = Variable<String>(decoration.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (isOrphaned.present) {
      map['is_orphaned'] = Variable<bool>(isOrphaned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TextHighlightsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('blockIndex: $blockIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('selectedText: $selectedText, ')
          ..write('color: $color, ')
          ..write('decoration: $decoration, ')
          ..write('noteText: $noteText, ')
          ..write('isOrphaned: $isOrphaned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SavedBooksTable savedBooks = $SavedBooksTable(this);
  late final $AuthorsTable authors = $AuthorsTable(this);
  late final $SeriesTable series = $SeriesTable(this);
  late final $BookSeriesTable bookSeries = $BookSeriesTable(this);
  late final $GenresTable genres = $GenresTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $QuotesTable quotes = $QuotesTable(this);
  late final $SearchHistoryTable searchHistory = $SearchHistoryTable(this);
  late final $CollectionsTable collections = $CollectionsTable(this);
  late final $BookCollectionsTable bookCollections = $BookCollectionsTable(
    this,
  );
  late final $ReadingSessionsTable readingSessions = $ReadingSessionsTable(
    this,
  );
  late final $PerBookSettingsTable perBookSettings = $PerBookSettingsTable(
    this,
  );
  late final $TagsTable tags = $TagsTable(this);
  late final $BookTagsTable bookTags = $BookTagsTable(this);
  late final $ReadingTimeTable readingTime = $ReadingTimeTable(this);
  late final $TextHighlightsTable textHighlights = $TextHighlightsTable(this);
  late final Index idxSavedBooksContentHash = Index(
    'idx_saved_books_content_hash',
    'CREATE INDEX idx_saved_books_content_hash ON saved_books (content_hash)',
  );
  late final Index idxSavedBooksAddedAt = Index(
    'idx_saved_books_added_at',
    'CREATE INDEX idx_saved_books_added_at ON saved_books (added_at)',
  );
  late final Index idxSavedBooksTitle = Index(
    'idx_saved_books_title',
    'CREATE INDEX idx_saved_books_title ON saved_books (title)',
  );
  late final Index idxDownloadsBookId = Index(
    'idx_downloads_bookId',
    'CREATE INDEX idx_downloads_bookId ON downloads (book_id)',
  );
  late final Index idxBookmarksBookId = Index(
    'idx_bookmarks_bookId',
    'CREATE INDEX idx_bookmarks_bookId ON bookmarks (book_id)',
  );
  late final Index idxNotesBookId = Index(
    'idx_notes_bookId',
    'CREATE INDEX idx_notes_bookId ON notes (book_id)',
  );
  late final Index idxQuotesBookId = Index(
    'idx_quotes_bookId',
    'CREATE INDEX idx_quotes_bookId ON quotes (book_id)',
  );
  late final Index idxBookCollectionsCollectionId = Index(
    'idx_book_collections_collection_id',
    'CREATE INDEX idx_book_collections_collection_id ON book_collections (collection_id)',
  );
  late final Index idxReadingSessionsBookId = Index(
    'idx_reading_sessions_bookId',
    'CREATE INDEX idx_reading_sessions_bookId ON reading_sessions (book_id)',
  );
  late final Index idxBookTagsTagId = Index(
    'idx_book_tags_tag_id',
    'CREATE INDEX idx_book_tags_tag_id ON book_tags (tag_id)',
  );
  late final Index idxTextHighlightsBookId = Index(
    'idx_text_highlights_bookId',
    'CREATE INDEX idx_text_highlights_bookId ON text_highlights (book_id)',
  );
  late final Index idxTextHighlightsChapterId = Index(
    'idx_text_highlights_chapterId',
    'CREATE INDEX idx_text_highlights_chapterId ON text_highlights (chapter_id)',
  );
  late final BookDao bookDao = BookDao(this as AppDatabase);
  late final DownloadDao downloadDao = DownloadDao(this as AppDatabase);
  late final CollectionDao collectionDao = CollectionDao(this as AppDatabase);
  late final BookmarkDao bookmarkDao = BookmarkDao(this as AppDatabase);
  late final GenreDao genreDao = GenreDao(this as AppDatabase);
  late final PerBookSettingsDao perBookSettingsDao = PerBookSettingsDao(
    this as AppDatabase,
  );
  late final TagDao tagDao = TagDao(this as AppDatabase);
  late final ReadingTimeDao readingTimeDao = ReadingTimeDao(
    this as AppDatabase,
  );
  late final AuthorDao authorDao = AuthorDao(this as AppDatabase);
  late final SeriesDao seriesDao = SeriesDao(this as AppDatabase);
  late final HighlightDao highlightDao = HighlightDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    savedBooks,
    authors,
    series,
    bookSeries,
    genres,
    downloads,
    readingProgress,
    bookmarks,
    notes,
    quotes,
    searchHistory,
    collections,
    bookCollections,
    readingSessions,
    perBookSettings,
    tags,
    bookTags,
    readingTime,
    textHighlights,
    idxSavedBooksContentHash,
    idxSavedBooksAddedAt,
    idxSavedBooksTitle,
    idxDownloadsBookId,
    idxBookmarksBookId,
    idxNotesBookId,
    idxQuotesBookId,
    idxBookCollectionsCollectionId,
    idxReadingSessionsBookId,
    idxBookTagsTagId,
    idxTextHighlightsBookId,
    idxTextHighlightsChapterId,
  ];
}

typedef $$SavedBooksTableCreateCompanionBuilder =
    SavedBooksCompanion Function({
      required String id,
      required String title,
      Value<List<String>> authorIds,
      Value<List<String>> genreIds,
      Value<String?> description,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String> coverStatus,
      Value<DateTime?> publishDate,
      Value<String?> sourceId,
      Value<String?> sourceUrl,
      Value<DateTime> addedAt,
      Value<String?> contentHash,
      Value<int?> fileSize,
      Value<String> filePath,
      Value<String> readingStatus,
      Value<String?> detectedEncoding,
      Value<double?> encodingConfidence,
      Value<String?> encodingSource,
      Value<String?> userForcedEncoding,
      Value<String> storageMode,
      Value<String?> externalUri,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$SavedBooksTableUpdateCompanionBuilder =
    SavedBooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<List<String>> authorIds,
      Value<List<String>> genreIds,
      Value<String?> description,
      Value<String?> coverUrl,
      Value<String?> coverPath,
      Value<String> coverStatus,
      Value<DateTime?> publishDate,
      Value<String?> sourceId,
      Value<String?> sourceUrl,
      Value<DateTime> addedAt,
      Value<String?> contentHash,
      Value<int?> fileSize,
      Value<String> filePath,
      Value<String> readingStatus,
      Value<String?> detectedEncoding,
      Value<double?> encodingConfidence,
      Value<String?> encodingSource,
      Value<String?> userForcedEncoding,
      Value<String> storageMode,
      Value<String?> externalUri,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$SavedBooksTableFilterComposer extends Composer<_$AppDatabase, $SavedBooksTable> {
  $$SavedBooksTableFilterComposer({
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

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get authorIds =>
      $composableBuilder(
        column: $table.authorIds,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get genreIds =>
      $composableBuilder(
        column: $table.genreIds,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverStatus => $composableBuilder(
    column: $table.coverStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishDate => $composableBuilder(
    column: $table.publishDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingStatus => $composableBuilder(
    column: $table.readingStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detectedEncoding => $composableBuilder(
    column: $table.detectedEncoding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get encodingConfidence => $composableBuilder(
    column: $table.encodingConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encodingSource => $composableBuilder(
    column: $table.encodingSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userForcedEncoding => $composableBuilder(
    column: $table.userForcedEncoding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalUri => $composableBuilder(
    column: $table.externalUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedBooksTableOrderingComposer extends Composer<_$AppDatabase, $SavedBooksTable> {
  $$SavedBooksTableOrderingComposer({
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

  ColumnOrderings<String> get authorIds => $composableBuilder(
    column: $table.authorIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genreIds => $composableBuilder(
    column: $table.genreIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverStatus => $composableBuilder(
    column: $table.coverStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishDate => $composableBuilder(
    column: $table.publishDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingStatus => $composableBuilder(
    column: $table.readingStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detectedEncoding => $composableBuilder(
    column: $table.detectedEncoding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get encodingConfidence => $composableBuilder(
    column: $table.encodingConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encodingSource => $composableBuilder(
    column: $table.encodingSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userForcedEncoding => $composableBuilder(
    column: $table.userForcedEncoding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalUri => $composableBuilder(
    column: $table.externalUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedBooksTableAnnotationComposer extends Composer<_$AppDatabase, $SavedBooksTable> {
  $$SavedBooksTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<List<String>, String> get authorIds =>
      $composableBuilder(column: $table.authorIds, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get genreIds =>
      $composableBuilder(column: $table.genreIds, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get coverStatus => $composableBuilder(
    column: $table.coverStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get publishDate => $composableBuilder(
    column: $table.publishDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get readingStatus => $composableBuilder(
    column: $table.readingStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detectedEncoding => $composableBuilder(
    column: $table.detectedEncoding,
    builder: (column) => column,
  );

  GeneratedColumn<double> get encodingConfidence => $composableBuilder(
    column: $table.encodingConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encodingSource => $composableBuilder(
    column: $table.encodingSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userForcedEncoding => $composableBuilder(
    column: $table.userForcedEncoding,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalUri => $composableBuilder(
    column: $table.externalUri,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SavedBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedBooksTable,
          SavedBook,
          $$SavedBooksTableFilterComposer,
          $$SavedBooksTableOrderingComposer,
          $$SavedBooksTableAnnotationComposer,
          $$SavedBooksTableCreateCompanionBuilder,
          $$SavedBooksTableUpdateCompanionBuilder,
          (
            SavedBook,
            BaseReferences<_$AppDatabase, $SavedBooksTable, SavedBook>,
          ),
          SavedBook,
          PrefetchHooks Function()
        > {
  $$SavedBooksTableTableManager(_$AppDatabase db, $SavedBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SavedBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SavedBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<List<String>> authorIds = const Value.absent(),
                Value<List<String>> genreIds = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String> coverStatus = const Value.absent(),
                Value<DateTime?> publishDate = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> readingStatus = const Value.absent(),
                Value<String?> detectedEncoding = const Value.absent(),
                Value<double?> encodingConfidence = const Value.absent(),
                Value<String?> encodingSource = const Value.absent(),
                Value<String?> userForcedEncoding = const Value.absent(),
                Value<String> storageMode = const Value.absent(),
                Value<String?> externalUri = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedBooksCompanion(
                id: id,
                title: title,
                authorIds: authorIds,
                genreIds: genreIds,
                description: description,
                coverUrl: coverUrl,
                coverPath: coverPath,
                coverStatus: coverStatus,
                publishDate: publishDate,
                sourceId: sourceId,
                sourceUrl: sourceUrl,
                addedAt: addedAt,
                contentHash: contentHash,
                fileSize: fileSize,
                filePath: filePath,
                readingStatus: readingStatus,
                detectedEncoding: detectedEncoding,
                encodingConfidence: encodingConfidence,
                encodingSource: encodingSource,
                userForcedEncoding: userForcedEncoding,
                storageMode: storageMode,
                externalUri: externalUri,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<List<String>> authorIds = const Value.absent(),
                Value<List<String>> genreIds = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String> coverStatus = const Value.absent(),
                Value<DateTime?> publishDate = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> readingStatus = const Value.absent(),
                Value<String?> detectedEncoding = const Value.absent(),
                Value<double?> encodingConfidence = const Value.absent(),
                Value<String?> encodingSource = const Value.absent(),
                Value<String?> userForcedEncoding = const Value.absent(),
                Value<String> storageMode = const Value.absent(),
                Value<String?> externalUri = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedBooksCompanion.insert(
                id: id,
                title: title,
                authorIds: authorIds,
                genreIds: genreIds,
                description: description,
                coverUrl: coverUrl,
                coverPath: coverPath,
                coverStatus: coverStatus,
                publishDate: publishDate,
                sourceId: sourceId,
                sourceUrl: sourceUrl,
                addedAt: addedAt,
                contentHash: contentHash,
                fileSize: fileSize,
                filePath: filePath,
                readingStatus: readingStatus,
                detectedEncoding: detectedEncoding,
                encodingConfidence: encodingConfidence,
                encodingSource: encodingSource,
                userForcedEncoding: userForcedEncoding,
                storageMode: storageMode,
                externalUri: externalUri,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedBooksTable,
      SavedBook,
      $$SavedBooksTableFilterComposer,
      $$SavedBooksTableOrderingComposer,
      $$SavedBooksTableAnnotationComposer,
      $$SavedBooksTableCreateCompanionBuilder,
      $$SavedBooksTableUpdateCompanionBuilder,
      (SavedBook, BaseReferences<_$AppDatabase, $SavedBooksTable, SavedBook>),
      SavedBook,
      PrefetchHooks Function()
    >;
typedef $$AuthorsTableCreateCompanionBuilder =
    AuthorsCompanion Function({
      required String id,
      required String name,
      Value<List<String>> bookIds,
      Value<int> rowid,
    });
typedef $$AuthorsTableUpdateCompanionBuilder =
    AuthorsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<List<String>> bookIds,
      Value<int> rowid,
    });

class $$AuthorsTableFilterComposer extends Composer<_$AppDatabase, $AuthorsTable> {
  $$AuthorsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get bookIds =>
      $composableBuilder(
        column: $table.bookIds,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$AuthorsTableOrderingComposer extends Composer<_$AppDatabase, $AuthorsTable> {
  $$AuthorsTableOrderingComposer({
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

  ColumnOrderings<String> get bookIds => $composableBuilder(
    column: $table.bookIds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuthorsTableAnnotationComposer extends Composer<_$AppDatabase, $AuthorsTable> {
  $$AuthorsTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<List<String>, String> get bookIds =>
      $composableBuilder(column: $table.bookIds, builder: (column) => column);
}

class $$AuthorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuthorsTable,
          Author,
          $$AuthorsTableFilterComposer,
          $$AuthorsTableOrderingComposer,
          $$AuthorsTableAnnotationComposer,
          $$AuthorsTableCreateCompanionBuilder,
          $$AuthorsTableUpdateCompanionBuilder,
          (Author, BaseReferences<_$AppDatabase, $AuthorsTable, Author>),
          Author,
          PrefetchHooks Function()
        > {
  $$AuthorsTableTableManager(_$AppDatabase db, $AuthorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AuthorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AuthorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuthorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<List<String>> bookIds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuthorsCompanion(
                id: id,
                name: name,
                bookIds: bookIds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<List<String>> bookIds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuthorsCompanion.insert(
                id: id,
                name: name,
                bookIds: bookIds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuthorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuthorsTable,
      Author,
      $$AuthorsTableFilterComposer,
      $$AuthorsTableOrderingComposer,
      $$AuthorsTableAnnotationComposer,
      $$AuthorsTableCreateCompanionBuilder,
      $$AuthorsTableUpdateCompanionBuilder,
      (Author, BaseReferences<_$AppDatabase, $AuthorsTable, Author>),
      Author,
      PrefetchHooks Function()
    >;
typedef $$SeriesTableCreateCompanionBuilder =
    SeriesCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<List<String>> bookIds,
      Value<int> rowid,
    });
typedef $$SeriesTableUpdateCompanionBuilder =
    SeriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<List<String>> bookIds,
      Value<int> rowid,
    });

class $$SeriesTableFilterComposer extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get bookIds =>
      $composableBuilder(
        column: $table.bookIds,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$SeriesTableOrderingComposer extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookIds => $composableBuilder(
    column: $table.bookIds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesTableAnnotationComposer extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get bookIds =>
      $composableBuilder(column: $table.bookIds, builder: (column) => column);
}

class $$SeriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesTable,
          Sery,
          $$SeriesTableFilterComposer,
          $$SeriesTableOrderingComposer,
          $$SeriesTableAnnotationComposer,
          $$SeriesTableCreateCompanionBuilder,
          $$SeriesTableUpdateCompanionBuilder,
          (Sery, BaseReferences<_$AppDatabase, $SeriesTable, Sery>),
          Sery,
          PrefetchHooks Function()
        > {
  $$SeriesTableTableManager(_$AppDatabase db, $SeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<List<String>> bookIds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesCompanion(
                id: id,
                name: name,
                description: description,
                bookIds: bookIds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<List<String>> bookIds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesCompanion.insert(
                id: id,
                name: name,
                description: description,
                bookIds: bookIds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesTable,
      Sery,
      $$SeriesTableFilterComposer,
      $$SeriesTableOrderingComposer,
      $$SeriesTableAnnotationComposer,
      $$SeriesTableCreateCompanionBuilder,
      $$SeriesTableUpdateCompanionBuilder,
      (Sery, BaseReferences<_$AppDatabase, $SeriesTable, Sery>),
      Sery,
      PrefetchHooks Function()
    >;
typedef $$BookSeriesTableCreateCompanionBuilder =
    BookSeriesCompanion Function({
      required String bookId,
      required String seriesId,
      Value<int?> sequenceNumber,
      Value<int> rowid,
    });
typedef $$BookSeriesTableUpdateCompanionBuilder =
    BookSeriesCompanion Function({
      Value<String> bookId,
      Value<String> seriesId,
      Value<int?> sequenceNumber,
      Value<int> rowid,
    });

class $$BookSeriesTableFilterComposer extends Composer<_$AppDatabase, $BookSeriesTable> {
  $$BookSeriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookSeriesTableOrderingComposer extends Composer<_$AppDatabase, $BookSeriesTable> {
  $$BookSeriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookSeriesTableAnnotationComposer extends Composer<_$AppDatabase, $BookSeriesTable> {
  $$BookSeriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => column,
  );
}

class $$BookSeriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookSeriesTable,
          BookSery,
          $$BookSeriesTableFilterComposer,
          $$BookSeriesTableOrderingComposer,
          $$BookSeriesTableAnnotationComposer,
          $$BookSeriesTableCreateCompanionBuilder,
          $$BookSeriesTableUpdateCompanionBuilder,
          (BookSery, BaseReferences<_$AppDatabase, $BookSeriesTable, BookSery>),
          BookSery,
          PrefetchHooks Function()
        > {
  $$BookSeriesTableTableManager(_$AppDatabase db, $BookSeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$BookSeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$BookSeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookSeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<int?> sequenceNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookSeriesCompanion(
                bookId: bookId,
                seriesId: seriesId,
                sequenceNumber: sequenceNumber,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String seriesId,
                Value<int?> sequenceNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookSeriesCompanion.insert(
                bookId: bookId,
                seriesId: seriesId,
                sequenceNumber: sequenceNumber,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookSeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookSeriesTable,
      BookSery,
      $$BookSeriesTableFilterComposer,
      $$BookSeriesTableOrderingComposer,
      $$BookSeriesTableAnnotationComposer,
      $$BookSeriesTableCreateCompanionBuilder,
      $$BookSeriesTableUpdateCompanionBuilder,
      (BookSery, BaseReferences<_$AppDatabase, $BookSeriesTable, BookSery>),
      BookSery,
      PrefetchHooks Function()
    >;
typedef $$GenresTableCreateCompanionBuilder =
    GenresCompanion Function({
      required String id,
      required String name,
      Value<String?> parentId,
      Value<int> rowid,
    });
typedef $$GenresTableUpdateCompanionBuilder =
    GenresCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> parentId,
      Value<int> rowid,
    });

class $$GenresTableFilterComposer extends Composer<_$AppDatabase, $GenresTable> {
  $$GenresTableFilterComposer({
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

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GenresTableOrderingComposer extends Composer<_$AppDatabase, $GenresTable> {
  $$GenresTableOrderingComposer({
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

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GenresTableAnnotationComposer extends Composer<_$AppDatabase, $GenresTable> {
  $$GenresTableAnnotationComposer({
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

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);
}

class $$GenresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GenresTable,
          Genre,
          $$GenresTableFilterComposer,
          $$GenresTableOrderingComposer,
          $$GenresTableAnnotationComposer,
          $$GenresTableCreateCompanionBuilder,
          $$GenresTableUpdateCompanionBuilder,
          (Genre, BaseReferences<_$AppDatabase, $GenresTable, Genre>),
          Genre,
          PrefetchHooks Function()
        > {
  $$GenresTableTableManager(_$AppDatabase db, $GenresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$GenresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$GenresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GenresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenresCompanion(
                id: id,
                name: name,
                parentId: parentId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> parentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenresCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GenresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GenresTable,
      Genre,
      $$GenresTableFilterComposer,
      $$GenresTableOrderingComposer,
      $$GenresTableAnnotationComposer,
      $$GenresTableCreateCompanionBuilder,
      $$GenresTableUpdateCompanionBuilder,
      (Genre, BaseReferences<_$AppDatabase, $GenresTable, Genre>),
      Genre,
      PrefetchHooks Function()
    >;
typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      required String id,
      required String bookId,
      Value<String> bookTitle,
      required String format,
      required String sourceUrl,
      Value<String?> targetPath,
      required DownloadStatusDb status,
      Value<int> downloadedBytes,
      Value<int> totalBytes,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> bookTitle,
      Value<String> format,
      Value<String> sourceUrl,
      Value<String?> targetPath,
      Value<DownloadStatusDb> status,
      Value<int> downloadedBytes,
      Value<int> totalBytes,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$DownloadsTableFilterComposer extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
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

  ColumnFilters<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadStatusDb, DownloadStatusDb, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadsTableOrderingComposer extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
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

  ColumnOrderings<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
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

  GeneratedColumn<String> get bookTitle =>
      $composableBuilder(column: $table.bookTitle, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DownloadStatusDb, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          Download,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (Download, BaseReferences<_$AppDatabase, $DownloadsTable, Download>),
          Download,
          PrefetchHooks Function()
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> bookTitle = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String?> targetPath = const Value.absent(),
                Value<DownloadStatusDb> status = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                bookId: bookId,
                bookTitle: bookTitle,
                format: format,
                sourceUrl: sourceUrl,
                targetPath: targetPath,
                status: status,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                Value<String> bookTitle = const Value.absent(),
                required String format,
                required String sourceUrl,
                Value<String?> targetPath = const Value.absent(),
                required DownloadStatusDb status,
                Value<int> downloadedBytes = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion.insert(
                id: id,
                bookId: bookId,
                bookTitle: bookTitle,
                format: format,
                sourceUrl: sourceUrl,
                targetPath: targetPath,
                status: status,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      Download,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (Download, BaseReferences<_$AppDatabase, $DownloadsTable, Download>),
      Download,
      PrefetchHooks Function()
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      required String bookId,
      Value<int> currentPosition,
      Value<int> chapterIndex,
      Value<int> paragraphIndex,
      Value<double> localOffset,
      Value<double> progressPercent,
      Value<String> chapterId,
      Value<int> textOffset,
      Value<int> totalPages,
      Value<DateTime> lastRead,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<String> bookId,
      Value<int> currentPosition,
      Value<int> chapterIndex,
      Value<int> paragraphIndex,
      Value<double> localOffset,
      Value<double> progressPercent,
      Value<String> chapterId,
      Value<int> textOffset,
      Value<int> totalPages,
      Value<DateTime> lastRead,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ReadingProgressTableFilterComposer extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPosition => $composableBuilder(
    column: $table.currentPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastRead => $composableBuilder(
    column: $table.lastRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPosition => $composableBuilder(
    column: $table.currentPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastRead => $composableBuilder(
    column: $table.lastRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get currentPosition => $composableBuilder(
    column: $table.currentPosition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progressPercent => $composableBuilder(
    column: $table.progressPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get textOffset => $composableBuilder(
    column: $table.textOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastRead =>
      $composableBuilder(column: $table.lastRead, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (
            ReadingProgressData,
            BaseReferences<_$AppDatabase, $ReadingProgressTable, ReadingProgressData>,
          ),
          ReadingProgressData,
          PrefetchHooks Function()
        > {
  $$ReadingProgressTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> currentPosition = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<double> localOffset = const Value.absent(),
                Value<double> progressPercent = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> textOffset = const Value.absent(),
                Value<int> totalPages = const Value.absent(),
                Value<DateTime> lastRead = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion(
                bookId: bookId,
                currentPosition: currentPosition,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                localOffset: localOffset,
                progressPercent: progressPercent,
                chapterId: chapterId,
                textOffset: textOffset,
                totalPages: totalPages,
                lastRead: lastRead,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                Value<int> currentPosition = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<double> localOffset = const Value.absent(),
                Value<double> progressPercent = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> textOffset = const Value.absent(),
                Value<int> totalPages = const Value.absent(),
                Value<DateTime> lastRead = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                bookId: bookId,
                currentPosition: currentPosition,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                localOffset: localOffset,
                progressPercent: progressPercent,
                chapterId: chapterId,
                textOffset: textOffset,
                totalPages: totalPages,
                lastRead: lastRead,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTable,
      ReadingProgressData,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (
        ReadingProgressData,
        BaseReferences<_$AppDatabase, $ReadingProgressTable, ReadingProgressData>,
      ),
      ReadingProgressData,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required String bookId,
      required int chapterIndex,
      required int paragraphIndex,
      Value<double> localOffset,
      Value<String?> selectedText,
      Value<String?> note,
      Value<String?> highlightStyle,
      Value<String?> highlightColor,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<int> paragraphIndex,
      Value<double> localOffset,
      Value<String?> selectedText,
      Value<String?> note,
      Value<String?> highlightStyle,
      Value<String?> highlightColor,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$BookmarksTableFilterComposer extends Composer<_$AppDatabase, $BookmarksTable> {
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

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highlightStyle => $composableBuilder(
    column: $table.highlightStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highlightColor => $composableBuilder(
    column: $table.highlightColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer extends Composer<_$AppDatabase, $BookmarksTable> {
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

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highlightStyle => $composableBuilder(
    column: $table.highlightStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highlightColor => $composableBuilder(
    column: $table.highlightColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer extends Composer<_$AppDatabase, $BookmarksTable> {
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

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get highlightStyle => $composableBuilder(
    column: $table.highlightStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get highlightColor => $composableBuilder(
    column: $table.highlightColor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
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
          createFilteringComposer: () => $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<double> localOffset = const Value.absent(),
                Value<String?> selectedText = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> highlightStyle = const Value.absent(),
                Value<String?> highlightColor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                localOffset: localOffset,
                selectedText: selectedText,
                note: note,
                highlightStyle: highlightStyle,
                highlightColor: highlightColor,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int chapterIndex,
                required int paragraphIndex,
                Value<double> localOffset = const Value.absent(),
                Value<String?> selectedText = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> highlightStyle = const Value.absent(),
                Value<String?> highlightColor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                localOffset: localOffset,
                selectedText: selectedText,
                note: note,
                highlightStyle: highlightStyle,
                highlightColor: highlightColor,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
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
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      required String bookId,
      required int chapterIndex,
      required int paragraphIndex,
      Value<double> localOffset,
      required String content,
      Value<String> highlightColor,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<int> paragraphIndex,
      Value<double> localOffset,
      Value<String> content,
      Value<String> highlightColor,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
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

  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highlightColor => $composableBuilder(
    column: $table.highlightColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
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

  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highlightColor => $composableBuilder(
    column: $table.highlightColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
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

  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get localOffset => $composableBuilder(
    column: $table.localOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get highlightColor => $composableBuilder(
    column: $table.highlightColor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<double> localOffset = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> highlightColor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                localOffset: localOffset,
                content: content,
                highlightColor: highlightColor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int chapterIndex,
                required int paragraphIndex,
                Value<double> localOffset = const Value.absent(),
                required String content,
                Value<String> highlightColor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                localOffset: localOffset,
                content: content,
                highlightColor: highlightColor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$QuotesTableCreateCompanionBuilder =
    QuotesCompanion Function({
      required String id,
      required String bookId,
      required int chapterIndex,
      required int paragraphIndex,
      required String selectedText,
      Value<String?> beforeContext,
      Value<String?> afterContext,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$QuotesTableUpdateCompanionBuilder =
    QuotesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<int> paragraphIndex,
      Value<String> selectedText,
      Value<String?> beforeContext,
      Value<String?> afterContext,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$QuotesTableFilterComposer extends Composer<_$AppDatabase, $QuotesTable> {
  $$QuotesTableFilterComposer({
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

  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeContext => $composableBuilder(
    column: $table.beforeContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterContext => $composableBuilder(
    column: $table.afterContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuotesTableOrderingComposer extends Composer<_$AppDatabase, $QuotesTable> {
  $$QuotesTableOrderingComposer({
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

  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeContext => $composableBuilder(
    column: $table.beforeContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterContext => $composableBuilder(
    column: $table.afterContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuotesTableAnnotationComposer extends Composer<_$AppDatabase, $QuotesTable> {
  $$QuotesTableAnnotationComposer({
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

  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beforeContext => $composableBuilder(
    column: $table.beforeContext,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterContext => $composableBuilder(
    column: $table.afterContext,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QuotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuotesTable,
          Quote,
          $$QuotesTableFilterComposer,
          $$QuotesTableOrderingComposer,
          $$QuotesTableAnnotationComposer,
          $$QuotesTableCreateCompanionBuilder,
          $$QuotesTableUpdateCompanionBuilder,
          (Quote, BaseReferences<_$AppDatabase, $QuotesTable, Quote>),
          Quote,
          PrefetchHooks Function()
        > {
  $$QuotesTableTableManager(_$AppDatabase db, $QuotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$QuotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$QuotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<String> selectedText = const Value.absent(),
                Value<String?> beforeContext = const Value.absent(),
                Value<String?> afterContext = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuotesCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                selectedText: selectedText,
                beforeContext: beforeContext,
                afterContext: afterContext,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int chapterIndex,
                required int paragraphIndex,
                required String selectedText,
                Value<String?> beforeContext = const Value.absent(),
                Value<String?> afterContext = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuotesCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                selectedText: selectedText,
                beforeContext: beforeContext,
                afterContext: afterContext,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuotesTable,
      Quote,
      $$QuotesTableFilterComposer,
      $$QuotesTableOrderingComposer,
      $$QuotesTableAnnotationComposer,
      $$QuotesTableCreateCompanionBuilder,
      $$QuotesTableUpdateCompanionBuilder,
      (Quote, BaseReferences<_$AppDatabase, $QuotesTable, Quote>),
      Quote,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryTableCreateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      required String query,
      required String type,
      Value<DateTime> searchedAt,
    });
typedef $$SearchHistoryTableUpdateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<int> id,
      Value<String> query,
      Value<String> type,
      Value<DateTime> searchedAt,
    });

class $$SearchHistoryTableFilterComposer extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableFilterComposer({
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

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTableOrderingComposer extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTableAnnotationComposer extends Composer<_$AppDatabase, $SearchHistoryTable> {
  $$SearchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get searchedAt => $composableBuilder(
    column: $table.searchedAt,
    builder: (column) => column,
  );
}

class $$SearchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchHistoryTable,
          SearchHistoryData,
          $$SearchHistoryTableFilterComposer,
          $$SearchHistoryTableOrderingComposer,
          $$SearchHistoryTableAnnotationComposer,
          $$SearchHistoryTableCreateCompanionBuilder,
          $$SearchHistoryTableUpdateCompanionBuilder,
          (
            SearchHistoryData,
            BaseReferences<_$AppDatabase, $SearchHistoryTable, SearchHistoryData>,
          ),
          SearchHistoryData,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTableTableManager(_$AppDatabase db, $SearchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SearchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryCompanion(
                id: id,
                query: query,
                type: type,
                searchedAt: searchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String query,
                required String type,
                Value<DateTime> searchedAt = const Value.absent(),
              }) => SearchHistoryCompanion.insert(
                id: id,
                query: query,
                type: type,
                searchedAt: searchedAt,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchHistoryTable,
      SearchHistoryData,
      $$SearchHistoryTableFilterComposer,
      $$SearchHistoryTableOrderingComposer,
      $$SearchHistoryTableAnnotationComposer,
      $$SearchHistoryTableCreateCompanionBuilder,
      $$SearchHistoryTableUpdateCompanionBuilder,
      (
        SearchHistoryData,
        BaseReferences<_$AppDatabase, $SearchHistoryTable, SearchHistoryData>,
      ),
      SearchHistoryData,
      PrefetchHooks Function()
    >;
typedef $$CollectionsTableCreateCompanionBuilder =
    CollectionsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<List<String>> bookIds,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$CollectionsTableUpdateCompanionBuilder =
    CollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<List<String>> bookIds,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CollectionsTableFilterComposer extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get bookIds =>
      $composableBuilder(
        column: $table.bookIds,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionsTableOrderingComposer extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookIds => $composableBuilder(
    column: $table.bookIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionsTableAnnotationComposer extends Composer<_$AppDatabase, $CollectionsTable> {
  $$CollectionsTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get bookIds =>
      $composableBuilder(column: $table.bookIds, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionsTable,
          Collection,
          $$CollectionsTableFilterComposer,
          $$CollectionsTableOrderingComposer,
          $$CollectionsTableAnnotationComposer,
          $$CollectionsTableCreateCompanionBuilder,
          $$CollectionsTableUpdateCompanionBuilder,
          (
            Collection,
            BaseReferences<_$AppDatabase, $CollectionsTable, Collection>,
          ),
          Collection,
          PrefetchHooks Function()
        > {
  $$CollectionsTableTableManager(_$AppDatabase db, $CollectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<List<String>> bookIds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion(
                id: id,
                name: name,
                description: description,
                bookIds: bookIds,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<List<String>> bookIds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionsCompanion.insert(
                id: id,
                name: name,
                description: description,
                bookIds: bookIds,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionsTable,
      Collection,
      $$CollectionsTableFilterComposer,
      $$CollectionsTableOrderingComposer,
      $$CollectionsTableAnnotationComposer,
      $$CollectionsTableCreateCompanionBuilder,
      $$CollectionsTableUpdateCompanionBuilder,
      (
        Collection,
        BaseReferences<_$AppDatabase, $CollectionsTable, Collection>,
      ),
      Collection,
      PrefetchHooks Function()
    >;
typedef $$BookCollectionsTableCreateCompanionBuilder =
    BookCollectionsCompanion Function({
      required String bookId,
      required String collectionId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$BookCollectionsTableUpdateCompanionBuilder =
    BookCollectionsCompanion Function({
      Value<String> bookId,
      Value<String> collectionId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$BookCollectionsTableFilterComposer extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookCollectionsTable> {
  $$BookCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$BookCollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookCollectionsTable,
          BookCollection,
          $$BookCollectionsTableFilterComposer,
          $$BookCollectionsTableOrderingComposer,
          $$BookCollectionsTableAnnotationComposer,
          $$BookCollectionsTableCreateCompanionBuilder,
          $$BookCollectionsTableUpdateCompanionBuilder,
          (
            BookCollection,
            BaseReferences<_$AppDatabase, $BookCollectionsTable, BookCollection>,
          ),
          BookCollection,
          PrefetchHooks Function()
        > {
  $$BookCollectionsTableTableManager(
    _$AppDatabase db,
    $BookCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookCollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> collectionId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookCollectionsCompanion(
                bookId: bookId,
                collectionId: collectionId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String collectionId,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookCollectionsCompanion.insert(
                bookId: bookId,
                collectionId: collectionId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookCollectionsTable,
      BookCollection,
      $$BookCollectionsTableFilterComposer,
      $$BookCollectionsTableOrderingComposer,
      $$BookCollectionsTableAnnotationComposer,
      $$BookCollectionsTableCreateCompanionBuilder,
      $$BookCollectionsTableUpdateCompanionBuilder,
      (
        BookCollection,
        BaseReferences<_$AppDatabase, $BookCollectionsTable, BookCollection>,
      ),
      BookCollection,
      PrefetchHooks Function()
    >;
typedef $$ReadingSessionsTableCreateCompanionBuilder =
    ReadingSessionsCompanion Function({
      Value<int> id,
      required String bookId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> chaptersRead,
    });
typedef $$ReadingSessionsTableUpdateCompanionBuilder =
    ReadingSessionsCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> chaptersRead,
    });

class $$ReadingSessionsTableFilterComposer extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chaptersRead => $composableBuilder(
    column: $table.chaptersRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chaptersRead => $composableBuilder(
    column: $table.chaptersRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get chaptersRead => $composableBuilder(
    column: $table.chaptersRead,
    builder: (column) => column,
  );
}

class $$ReadingSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingSessionsTable,
          ReadingSession,
          $$ReadingSessionsTableFilterComposer,
          $$ReadingSessionsTableOrderingComposer,
          $$ReadingSessionsTableAnnotationComposer,
          $$ReadingSessionsTableCreateCompanionBuilder,
          $$ReadingSessionsTableUpdateCompanionBuilder,
          (
            ReadingSession,
            BaseReferences<_$AppDatabase, $ReadingSessionsTable, ReadingSession>,
          ),
          ReadingSession,
          PrefetchHooks Function()
        > {
  $$ReadingSessionsTableTableManager(
    _$AppDatabase db,
    $ReadingSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> chaptersRead = const Value.absent(),
              }) => ReadingSessionsCompanion(
                id: id,
                bookId: bookId,
                startedAt: startedAt,
                endedAt: endedAt,
                chaptersRead: chaptersRead,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> chaptersRead = const Value.absent(),
              }) => ReadingSessionsCompanion.insert(
                id: id,
                bookId: bookId,
                startedAt: startedAt,
                endedAt: endedAt,
                chaptersRead: chaptersRead,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingSessionsTable,
      ReadingSession,
      $$ReadingSessionsTableFilterComposer,
      $$ReadingSessionsTableOrderingComposer,
      $$ReadingSessionsTableAnnotationComposer,
      $$ReadingSessionsTableCreateCompanionBuilder,
      $$ReadingSessionsTableUpdateCompanionBuilder,
      (
        ReadingSession,
        BaseReferences<_$AppDatabase, $ReadingSessionsTable, ReadingSession>,
      ),
      ReadingSession,
      PrefetchHooks Function()
    >;
typedef $$PerBookSettingsTableCreateCompanionBuilder =
    PerBookSettingsCompanion Function({
      required String bookId,
      required String settingsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PerBookSettingsTableUpdateCompanionBuilder =
    PerBookSettingsCompanion Function({
      Value<String> bookId,
      Value<String> settingsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PerBookSettingsTableFilterComposer extends Composer<_$AppDatabase, $PerBookSettingsTable> {
  $$PerBookSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PerBookSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PerBookSettingsTable> {
  $$PerBookSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PerBookSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PerBookSettingsTable> {
  $$PerBookSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PerBookSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PerBookSettingsTable,
          PerBookSetting,
          $$PerBookSettingsTableFilterComposer,
          $$PerBookSettingsTableOrderingComposer,
          $$PerBookSettingsTableAnnotationComposer,
          $$PerBookSettingsTableCreateCompanionBuilder,
          $$PerBookSettingsTableUpdateCompanionBuilder,
          (
            PerBookSetting,
            BaseReferences<_$AppDatabase, $PerBookSettingsTable, PerBookSetting>,
          ),
          PerBookSetting,
          PrefetchHooks Function()
        > {
  $$PerBookSettingsTableTableManager(
    _$AppDatabase db,
    $PerBookSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PerBookSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PerBookSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PerBookSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> settingsJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PerBookSettingsCompanion(
                bookId: bookId,
                settingsJson: settingsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String settingsJson,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PerBookSettingsCompanion.insert(
                bookId: bookId,
                settingsJson: settingsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PerBookSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PerBookSettingsTable,
      PerBookSetting,
      $$PerBookSettingsTableFilterComposer,
      $$PerBookSettingsTableOrderingComposer,
      $$PerBookSettingsTableAnnotationComposer,
      $$PerBookSettingsTableCreateCompanionBuilder,
      $$PerBookSettingsTableUpdateCompanionBuilder,
      (
        PerBookSetting,
        BaseReferences<_$AppDatabase, $PerBookSettingsTable, PerBookSetting>,
      ),
      PerBookSetting,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      Value<String> color,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> color,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
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

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                color: color,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $$BookTagsTableCreateCompanionBuilder =
    BookTagsCompanion Function({
      required String bookId,
      required String tagId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$BookTagsTableUpdateCompanionBuilder =
    BookTagsCompanion Function({
      Value<String> bookId,
      Value<String> tagId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$BookTagsTableFilterComposer extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookTagsTableOrderingComposer extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookTagsTableAnnotationComposer extends Composer<_$AppDatabase, $BookTagsTable> {
  $$BookTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$BookTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookTagsTable,
          BookTag,
          $$BookTagsTableFilterComposer,
          $$BookTagsTableOrderingComposer,
          $$BookTagsTableAnnotationComposer,
          $$BookTagsTableCreateCompanionBuilder,
          $$BookTagsTableUpdateCompanionBuilder,
          (BookTag, BaseReferences<_$AppDatabase, $BookTagsTable, BookTag>),
          BookTag,
          PrefetchHooks Function()
        > {
  $$BookTagsTableTableManager(_$AppDatabase db, $BookTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$BookTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$BookTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookTagsCompanion(
                bookId: bookId,
                tagId: tagId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String tagId,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookTagsCompanion.insert(
                bookId: bookId,
                tagId: tagId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookTagsTable,
      BookTag,
      $$BookTagsTableFilterComposer,
      $$BookTagsTableOrderingComposer,
      $$BookTagsTableAnnotationComposer,
      $$BookTagsTableCreateCompanionBuilder,
      $$BookTagsTableUpdateCompanionBuilder,
      (BookTag, BaseReferences<_$AppDatabase, $BookTagsTable, BookTag>),
      BookTag,
      PrefetchHooks Function()
    >;
typedef $$ReadingTimeTableCreateCompanionBuilder =
    ReadingTimeCompanion Function({
      required String bookId,
      required DateTime date,
      Value<int> readingTimeSeconds,
      Value<int> pagesRead,
      Value<double> wpm,
      Value<int> wpmSessionCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ReadingTimeTableUpdateCompanionBuilder =
    ReadingTimeCompanion Function({
      Value<String> bookId,
      Value<DateTime> date,
      Value<int> readingTimeSeconds,
      Value<int> pagesRead,
      Value<double> wpm,
      Value<int> wpmSessionCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ReadingTimeTableFilterComposer extends Composer<_$AppDatabase, $ReadingTimeTable> {
  $$ReadingTimeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pagesRead => $composableBuilder(
    column: $table.pagesRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wpm => $composableBuilder(
    column: $table.wpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wpmSessionCount => $composableBuilder(
    column: $table.wpmSessionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingTimeTableOrderingComposer extends Composer<_$AppDatabase, $ReadingTimeTable> {
  $$ReadingTimeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pagesRead => $composableBuilder(
    column: $table.pagesRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wpm => $composableBuilder(
    column: $table.wpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wpmSessionCount => $composableBuilder(
    column: $table.wpmSessionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingTimeTableAnnotationComposer extends Composer<_$AppDatabase, $ReadingTimeTable> {
  $$ReadingTimeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pagesRead =>
      $composableBuilder(column: $table.pagesRead, builder: (column) => column);

  GeneratedColumn<double> get wpm =>
      $composableBuilder(column: $table.wpm, builder: (column) => column);

  GeneratedColumn<int> get wpmSessionCount => $composableBuilder(
    column: $table.wpmSessionCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReadingTimeTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingTimeTable,
          ReadingTimeData,
          $$ReadingTimeTableFilterComposer,
          $$ReadingTimeTableOrderingComposer,
          $$ReadingTimeTableAnnotationComposer,
          $$ReadingTimeTableCreateCompanionBuilder,
          $$ReadingTimeTableUpdateCompanionBuilder,
          (
            ReadingTimeData,
            BaseReferences<_$AppDatabase, $ReadingTimeTable, ReadingTimeData>,
          ),
          ReadingTimeData,
          PrefetchHooks Function()
        > {
  $$ReadingTimeTableTableManager(_$AppDatabase db, $ReadingTimeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ReadingTimeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ReadingTimeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingTimeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> readingTimeSeconds = const Value.absent(),
                Value<int> pagesRead = const Value.absent(),
                Value<double> wpm = const Value.absent(),
                Value<int> wpmSessionCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingTimeCompanion(
                bookId: bookId,
                date: date,
                readingTimeSeconds: readingTimeSeconds,
                pagesRead: pagesRead,
                wpm: wpm,
                wpmSessionCount: wpmSessionCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required DateTime date,
                Value<int> readingTimeSeconds = const Value.absent(),
                Value<int> pagesRead = const Value.absent(),
                Value<double> wpm = const Value.absent(),
                Value<int> wpmSessionCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingTimeCompanion.insert(
                bookId: bookId,
                date: date,
                readingTimeSeconds: readingTimeSeconds,
                pagesRead: pagesRead,
                wpm: wpm,
                wpmSessionCount: wpmSessionCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingTimeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingTimeTable,
      ReadingTimeData,
      $$ReadingTimeTableFilterComposer,
      $$ReadingTimeTableOrderingComposer,
      $$ReadingTimeTableAnnotationComposer,
      $$ReadingTimeTableCreateCompanionBuilder,
      $$ReadingTimeTableUpdateCompanionBuilder,
      (
        ReadingTimeData,
        BaseReferences<_$AppDatabase, $ReadingTimeTable, ReadingTimeData>,
      ),
      ReadingTimeData,
      PrefetchHooks Function()
    >;
typedef $$TextHighlightsTableCreateCompanionBuilder =
    TextHighlightsCompanion Function({
      required String id,
      required String bookId,
      required String chapterId,
      required int chapterIndex,
      required int blockIndex,
      required int startOffset,
      required int endOffset,
      required String selectedText,
      Value<String> color,
      Value<String> decoration,
      Value<String?> noteText,
      Value<bool> isOrphaned,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$TextHighlightsTableUpdateCompanionBuilder =
    TextHighlightsCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> chapterId,
      Value<int> chapterIndex,
      Value<int> blockIndex,
      Value<int> startOffset,
      Value<int> endOffset,
      Value<String> selectedText,
      Value<String> color,
      Value<String> decoration,
      Value<String?> noteText,
      Value<bool> isOrphaned,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$TextHighlightsTableFilterComposer extends Composer<_$AppDatabase, $TextHighlightsTable> {
  $$TextHighlightsTableFilterComposer({
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

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blockIndex => $composableBuilder(
    column: $table.blockIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decoration => $composableBuilder(
    column: $table.decoration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOrphaned => $composableBuilder(
    column: $table.isOrphaned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TextHighlightsTableOrderingComposer extends Composer<_$AppDatabase, $TextHighlightsTable> {
  $$TextHighlightsTableOrderingComposer({
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

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blockIndex => $composableBuilder(
    column: $table.blockIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decoration => $composableBuilder(
    column: $table.decoration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOrphaned => $composableBuilder(
    column: $table.isOrphaned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TextHighlightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TextHighlightsTable> {
  $$TextHighlightsTableAnnotationComposer({
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

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get blockIndex => $composableBuilder(
    column: $table.blockIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<String> get selectedText => $composableBuilder(
    column: $table.selectedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get decoration => $composableBuilder(
    column: $table.decoration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<bool> get isOrphaned => $composableBuilder(
    column: $table.isOrphaned,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TextHighlightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TextHighlightsTable,
          TextHighlight,
          $$TextHighlightsTableFilterComposer,
          $$TextHighlightsTableOrderingComposer,
          $$TextHighlightsTableAnnotationComposer,
          $$TextHighlightsTableCreateCompanionBuilder,
          $$TextHighlightsTableUpdateCompanionBuilder,
          (
            TextHighlight,
            BaseReferences<_$AppDatabase, $TextHighlightsTable, TextHighlight>,
          ),
          TextHighlight,
          PrefetchHooks Function()
        > {
  $$TextHighlightsTableTableManager(
    _$AppDatabase db,
    $TextHighlightsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TextHighlightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TextHighlightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TextHighlightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> blockIndex = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<String> selectedText = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> decoration = const Value.absent(),
                Value<String?> noteText = const Value.absent(),
                Value<bool> isOrphaned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextHighlightsCompanion(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                chapterIndex: chapterIndex,
                blockIndex: blockIndex,
                startOffset: startOffset,
                endOffset: endOffset,
                selectedText: selectedText,
                color: color,
                decoration: decoration,
                noteText: noteText,
                isOrphaned: isOrphaned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String chapterId,
                required int chapterIndex,
                required int blockIndex,
                required int startOffset,
                required int endOffset,
                required String selectedText,
                Value<String> color = const Value.absent(),
                Value<String> decoration = const Value.absent(),
                Value<String?> noteText = const Value.absent(),
                Value<bool> isOrphaned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TextHighlightsCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                chapterIndex: chapterIndex,
                blockIndex: blockIndex,
                startOffset: startOffset,
                endOffset: endOffset,
                selectedText: selectedText,
                color: color,
                decoration: decoration,
                noteText: noteText,
                isOrphaned: isOrphaned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TextHighlightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TextHighlightsTable,
      TextHighlight,
      $$TextHighlightsTableFilterComposer,
      $$TextHighlightsTableOrderingComposer,
      $$TextHighlightsTableAnnotationComposer,
      $$TextHighlightsTableCreateCompanionBuilder,
      $$TextHighlightsTableUpdateCompanionBuilder,
      (
        TextHighlight,
        BaseReferences<_$AppDatabase, $TextHighlightsTable, TextHighlight>,
      ),
      TextHighlight,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SavedBooksTableTableManager get savedBooks =>
      $$SavedBooksTableTableManager(_db, _db.savedBooks);
  $$AuthorsTableTableManager get authors => $$AuthorsTableTableManager(_db, _db.authors);
  $$SeriesTableTableManager get series => $$SeriesTableTableManager(_db, _db.series);
  $$BookSeriesTableTableManager get bookSeries =>
      $$BookSeriesTableTableManager(_db, _db.bookSeries);
  $$GenresTableTableManager get genres => $$GenresTableTableManager(_db, _db.genres);
  $$DownloadsTableTableManager get downloads => $$DownloadsTableTableManager(_db, _db.downloads);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$BookmarksTableTableManager get bookmarks => $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$NotesTableTableManager get notes => $$NotesTableTableManager(_db, _db.notes);
  $$QuotesTableTableManager get quotes => $$QuotesTableTableManager(_db, _db.quotes);
  $$SearchHistoryTableTableManager get searchHistory =>
      $$SearchHistoryTableTableManager(_db, _db.searchHistory);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db, _db.collections);
  $$BookCollectionsTableTableManager get bookCollections =>
      $$BookCollectionsTableTableManager(_db, _db.bookCollections);
  $$ReadingSessionsTableTableManager get readingSessions =>
      $$ReadingSessionsTableTableManager(_db, _db.readingSessions);
  $$PerBookSettingsTableTableManager get perBookSettings =>
      $$PerBookSettingsTableTableManager(_db, _db.perBookSettings);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$BookTagsTableTableManager get bookTags => $$BookTagsTableTableManager(_db, _db.bookTags);
  $$ReadingTimeTableTableManager get readingTime =>
      $$ReadingTimeTableTableManager(_db, _db.readingTime);
  $$TextHighlightsTableTableManager get textHighlights =>
      $$TextHighlightsTableTableManager(_db, _db.textHighlights);
}
