// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $WorldsTable extends Worlds with TableInfo<$WorldsTable, World> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorldsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportableMeta = const VerificationMeta(
    'exportable',
  );
  @override
  late final GeneratedColumn<bool> exportable = GeneratedColumn<bool>(
    'exportable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exportable" IN (0, 1))',
    ),
    clientDefault: () => true,
  );
  static const VerificationMeta _licenseMeta = const VerificationMeta(
    'license',
  );
  @override
  late final GeneratedColumn<String> license = GeneratedColumn<String>(
    'license',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => 'all-rights-reserved',
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
  static const VerificationMeta _sourceWorldIdMeta = const VerificationMeta(
    'sourceWorldId',
  );
  @override
  late final GeneratedColumn<String> sourceWorldId = GeneratedColumn<String>(
    'source_world_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestVersionMeta = const VerificationMeta(
    'latestVersion',
  );
  @override
  late final GeneratedColumn<int> latestVersion = GeneratedColumn<int>(
    'latest_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => 0,
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
    title,
    genre,
    summary,
    source,
    exportable,
    license,
    author,
    sourceWorldId,
    latestVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worlds';
  @override
  VerificationContext validateIntegrity(
    Insertable<World> instance, {
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
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    } else if (isInserting) {
      context.missing(_genreMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('exportable')) {
      context.handle(
        _exportableMeta,
        exportable.isAcceptableOrUnknown(data['exportable']!, _exportableMeta),
      );
    }
    if (data.containsKey('license')) {
      context.handle(
        _licenseMeta,
        license.isAcceptableOrUnknown(data['license']!, _licenseMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('source_world_id')) {
      context.handle(
        _sourceWorldIdMeta,
        sourceWorldId.isAcceptableOrUnknown(
          data['source_world_id']!,
          _sourceWorldIdMeta,
        ),
      );
    }
    if (data.containsKey('latest_version')) {
      context.handle(
        _latestVersionMeta,
        latestVersion.isAcceptableOrUnknown(
          data['latest_version']!,
          _latestVersionMeta,
        ),
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
  World map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return World(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      exportable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exportable'],
      )!,
      license: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      sourceWorldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_world_id'],
      ),
      latestVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_version'],
      )!,
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
  $WorldsTable createAlias(String alias) {
    return $WorldsTable(attachedDatabase, alias);
  }
}

class World extends DataClass implements Insertable<World> {
  final String id;
  final String title;
  final String genre;
  final String? summary;
  final String source;
  final bool exportable;
  final String license;
  final String? author;
  final String? sourceWorldId;
  final int latestVersion;
  final int createdAt;
  final int updatedAt;
  const World({
    required this.id,
    required this.title,
    required this.genre,
    this.summary,
    required this.source,
    required this.exportable,
    required this.license,
    this.author,
    this.sourceWorldId,
    required this.latestVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['genre'] = Variable<String>(genre);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['source'] = Variable<String>(source);
    map['exportable'] = Variable<bool>(exportable);
    map['license'] = Variable<String>(license);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || sourceWorldId != null) {
      map['source_world_id'] = Variable<String>(sourceWorldId);
    }
    map['latest_version'] = Variable<int>(latestVersion);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  WorldsCompanion toCompanion(bool nullToAbsent) {
    return WorldsCompanion(
      id: Value(id),
      title: Value(title),
      genre: Value(genre),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      source: Value(source),
      exportable: Value(exportable),
      license: Value(license),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      sourceWorldId: sourceWorldId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceWorldId),
      latestVersion: Value(latestVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory World.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return World(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      genre: serializer.fromJson<String>(json['genre']),
      summary: serializer.fromJson<String?>(json['summary']),
      source: serializer.fromJson<String>(json['source']),
      exportable: serializer.fromJson<bool>(json['exportable']),
      license: serializer.fromJson<String>(json['license']),
      author: serializer.fromJson<String?>(json['author']),
      sourceWorldId: serializer.fromJson<String?>(json['sourceWorldId']),
      latestVersion: serializer.fromJson<int>(json['latestVersion']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'genre': serializer.toJson<String>(genre),
      'summary': serializer.toJson<String?>(summary),
      'source': serializer.toJson<String>(source),
      'exportable': serializer.toJson<bool>(exportable),
      'license': serializer.toJson<String>(license),
      'author': serializer.toJson<String?>(author),
      'sourceWorldId': serializer.toJson<String?>(sourceWorldId),
      'latestVersion': serializer.toJson<int>(latestVersion),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  World copyWith({
    String? id,
    String? title,
    String? genre,
    Value<String?> summary = const Value.absent(),
    String? source,
    bool? exportable,
    String? license,
    Value<String?> author = const Value.absent(),
    Value<String?> sourceWorldId = const Value.absent(),
    int? latestVersion,
    int? createdAt,
    int? updatedAt,
  }) => World(
    id: id ?? this.id,
    title: title ?? this.title,
    genre: genre ?? this.genre,
    summary: summary.present ? summary.value : this.summary,
    source: source ?? this.source,
    exportable: exportable ?? this.exportable,
    license: license ?? this.license,
    author: author.present ? author.value : this.author,
    sourceWorldId: sourceWorldId.present
        ? sourceWorldId.value
        : this.sourceWorldId,
    latestVersion: latestVersion ?? this.latestVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  World copyWithCompanion(WorldsCompanion data) {
    return World(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      genre: data.genre.present ? data.genre.value : this.genre,
      summary: data.summary.present ? data.summary.value : this.summary,
      source: data.source.present ? data.source.value : this.source,
      exportable: data.exportable.present
          ? data.exportable.value
          : this.exportable,
      license: data.license.present ? data.license.value : this.license,
      author: data.author.present ? data.author.value : this.author,
      sourceWorldId: data.sourceWorldId.present
          ? data.sourceWorldId.value
          : this.sourceWorldId,
      latestVersion: data.latestVersion.present
          ? data.latestVersion.value
          : this.latestVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('World(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('genre: $genre, ')
          ..write('summary: $summary, ')
          ..write('source: $source, ')
          ..write('exportable: $exportable, ')
          ..write('license: $license, ')
          ..write('author: $author, ')
          ..write('sourceWorldId: $sourceWorldId, ')
          ..write('latestVersion: $latestVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    genre,
    summary,
    source,
    exportable,
    license,
    author,
    sourceWorldId,
    latestVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is World &&
          other.id == this.id &&
          other.title == this.title &&
          other.genre == this.genre &&
          other.summary == this.summary &&
          other.source == this.source &&
          other.exportable == this.exportable &&
          other.license == this.license &&
          other.author == this.author &&
          other.sourceWorldId == this.sourceWorldId &&
          other.latestVersion == this.latestVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorldsCompanion extends UpdateCompanion<World> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> genre;
  final Value<String?> summary;
  final Value<String> source;
  final Value<bool> exportable;
  final Value<String> license;
  final Value<String?> author;
  final Value<String?> sourceWorldId;
  final Value<int> latestVersion;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const WorldsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.genre = const Value.absent(),
    this.summary = const Value.absent(),
    this.source = const Value.absent(),
    this.exportable = const Value.absent(),
    this.license = const Value.absent(),
    this.author = const Value.absent(),
    this.sourceWorldId = const Value.absent(),
    this.latestVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorldsCompanion.insert({
    required String id,
    required String title,
    required String genre,
    this.summary = const Value.absent(),
    required String source,
    this.exportable = const Value.absent(),
    this.license = const Value.absent(),
    this.author = const Value.absent(),
    this.sourceWorldId = const Value.absent(),
    this.latestVersion = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       genre = Value(genre),
       source = Value(source),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<World> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? genre,
    Expression<String>? summary,
    Expression<String>? source,
    Expression<bool>? exportable,
    Expression<String>? license,
    Expression<String>? author,
    Expression<String>? sourceWorldId,
    Expression<int>? latestVersion,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (genre != null) 'genre': genre,
      if (summary != null) 'summary': summary,
      if (source != null) 'source': source,
      if (exportable != null) 'exportable': exportable,
      if (license != null) 'license': license,
      if (author != null) 'author': author,
      if (sourceWorldId != null) 'source_world_id': sourceWorldId,
      if (latestVersion != null) 'latest_version': latestVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorldsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? genre,
    Value<String?>? summary,
    Value<String>? source,
    Value<bool>? exportable,
    Value<String>? license,
    Value<String?>? author,
    Value<String?>? sourceWorldId,
    Value<int>? latestVersion,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorldsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      summary: summary ?? this.summary,
      source: source ?? this.source,
      exportable: exportable ?? this.exportable,
      license: license ?? this.license,
      author: author ?? this.author,
      sourceWorldId: sourceWorldId ?? this.sourceWorldId,
      latestVersion: latestVersion ?? this.latestVersion,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (exportable.present) {
      map['exportable'] = Variable<bool>(exportable.value);
    }
    if (license.present) {
      map['license'] = Variable<String>(license.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (sourceWorldId.present) {
      map['source_world_id'] = Variable<String>(sourceWorldId.value);
    }
    if (latestVersion.present) {
      map['latest_version'] = Variable<int>(latestVersion.value);
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
    return (StringBuffer('WorldsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('genre: $genre, ')
          ..write('summary: $summary, ')
          ..write('source: $source, ')
          ..write('exportable: $exportable, ')
          ..write('license: $license, ')
          ..write('author: $author, ')
          ..write('sourceWorldId: $sourceWorldId, ')
          ..write('latestVersion: $latestVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorldVersionsTable extends WorldVersions
    with TableInfo<$WorldVersionsTable, WorldVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorldVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worldIdMeta = const VerificationMeta(
    'worldId',
  );
  @override
  late final GeneratedColumn<String> worldId = GeneratedColumn<String>(
    'world_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bibleMeta = const VerificationMeta('bible');
  @override
  late final GeneratedColumn<String> bible = GeneratedColumn<String>(
    'bible',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _identitiesMeta = const VerificationMeta(
    'identities',
  );
  @override
  late final GeneratedColumn<String> identities = GeneratedColumn<String>(
    'identities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedsMeta = const VerificationMeta('seeds');
  @override
  late final GeneratedColumn<String> seeds = GeneratedColumn<String>(
    'seeds',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    worldId,
    version,
    bible,
    identities,
    seeds,
    checksum,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'world_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorldVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('world_id')) {
      context.handle(
        _worldIdMeta,
        worldId.isAcceptableOrUnknown(data['world_id']!, _worldIdMeta),
      );
    } else if (isInserting) {
      context.missing(_worldIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('bible')) {
      context.handle(
        _bibleMeta,
        bible.isAcceptableOrUnknown(data['bible']!, _bibleMeta),
      );
    } else if (isInserting) {
      context.missing(_bibleMeta);
    }
    if (data.containsKey('identities')) {
      context.handle(
        _identitiesMeta,
        identities.isAcceptableOrUnknown(data['identities']!, _identitiesMeta),
      );
    } else if (isInserting) {
      context.missing(_identitiesMeta);
    }
    if (data.containsKey('seeds')) {
      context.handle(
        _seedsMeta,
        seeds.isAcceptableOrUnknown(data['seeds']!, _seedsMeta),
      );
    } else if (isInserting) {
      context.missing(_seedsMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
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
  WorldVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorldVersion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      worldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}world_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      bible: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bible'],
      )!,
      identities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identities'],
      )!,
      seeds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seeds'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorldVersionsTable createAlias(String alias) {
    return $WorldVersionsTable(attachedDatabase, alias);
  }
}

class WorldVersion extends DataClass implements Insertable<WorldVersion> {
  final String id;
  final String worldId;
  final int version;
  final String bible;
  final String identities;
  final String seeds;
  final String checksum;
  final int createdAt;
  const WorldVersion({
    required this.id,
    required this.worldId,
    required this.version,
    required this.bible,
    required this.identities,
    required this.seeds,
    required this.checksum,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['world_id'] = Variable<String>(worldId);
    map['version'] = Variable<int>(version);
    map['bible'] = Variable<String>(bible);
    map['identities'] = Variable<String>(identities);
    map['seeds'] = Variable<String>(seeds);
    map['checksum'] = Variable<String>(checksum);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  WorldVersionsCompanion toCompanion(bool nullToAbsent) {
    return WorldVersionsCompanion(
      id: Value(id),
      worldId: Value(worldId),
      version: Value(version),
      bible: Value(bible),
      identities: Value(identities),
      seeds: Value(seeds),
      checksum: Value(checksum),
      createdAt: Value(createdAt),
    );
  }

  factory WorldVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorldVersion(
      id: serializer.fromJson<String>(json['id']),
      worldId: serializer.fromJson<String>(json['worldId']),
      version: serializer.fromJson<int>(json['version']),
      bible: serializer.fromJson<String>(json['bible']),
      identities: serializer.fromJson<String>(json['identities']),
      seeds: serializer.fromJson<String>(json['seeds']),
      checksum: serializer.fromJson<String>(json['checksum']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'worldId': serializer.toJson<String>(worldId),
      'version': serializer.toJson<int>(version),
      'bible': serializer.toJson<String>(bible),
      'identities': serializer.toJson<String>(identities),
      'seeds': serializer.toJson<String>(seeds),
      'checksum': serializer.toJson<String>(checksum),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  WorldVersion copyWith({
    String? id,
    String? worldId,
    int? version,
    String? bible,
    String? identities,
    String? seeds,
    String? checksum,
    int? createdAt,
  }) => WorldVersion(
    id: id ?? this.id,
    worldId: worldId ?? this.worldId,
    version: version ?? this.version,
    bible: bible ?? this.bible,
    identities: identities ?? this.identities,
    seeds: seeds ?? this.seeds,
    checksum: checksum ?? this.checksum,
    createdAt: createdAt ?? this.createdAt,
  );
  WorldVersion copyWithCompanion(WorldVersionsCompanion data) {
    return WorldVersion(
      id: data.id.present ? data.id.value : this.id,
      worldId: data.worldId.present ? data.worldId.value : this.worldId,
      version: data.version.present ? data.version.value : this.version,
      bible: data.bible.present ? data.bible.value : this.bible,
      identities: data.identities.present
          ? data.identities.value
          : this.identities,
      seeds: data.seeds.present ? data.seeds.value : this.seeds,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorldVersion(')
          ..write('id: $id, ')
          ..write('worldId: $worldId, ')
          ..write('version: $version, ')
          ..write('bible: $bible, ')
          ..write('identities: $identities, ')
          ..write('seeds: $seeds, ')
          ..write('checksum: $checksum, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    worldId,
    version,
    bible,
    identities,
    seeds,
    checksum,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorldVersion &&
          other.id == this.id &&
          other.worldId == this.worldId &&
          other.version == this.version &&
          other.bible == this.bible &&
          other.identities == this.identities &&
          other.seeds == this.seeds &&
          other.checksum == this.checksum &&
          other.createdAt == this.createdAt);
}

class WorldVersionsCompanion extends UpdateCompanion<WorldVersion> {
  final Value<String> id;
  final Value<String> worldId;
  final Value<int> version;
  final Value<String> bible;
  final Value<String> identities;
  final Value<String> seeds;
  final Value<String> checksum;
  final Value<int> createdAt;
  final Value<int> rowid;
  const WorldVersionsCompanion({
    this.id = const Value.absent(),
    this.worldId = const Value.absent(),
    this.version = const Value.absent(),
    this.bible = const Value.absent(),
    this.identities = const Value.absent(),
    this.seeds = const Value.absent(),
    this.checksum = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorldVersionsCompanion.insert({
    required String id,
    required String worldId,
    required int version,
    required String bible,
    required String identities,
    required String seeds,
    required String checksum,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       worldId = Value(worldId),
       version = Value(version),
       bible = Value(bible),
       identities = Value(identities),
       seeds = Value(seeds),
       checksum = Value(checksum),
       createdAt = Value(createdAt);
  static Insertable<WorldVersion> custom({
    Expression<String>? id,
    Expression<String>? worldId,
    Expression<int>? version,
    Expression<String>? bible,
    Expression<String>? identities,
    Expression<String>? seeds,
    Expression<String>? checksum,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (worldId != null) 'world_id': worldId,
      if (version != null) 'version': version,
      if (bible != null) 'bible': bible,
      if (identities != null) 'identities': identities,
      if (seeds != null) 'seeds': seeds,
      if (checksum != null) 'checksum': checksum,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorldVersionsCompanion copyWith({
    Value<String>? id,
    Value<String>? worldId,
    Value<int>? version,
    Value<String>? bible,
    Value<String>? identities,
    Value<String>? seeds,
    Value<String>? checksum,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return WorldVersionsCompanion(
      id: id ?? this.id,
      worldId: worldId ?? this.worldId,
      version: version ?? this.version,
      bible: bible ?? this.bible,
      identities: identities ?? this.identities,
      seeds: seeds ?? this.seeds,
      checksum: checksum ?? this.checksum,
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
    if (worldId.present) {
      map['world_id'] = Variable<String>(worldId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (bible.present) {
      map['bible'] = Variable<String>(bible.value);
    }
    if (identities.present) {
      map['identities'] = Variable<String>(identities.value);
    }
    if (seeds.present) {
      map['seeds'] = Variable<String>(seeds.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
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
    return (StringBuffer('WorldVersionsCompanion(')
          ..write('id: $id, ')
          ..write('worldId: $worldId, ')
          ..write('version: $version, ')
          ..write('bible: $bible, ')
          ..write('identities: $identities, ')
          ..write('seeds: $seeds, ')
          ..write('checksum: $checksum, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunsTable extends Runs with TableInfo<$RunsTable, Run> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worldIdMeta = const VerificationMeta(
    'worldId',
  );
  @override
  late final GeneratedColumn<String> worldId = GeneratedColumn<String>(
    'world_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worldVersionMeta = const VerificationMeta(
    'worldVersion',
  );
  @override
  late final GeneratedColumn<int> worldVersion = GeneratedColumn<int>(
    'world_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _identityIdMeta = const VerificationMeta(
    'identityId',
  );
  @override
  late final GeneratedColumn<String> identityId = GeneratedColumn<String>(
    'identity_id',
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
    clientDefault: () => 'active',
  );
  static const VerificationMeta _chapterMeta = const VerificationMeta(
    'chapter',
  );
  @override
  late final GeneratedColumn<int> chapter = GeneratedColumn<int>(
    'chapter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => 1,
  );
  static const VerificationMeta _turnNoMeta = const VerificationMeta('turnNo');
  @override
  late final GeneratedColumn<int> turnNo = GeneratedColumn<int>(
    'turn_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => 0,
  );
  static const VerificationMeta _headSnapshotIdMeta = const VerificationMeta(
    'headSnapshotId',
  );
  @override
  late final GeneratedColumn<String> headSnapshotId = GeneratedColumn<String>(
    'head_snapshot_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endingIdMeta = const VerificationMeta(
    'endingId',
  );
  @override
  late final GeneratedColumn<String> endingId = GeneratedColumn<String>(
    'ending_id',
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
    worldId,
    worldVersion,
    identityId,
    status,
    chapter,
    turnNo,
    headSnapshotId,
    endingId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Run> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('world_id')) {
      context.handle(
        _worldIdMeta,
        worldId.isAcceptableOrUnknown(data['world_id']!, _worldIdMeta),
      );
    } else if (isInserting) {
      context.missing(_worldIdMeta);
    }
    if (data.containsKey('world_version')) {
      context.handle(
        _worldVersionMeta,
        worldVersion.isAcceptableOrUnknown(
          data['world_version']!,
          _worldVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_worldVersionMeta);
    }
    if (data.containsKey('identity_id')) {
      context.handle(
        _identityIdMeta,
        identityId.isAcceptableOrUnknown(data['identity_id']!, _identityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_identityIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('chapter')) {
      context.handle(
        _chapterMeta,
        chapter.isAcceptableOrUnknown(data['chapter']!, _chapterMeta),
      );
    }
    if (data.containsKey('turn_no')) {
      context.handle(
        _turnNoMeta,
        turnNo.isAcceptableOrUnknown(data['turn_no']!, _turnNoMeta),
      );
    }
    if (data.containsKey('head_snapshot_id')) {
      context.handle(
        _headSnapshotIdMeta,
        headSnapshotId.isAcceptableOrUnknown(
          data['head_snapshot_id']!,
          _headSnapshotIdMeta,
        ),
      );
    }
    if (data.containsKey('ending_id')) {
      context.handle(
        _endingIdMeta,
        endingId.isAcceptableOrUnknown(data['ending_id']!, _endingIdMeta),
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
  Run map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Run(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      worldId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}world_id'],
      )!,
      worldVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}world_version'],
      )!,
      identityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      chapter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter'],
      )!,
      turnNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn_no'],
      )!,
      headSnapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}head_snapshot_id'],
      ),
      endingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ending_id'],
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
  $RunsTable createAlias(String alias) {
    return $RunsTable(attachedDatabase, alias);
  }
}

class Run extends DataClass implements Insertable<Run> {
  final String id;
  final String worldId;
  final int worldVersion;
  final String identityId;
  final String status;
  final int chapter;
  final int turnNo;
  final String? headSnapshotId;
  final String? endingId;
  final int createdAt;
  final int updatedAt;
  const Run({
    required this.id,
    required this.worldId,
    required this.worldVersion,
    required this.identityId,
    required this.status,
    required this.chapter,
    required this.turnNo,
    this.headSnapshotId,
    this.endingId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['world_id'] = Variable<String>(worldId);
    map['world_version'] = Variable<int>(worldVersion);
    map['identity_id'] = Variable<String>(identityId);
    map['status'] = Variable<String>(status);
    map['chapter'] = Variable<int>(chapter);
    map['turn_no'] = Variable<int>(turnNo);
    if (!nullToAbsent || headSnapshotId != null) {
      map['head_snapshot_id'] = Variable<String>(headSnapshotId);
    }
    if (!nullToAbsent || endingId != null) {
      map['ending_id'] = Variable<String>(endingId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  RunsCompanion toCompanion(bool nullToAbsent) {
    return RunsCompanion(
      id: Value(id),
      worldId: Value(worldId),
      worldVersion: Value(worldVersion),
      identityId: Value(identityId),
      status: Value(status),
      chapter: Value(chapter),
      turnNo: Value(turnNo),
      headSnapshotId: headSnapshotId == null && nullToAbsent
          ? const Value.absent()
          : Value(headSnapshotId),
      endingId: endingId == null && nullToAbsent
          ? const Value.absent()
          : Value(endingId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Run.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Run(
      id: serializer.fromJson<String>(json['id']),
      worldId: serializer.fromJson<String>(json['worldId']),
      worldVersion: serializer.fromJson<int>(json['worldVersion']),
      identityId: serializer.fromJson<String>(json['identityId']),
      status: serializer.fromJson<String>(json['status']),
      chapter: serializer.fromJson<int>(json['chapter']),
      turnNo: serializer.fromJson<int>(json['turnNo']),
      headSnapshotId: serializer.fromJson<String?>(json['headSnapshotId']),
      endingId: serializer.fromJson<String?>(json['endingId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'worldId': serializer.toJson<String>(worldId),
      'worldVersion': serializer.toJson<int>(worldVersion),
      'identityId': serializer.toJson<String>(identityId),
      'status': serializer.toJson<String>(status),
      'chapter': serializer.toJson<int>(chapter),
      'turnNo': serializer.toJson<int>(turnNo),
      'headSnapshotId': serializer.toJson<String?>(headSnapshotId),
      'endingId': serializer.toJson<String?>(endingId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Run copyWith({
    String? id,
    String? worldId,
    int? worldVersion,
    String? identityId,
    String? status,
    int? chapter,
    int? turnNo,
    Value<String?> headSnapshotId = const Value.absent(),
    Value<String?> endingId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => Run(
    id: id ?? this.id,
    worldId: worldId ?? this.worldId,
    worldVersion: worldVersion ?? this.worldVersion,
    identityId: identityId ?? this.identityId,
    status: status ?? this.status,
    chapter: chapter ?? this.chapter,
    turnNo: turnNo ?? this.turnNo,
    headSnapshotId: headSnapshotId.present
        ? headSnapshotId.value
        : this.headSnapshotId,
    endingId: endingId.present ? endingId.value : this.endingId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Run copyWithCompanion(RunsCompanion data) {
    return Run(
      id: data.id.present ? data.id.value : this.id,
      worldId: data.worldId.present ? data.worldId.value : this.worldId,
      worldVersion: data.worldVersion.present
          ? data.worldVersion.value
          : this.worldVersion,
      identityId: data.identityId.present
          ? data.identityId.value
          : this.identityId,
      status: data.status.present ? data.status.value : this.status,
      chapter: data.chapter.present ? data.chapter.value : this.chapter,
      turnNo: data.turnNo.present ? data.turnNo.value : this.turnNo,
      headSnapshotId: data.headSnapshotId.present
          ? data.headSnapshotId.value
          : this.headSnapshotId,
      endingId: data.endingId.present ? data.endingId.value : this.endingId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Run(')
          ..write('id: $id, ')
          ..write('worldId: $worldId, ')
          ..write('worldVersion: $worldVersion, ')
          ..write('identityId: $identityId, ')
          ..write('status: $status, ')
          ..write('chapter: $chapter, ')
          ..write('turnNo: $turnNo, ')
          ..write('headSnapshotId: $headSnapshotId, ')
          ..write('endingId: $endingId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    worldId,
    worldVersion,
    identityId,
    status,
    chapter,
    turnNo,
    headSnapshotId,
    endingId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Run &&
          other.id == this.id &&
          other.worldId == this.worldId &&
          other.worldVersion == this.worldVersion &&
          other.identityId == this.identityId &&
          other.status == this.status &&
          other.chapter == this.chapter &&
          other.turnNo == this.turnNo &&
          other.headSnapshotId == this.headSnapshotId &&
          other.endingId == this.endingId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RunsCompanion extends UpdateCompanion<Run> {
  final Value<String> id;
  final Value<String> worldId;
  final Value<int> worldVersion;
  final Value<String> identityId;
  final Value<String> status;
  final Value<int> chapter;
  final Value<int> turnNo;
  final Value<String?> headSnapshotId;
  final Value<String?> endingId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const RunsCompanion({
    this.id = const Value.absent(),
    this.worldId = const Value.absent(),
    this.worldVersion = const Value.absent(),
    this.identityId = const Value.absent(),
    this.status = const Value.absent(),
    this.chapter = const Value.absent(),
    this.turnNo = const Value.absent(),
    this.headSnapshotId = const Value.absent(),
    this.endingId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunsCompanion.insert({
    required String id,
    required String worldId,
    required int worldVersion,
    required String identityId,
    this.status = const Value.absent(),
    this.chapter = const Value.absent(),
    this.turnNo = const Value.absent(),
    this.headSnapshotId = const Value.absent(),
    this.endingId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       worldId = Value(worldId),
       worldVersion = Value(worldVersion),
       identityId = Value(identityId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Run> custom({
    Expression<String>? id,
    Expression<String>? worldId,
    Expression<int>? worldVersion,
    Expression<String>? identityId,
    Expression<String>? status,
    Expression<int>? chapter,
    Expression<int>? turnNo,
    Expression<String>? headSnapshotId,
    Expression<String>? endingId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (worldId != null) 'world_id': worldId,
      if (worldVersion != null) 'world_version': worldVersion,
      if (identityId != null) 'identity_id': identityId,
      if (status != null) 'status': status,
      if (chapter != null) 'chapter': chapter,
      if (turnNo != null) 'turn_no': turnNo,
      if (headSnapshotId != null) 'head_snapshot_id': headSnapshotId,
      if (endingId != null) 'ending_id': endingId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunsCompanion copyWith({
    Value<String>? id,
    Value<String>? worldId,
    Value<int>? worldVersion,
    Value<String>? identityId,
    Value<String>? status,
    Value<int>? chapter,
    Value<int>? turnNo,
    Value<String?>? headSnapshotId,
    Value<String?>? endingId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return RunsCompanion(
      id: id ?? this.id,
      worldId: worldId ?? this.worldId,
      worldVersion: worldVersion ?? this.worldVersion,
      identityId: identityId ?? this.identityId,
      status: status ?? this.status,
      chapter: chapter ?? this.chapter,
      turnNo: turnNo ?? this.turnNo,
      headSnapshotId: headSnapshotId ?? this.headSnapshotId,
      endingId: endingId ?? this.endingId,
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
    if (worldId.present) {
      map['world_id'] = Variable<String>(worldId.value);
    }
    if (worldVersion.present) {
      map['world_version'] = Variable<int>(worldVersion.value);
    }
    if (identityId.present) {
      map['identity_id'] = Variable<String>(identityId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (chapter.present) {
      map['chapter'] = Variable<int>(chapter.value);
    }
    if (turnNo.present) {
      map['turn_no'] = Variable<int>(turnNo.value);
    }
    if (headSnapshotId.present) {
      map['head_snapshot_id'] = Variable<String>(headSnapshotId.value);
    }
    if (endingId.present) {
      map['ending_id'] = Variable<String>(endingId.value);
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
    return (StringBuffer('RunsCompanion(')
          ..write('id: $id, ')
          ..write('worldId: $worldId, ')
          ..write('worldVersion: $worldVersion, ')
          ..write('identityId: $identityId, ')
          ..write('status: $status, ')
          ..write('chapter: $chapter, ')
          ..write('turnNo: $turnNo, ')
          ..write('headSnapshotId: $headSnapshotId, ')
          ..write('endingId: $endingId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunSnapshotsTable extends RunSnapshots
    with TableInfo<$RunSnapshotsTable, RunSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turnNoMeta = const VerificationMeta('turnNo');
  @override
  late final GeneratedColumn<int> turnNo = GeneratedColumn<int>(
    'turn_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterMeta = const VerificationMeta(
    'chapter',
  );
  @override
  late final GeneratedColumn<int> chapter = GeneratedColumn<int>(
    'chapter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentSnapshotIdMeta = const VerificationMeta(
    'parentSnapshotId',
  );
  @override
  late final GeneratedColumn<String> parentSnapshotId = GeneratedColumn<String>(
    'parent_snapshot_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentRunIdMeta = const VerificationMeta(
    'parentRunId',
  );
  @override
  late final GeneratedColumn<String> parentRunId = GeneratedColumn<String>(
    'parent_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoryMeta = const VerificationMeta('memory');
  @override
  late final GeneratedColumn<String> memory = GeneratedColumn<String>(
    'memory',
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
    runId,
    turnNo,
    chapter,
    parentSnapshotId,
    parentRunId,
    state,
    memory,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('turn_no')) {
      context.handle(
        _turnNoMeta,
        turnNo.isAcceptableOrUnknown(data['turn_no']!, _turnNoMeta),
      );
    } else if (isInserting) {
      context.missing(_turnNoMeta);
    }
    if (data.containsKey('chapter')) {
      context.handle(
        _chapterMeta,
        chapter.isAcceptableOrUnknown(data['chapter']!, _chapterMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterMeta);
    }
    if (data.containsKey('parent_snapshot_id')) {
      context.handle(
        _parentSnapshotIdMeta,
        parentSnapshotId.isAcceptableOrUnknown(
          data['parent_snapshot_id']!,
          _parentSnapshotIdMeta,
        ),
      );
    }
    if (data.containsKey('parent_run_id')) {
      context.handle(
        _parentRunIdMeta,
        parentRunId.isAcceptableOrUnknown(
          data['parent_run_id']!,
          _parentRunIdMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('memory')) {
      context.handle(
        _memoryMeta,
        memory.isAcceptableOrUnknown(data['memory']!, _memoryMeta),
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
  RunSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      turnNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn_no'],
      )!,
      chapter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter'],
      )!,
      parentSnapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_snapshot_id'],
      ),
      parentRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_run_id'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      memory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RunSnapshotsTable createAlias(String alias) {
    return $RunSnapshotsTable(attachedDatabase, alias);
  }
}

class RunSnapshot extends DataClass implements Insertable<RunSnapshot> {
  final String id;
  final String runId;
  final int turnNo;
  final int chapter;
  final String? parentSnapshotId;
  final String? parentRunId;
  final String state;
  final String? memory;
  final int createdAt;
  const RunSnapshot({
    required this.id,
    required this.runId,
    required this.turnNo,
    required this.chapter,
    this.parentSnapshotId,
    this.parentRunId,
    required this.state,
    this.memory,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['turn_no'] = Variable<int>(turnNo);
    map['chapter'] = Variable<int>(chapter);
    if (!nullToAbsent || parentSnapshotId != null) {
      map['parent_snapshot_id'] = Variable<String>(parentSnapshotId);
    }
    if (!nullToAbsent || parentRunId != null) {
      map['parent_run_id'] = Variable<String>(parentRunId);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || memory != null) {
      map['memory'] = Variable<String>(memory);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  RunSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return RunSnapshotsCompanion(
      id: Value(id),
      runId: Value(runId),
      turnNo: Value(turnNo),
      chapter: Value(chapter),
      parentSnapshotId: parentSnapshotId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSnapshotId),
      parentRunId: parentRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentRunId),
      state: Value(state),
      memory: memory == null && nullToAbsent
          ? const Value.absent()
          : Value(memory),
      createdAt: Value(createdAt),
    );
  }

  factory RunSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunSnapshot(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      turnNo: serializer.fromJson<int>(json['turnNo']),
      chapter: serializer.fromJson<int>(json['chapter']),
      parentSnapshotId: serializer.fromJson<String?>(json['parentSnapshotId']),
      parentRunId: serializer.fromJson<String?>(json['parentRunId']),
      state: serializer.fromJson<String>(json['state']),
      memory: serializer.fromJson<String?>(json['memory']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'turnNo': serializer.toJson<int>(turnNo),
      'chapter': serializer.toJson<int>(chapter),
      'parentSnapshotId': serializer.toJson<String?>(parentSnapshotId),
      'parentRunId': serializer.toJson<String?>(parentRunId),
      'state': serializer.toJson<String>(state),
      'memory': serializer.toJson<String?>(memory),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  RunSnapshot copyWith({
    String? id,
    String? runId,
    int? turnNo,
    int? chapter,
    Value<String?> parentSnapshotId = const Value.absent(),
    Value<String?> parentRunId = const Value.absent(),
    String? state,
    Value<String?> memory = const Value.absent(),
    int? createdAt,
  }) => RunSnapshot(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    turnNo: turnNo ?? this.turnNo,
    chapter: chapter ?? this.chapter,
    parentSnapshotId: parentSnapshotId.present
        ? parentSnapshotId.value
        : this.parentSnapshotId,
    parentRunId: parentRunId.present ? parentRunId.value : this.parentRunId,
    state: state ?? this.state,
    memory: memory.present ? memory.value : this.memory,
    createdAt: createdAt ?? this.createdAt,
  );
  RunSnapshot copyWithCompanion(RunSnapshotsCompanion data) {
    return RunSnapshot(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      turnNo: data.turnNo.present ? data.turnNo.value : this.turnNo,
      chapter: data.chapter.present ? data.chapter.value : this.chapter,
      parentSnapshotId: data.parentSnapshotId.present
          ? data.parentSnapshotId.value
          : this.parentSnapshotId,
      parentRunId: data.parentRunId.present
          ? data.parentRunId.value
          : this.parentRunId,
      state: data.state.present ? data.state.value : this.state,
      memory: data.memory.present ? data.memory.value : this.memory,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunSnapshot(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('turnNo: $turnNo, ')
          ..write('chapter: $chapter, ')
          ..write('parentSnapshotId: $parentSnapshotId, ')
          ..write('parentRunId: $parentRunId, ')
          ..write('state: $state, ')
          ..write('memory: $memory, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    turnNo,
    chapter,
    parentSnapshotId,
    parentRunId,
    state,
    memory,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunSnapshot &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.turnNo == this.turnNo &&
          other.chapter == this.chapter &&
          other.parentSnapshotId == this.parentSnapshotId &&
          other.parentRunId == this.parentRunId &&
          other.state == this.state &&
          other.memory == this.memory &&
          other.createdAt == this.createdAt);
}

class RunSnapshotsCompanion extends UpdateCompanion<RunSnapshot> {
  final Value<String> id;
  final Value<String> runId;
  final Value<int> turnNo;
  final Value<int> chapter;
  final Value<String?> parentSnapshotId;
  final Value<String?> parentRunId;
  final Value<String> state;
  final Value<String?> memory;
  final Value<int> createdAt;
  final Value<int> rowid;
  const RunSnapshotsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.turnNo = const Value.absent(),
    this.chapter = const Value.absent(),
    this.parentSnapshotId = const Value.absent(),
    this.parentRunId = const Value.absent(),
    this.state = const Value.absent(),
    this.memory = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunSnapshotsCompanion.insert({
    required String id,
    required String runId,
    required int turnNo,
    required int chapter,
    this.parentSnapshotId = const Value.absent(),
    this.parentRunId = const Value.absent(),
    required String state,
    this.memory = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       turnNo = Value(turnNo),
       chapter = Value(chapter),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<RunSnapshot> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<int>? turnNo,
    Expression<int>? chapter,
    Expression<String>? parentSnapshotId,
    Expression<String>? parentRunId,
    Expression<String>? state,
    Expression<String>? memory,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (turnNo != null) 'turn_no': turnNo,
      if (chapter != null) 'chapter': chapter,
      if (parentSnapshotId != null) 'parent_snapshot_id': parentSnapshotId,
      if (parentRunId != null) 'parent_run_id': parentRunId,
      if (state != null) 'state': state,
      if (memory != null) 'memory': memory,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<int>? turnNo,
    Value<int>? chapter,
    Value<String?>? parentSnapshotId,
    Value<String?>? parentRunId,
    Value<String>? state,
    Value<String?>? memory,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return RunSnapshotsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      turnNo: turnNo ?? this.turnNo,
      chapter: chapter ?? this.chapter,
      parentSnapshotId: parentSnapshotId ?? this.parentSnapshotId,
      parentRunId: parentRunId ?? this.parentRunId,
      state: state ?? this.state,
      memory: memory ?? this.memory,
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
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (turnNo.present) {
      map['turn_no'] = Variable<int>(turnNo.value);
    }
    if (chapter.present) {
      map['chapter'] = Variable<int>(chapter.value);
    }
    if (parentSnapshotId.present) {
      map['parent_snapshot_id'] = Variable<String>(parentSnapshotId.value);
    }
    if (parentRunId.present) {
      map['parent_run_id'] = Variable<String>(parentRunId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (memory.present) {
      map['memory'] = Variable<String>(memory.value);
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
    return (StringBuffer('RunSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('turnNo: $turnNo, ')
          ..write('chapter: $chapter, ')
          ..write('parentSnapshotId: $parentSnapshotId, ')
          ..write('parentRunId: $parentRunId, ')
          ..write('state: $state, ')
          ..write('memory: $memory, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunEventsTable extends RunEvents
    with TableInfo<$RunEventsTable, RunEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turnNoMeta = const VerificationMeta('turnNo');
  @override
  late final GeneratedColumn<int> turnNo = GeneratedColumn<int>(
    'turn_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    runId,
    seq,
    turnNo,
    type,
    payload,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('turn_no')) {
      context.handle(
        _turnNoMeta,
        turnNo.isAcceptableOrUnknown(data['turn_no']!, _turnNoMeta),
      );
    } else if (isInserting) {
      context.missing(_turnNoMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
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
  Set<GeneratedColumn> get $primaryKey => {runId, seq};
  @override
  RunEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunEvent(
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      turnNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn_no'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RunEventsTable createAlias(String alias) {
    return $RunEventsTable(attachedDatabase, alias);
  }
}

class RunEvent extends DataClass implements Insertable<RunEvent> {
  final String runId;
  final int seq;
  final int turnNo;
  final String type;
  final String payload;
  final int createdAt;
  const RunEvent({
    required this.runId,
    required this.seq,
    required this.turnNo,
    required this.type,
    required this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_id'] = Variable<String>(runId);
    map['seq'] = Variable<int>(seq);
    map['turn_no'] = Variable<int>(turnNo);
    map['type'] = Variable<String>(type);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  RunEventsCompanion toCompanion(bool nullToAbsent) {
    return RunEventsCompanion(
      runId: Value(runId),
      seq: Value(seq),
      turnNo: Value(turnNo),
      type: Value(type),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory RunEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunEvent(
      runId: serializer.fromJson<String>(json['runId']),
      seq: serializer.fromJson<int>(json['seq']),
      turnNo: serializer.fromJson<int>(json['turnNo']),
      type: serializer.fromJson<String>(json['type']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'runId': serializer.toJson<String>(runId),
      'seq': serializer.toJson<int>(seq),
      'turnNo': serializer.toJson<int>(turnNo),
      'type': serializer.toJson<String>(type),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  RunEvent copyWith({
    String? runId,
    int? seq,
    int? turnNo,
    String? type,
    String? payload,
    int? createdAt,
  }) => RunEvent(
    runId: runId ?? this.runId,
    seq: seq ?? this.seq,
    turnNo: turnNo ?? this.turnNo,
    type: type ?? this.type,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  RunEvent copyWithCompanion(RunEventsCompanion data) {
    return RunEvent(
      runId: data.runId.present ? data.runId.value : this.runId,
      seq: data.seq.present ? data.seq.value : this.seq,
      turnNo: data.turnNo.present ? data.turnNo.value : this.turnNo,
      type: data.type.present ? data.type.value : this.type,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunEvent(')
          ..write('runId: $runId, ')
          ..write('seq: $seq, ')
          ..write('turnNo: $turnNo, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(runId, seq, turnNo, type, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunEvent &&
          other.runId == this.runId &&
          other.seq == this.seq &&
          other.turnNo == this.turnNo &&
          other.type == this.type &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class RunEventsCompanion extends UpdateCompanion<RunEvent> {
  final Value<String> runId;
  final Value<int> seq;
  final Value<int> turnNo;
  final Value<String> type;
  final Value<String> payload;
  final Value<int> createdAt;
  final Value<int> rowid;
  const RunEventsCompanion({
    this.runId = const Value.absent(),
    this.seq = const Value.absent(),
    this.turnNo = const Value.absent(),
    this.type = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunEventsCompanion.insert({
    required String runId,
    required int seq,
    required int turnNo,
    required String type,
    required String payload,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : runId = Value(runId),
       seq = Value(seq),
       turnNo = Value(turnNo),
       type = Value(type),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<RunEvent> custom({
    Expression<String>? runId,
    Expression<int>? seq,
    Expression<int>? turnNo,
    Expression<String>? type,
    Expression<String>? payload,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (runId != null) 'run_id': runId,
      if (seq != null) 'seq': seq,
      if (turnNo != null) 'turn_no': turnNo,
      if (type != null) 'type': type,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunEventsCompanion copyWith({
    Value<String>? runId,
    Value<int>? seq,
    Value<int>? turnNo,
    Value<String>? type,
    Value<String>? payload,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return RunEventsCompanion(
      runId: runId ?? this.runId,
      seq: seq ?? this.seq,
      turnNo: turnNo ?? this.turnNo,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (turnNo.present) {
      map['turn_no'] = Variable<int>(turnNo.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
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
    return (StringBuffer('RunEventsCompanion(')
          ..write('runId: $runId, ')
          ..write('seq: $seq, ')
          ..write('turnNo: $turnNo, ')
          ..write('type: $type, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageLogTable extends UsageLog
    with TableInfo<$UsageLogTable, UsageLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageLogTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _turnNoMeta = const VerificationMeta('turnNo');
  @override
  late final GeneratedColumn<int> turnNo = GeneratedColumn<int>(
    'turn_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokensInMeta = const VerificationMeta(
    'tokensIn',
  );
  @override
  late final GeneratedColumn<int> tokensIn = GeneratedColumn<int>(
    'tokens_in',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokensOutMeta = const VerificationMeta(
    'tokensOut',
  );
  @override
  late final GeneratedColumn<int> tokensOut = GeneratedColumn<int>(
    'tokens_out',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estimatedMeta = const VerificationMeta(
    'estimated',
  );
  @override
  late final GeneratedColumn<bool> estimated = GeneratedColumn<bool>(
    'estimated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("estimated" IN (0, 1))',
    ),
    clientDefault: () => false,
  );
  static const VerificationMeta _msMeta = const VerificationMeta('ms');
  @override
  late final GeneratedColumn<int> ms = GeneratedColumn<int>(
    'ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstByteMsMeta = const VerificationMeta(
    'firstByteMs',
  );
  @override
  late final GeneratedColumn<int> firstByteMs = GeneratedColumn<int>(
    'first_byte_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _okMeta = const VerificationMeta('ok');
  @override
  late final GeneratedColumn<bool> ok = GeneratedColumn<bool>(
    'ok',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ok" IN (0, 1))',
    ),
    clientDefault: () => true,
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
    runId,
    turnNo,
    role,
    model,
    tokensIn,
    tokensOut,
    estimated,
    ms,
    firstByteMs,
    ok,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('turn_no')) {
      context.handle(
        _turnNoMeta,
        turnNo.isAcceptableOrUnknown(data['turn_no']!, _turnNoMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('tokens_in')) {
      context.handle(
        _tokensInMeta,
        tokensIn.isAcceptableOrUnknown(data['tokens_in']!, _tokensInMeta),
      );
    } else if (isInserting) {
      context.missing(_tokensInMeta);
    }
    if (data.containsKey('tokens_out')) {
      context.handle(
        _tokensOutMeta,
        tokensOut.isAcceptableOrUnknown(data['tokens_out']!, _tokensOutMeta),
      );
    } else if (isInserting) {
      context.missing(_tokensOutMeta);
    }
    if (data.containsKey('estimated')) {
      context.handle(
        _estimatedMeta,
        estimated.isAcceptableOrUnknown(data['estimated']!, _estimatedMeta),
      );
    }
    if (data.containsKey('ms')) {
      context.handle(_msMeta, ms.isAcceptableOrUnknown(data['ms']!, _msMeta));
    } else if (isInserting) {
      context.missing(_msMeta);
    }
    if (data.containsKey('first_byte_ms')) {
      context.handle(
        _firstByteMsMeta,
        firstByteMs.isAcceptableOrUnknown(
          data['first_byte_ms']!,
          _firstByteMsMeta,
        ),
      );
    }
    if (data.containsKey('ok')) {
      context.handle(_okMeta, ok.isAcceptableOrUnknown(data['ok']!, _okMeta));
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
  UsageLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      turnNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn_no'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      tokensIn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tokens_in'],
      )!,
      tokensOut: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tokens_out'],
      )!,
      estimated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}estimated'],
      )!,
      ms: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ms'],
      )!,
      firstByteMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_byte_ms'],
      ),
      ok: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ok'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UsageLogTable createAlias(String alias) {
    return $UsageLogTable(attachedDatabase, alias);
  }
}

class UsageLogData extends DataClass implements Insertable<UsageLogData> {
  final int id;
  final String? runId;
  final int? turnNo;
  final String role;
  final String model;
  final int tokensIn;
  final int tokensOut;
  final bool estimated;
  final int ms;
  final int? firstByteMs;
  final bool ok;
  final int createdAt;
  const UsageLogData({
    required this.id,
    this.runId,
    this.turnNo,
    required this.role,
    required this.model,
    required this.tokensIn,
    required this.tokensOut,
    required this.estimated,
    required this.ms,
    this.firstByteMs,
    required this.ok,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    if (!nullToAbsent || turnNo != null) {
      map['turn_no'] = Variable<int>(turnNo);
    }
    map['role'] = Variable<String>(role);
    map['model'] = Variable<String>(model);
    map['tokens_in'] = Variable<int>(tokensIn);
    map['tokens_out'] = Variable<int>(tokensOut);
    map['estimated'] = Variable<bool>(estimated);
    map['ms'] = Variable<int>(ms);
    if (!nullToAbsent || firstByteMs != null) {
      map['first_byte_ms'] = Variable<int>(firstByteMs);
    }
    map['ok'] = Variable<bool>(ok);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  UsageLogCompanion toCompanion(bool nullToAbsent) {
    return UsageLogCompanion(
      id: Value(id),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      turnNo: turnNo == null && nullToAbsent
          ? const Value.absent()
          : Value(turnNo),
      role: Value(role),
      model: Value(model),
      tokensIn: Value(tokensIn),
      tokensOut: Value(tokensOut),
      estimated: Value(estimated),
      ms: Value(ms),
      firstByteMs: firstByteMs == null && nullToAbsent
          ? const Value.absent()
          : Value(firstByteMs),
      ok: Value(ok),
      createdAt: Value(createdAt),
    );
  }

  factory UsageLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageLogData(
      id: serializer.fromJson<int>(json['id']),
      runId: serializer.fromJson<String?>(json['runId']),
      turnNo: serializer.fromJson<int?>(json['turnNo']),
      role: serializer.fromJson<String>(json['role']),
      model: serializer.fromJson<String>(json['model']),
      tokensIn: serializer.fromJson<int>(json['tokensIn']),
      tokensOut: serializer.fromJson<int>(json['tokensOut']),
      estimated: serializer.fromJson<bool>(json['estimated']),
      ms: serializer.fromJson<int>(json['ms']),
      firstByteMs: serializer.fromJson<int?>(json['firstByteMs']),
      ok: serializer.fromJson<bool>(json['ok']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runId': serializer.toJson<String?>(runId),
      'turnNo': serializer.toJson<int?>(turnNo),
      'role': serializer.toJson<String>(role),
      'model': serializer.toJson<String>(model),
      'tokensIn': serializer.toJson<int>(tokensIn),
      'tokensOut': serializer.toJson<int>(tokensOut),
      'estimated': serializer.toJson<bool>(estimated),
      'ms': serializer.toJson<int>(ms),
      'firstByteMs': serializer.toJson<int?>(firstByteMs),
      'ok': serializer.toJson<bool>(ok),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  UsageLogData copyWith({
    int? id,
    Value<String?> runId = const Value.absent(),
    Value<int?> turnNo = const Value.absent(),
    String? role,
    String? model,
    int? tokensIn,
    int? tokensOut,
    bool? estimated,
    int? ms,
    Value<int?> firstByteMs = const Value.absent(),
    bool? ok,
    int? createdAt,
  }) => UsageLogData(
    id: id ?? this.id,
    runId: runId.present ? runId.value : this.runId,
    turnNo: turnNo.present ? turnNo.value : this.turnNo,
    role: role ?? this.role,
    model: model ?? this.model,
    tokensIn: tokensIn ?? this.tokensIn,
    tokensOut: tokensOut ?? this.tokensOut,
    estimated: estimated ?? this.estimated,
    ms: ms ?? this.ms,
    firstByteMs: firstByteMs.present ? firstByteMs.value : this.firstByteMs,
    ok: ok ?? this.ok,
    createdAt: createdAt ?? this.createdAt,
  );
  UsageLogData copyWithCompanion(UsageLogCompanion data) {
    return UsageLogData(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      turnNo: data.turnNo.present ? data.turnNo.value : this.turnNo,
      role: data.role.present ? data.role.value : this.role,
      model: data.model.present ? data.model.value : this.model,
      tokensIn: data.tokensIn.present ? data.tokensIn.value : this.tokensIn,
      tokensOut: data.tokensOut.present ? data.tokensOut.value : this.tokensOut,
      estimated: data.estimated.present ? data.estimated.value : this.estimated,
      ms: data.ms.present ? data.ms.value : this.ms,
      firstByteMs: data.firstByteMs.present
          ? data.firstByteMs.value
          : this.firstByteMs,
      ok: data.ok.present ? data.ok.value : this.ok,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageLogData(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('turnNo: $turnNo, ')
          ..write('role: $role, ')
          ..write('model: $model, ')
          ..write('tokensIn: $tokensIn, ')
          ..write('tokensOut: $tokensOut, ')
          ..write('estimated: $estimated, ')
          ..write('ms: $ms, ')
          ..write('firstByteMs: $firstByteMs, ')
          ..write('ok: $ok, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    turnNo,
    role,
    model,
    tokensIn,
    tokensOut,
    estimated,
    ms,
    firstByteMs,
    ok,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageLogData &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.turnNo == this.turnNo &&
          other.role == this.role &&
          other.model == this.model &&
          other.tokensIn == this.tokensIn &&
          other.tokensOut == this.tokensOut &&
          other.estimated == this.estimated &&
          other.ms == this.ms &&
          other.firstByteMs == this.firstByteMs &&
          other.ok == this.ok &&
          other.createdAt == this.createdAt);
}

class UsageLogCompanion extends UpdateCompanion<UsageLogData> {
  final Value<int> id;
  final Value<String?> runId;
  final Value<int?> turnNo;
  final Value<String> role;
  final Value<String> model;
  final Value<int> tokensIn;
  final Value<int> tokensOut;
  final Value<bool> estimated;
  final Value<int> ms;
  final Value<int?> firstByteMs;
  final Value<bool> ok;
  final Value<int> createdAt;
  const UsageLogCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.turnNo = const Value.absent(),
    this.role = const Value.absent(),
    this.model = const Value.absent(),
    this.tokensIn = const Value.absent(),
    this.tokensOut = const Value.absent(),
    this.estimated = const Value.absent(),
    this.ms = const Value.absent(),
    this.firstByteMs = const Value.absent(),
    this.ok = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UsageLogCompanion.insert({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.turnNo = const Value.absent(),
    required String role,
    required String model,
    required int tokensIn,
    required int tokensOut,
    this.estimated = const Value.absent(),
    required int ms,
    this.firstByteMs = const Value.absent(),
    this.ok = const Value.absent(),
    required int createdAt,
  }) : role = Value(role),
       model = Value(model),
       tokensIn = Value(tokensIn),
       tokensOut = Value(tokensOut),
       ms = Value(ms),
       createdAt = Value(createdAt);
  static Insertable<UsageLogData> custom({
    Expression<int>? id,
    Expression<String>? runId,
    Expression<int>? turnNo,
    Expression<String>? role,
    Expression<String>? model,
    Expression<int>? tokensIn,
    Expression<int>? tokensOut,
    Expression<bool>? estimated,
    Expression<int>? ms,
    Expression<int>? firstByteMs,
    Expression<bool>? ok,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (turnNo != null) 'turn_no': turnNo,
      if (role != null) 'role': role,
      if (model != null) 'model': model,
      if (tokensIn != null) 'tokens_in': tokensIn,
      if (tokensOut != null) 'tokens_out': tokensOut,
      if (estimated != null) 'estimated': estimated,
      if (ms != null) 'ms': ms,
      if (firstByteMs != null) 'first_byte_ms': firstByteMs,
      if (ok != null) 'ok': ok,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UsageLogCompanion copyWith({
    Value<int>? id,
    Value<String?>? runId,
    Value<int?>? turnNo,
    Value<String>? role,
    Value<String>? model,
    Value<int>? tokensIn,
    Value<int>? tokensOut,
    Value<bool>? estimated,
    Value<int>? ms,
    Value<int?>? firstByteMs,
    Value<bool>? ok,
    Value<int>? createdAt,
  }) {
    return UsageLogCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      turnNo: turnNo ?? this.turnNo,
      role: role ?? this.role,
      model: model ?? this.model,
      tokensIn: tokensIn ?? this.tokensIn,
      tokensOut: tokensOut ?? this.tokensOut,
      estimated: estimated ?? this.estimated,
      ms: ms ?? this.ms,
      firstByteMs: firstByteMs ?? this.firstByteMs,
      ok: ok ?? this.ok,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (turnNo.present) {
      map['turn_no'] = Variable<int>(turnNo.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (tokensIn.present) {
      map['tokens_in'] = Variable<int>(tokensIn.value);
    }
    if (tokensOut.present) {
      map['tokens_out'] = Variable<int>(tokensOut.value);
    }
    if (estimated.present) {
      map['estimated'] = Variable<bool>(estimated.value);
    }
    if (ms.present) {
      map['ms'] = Variable<int>(ms.value);
    }
    if (firstByteMs.present) {
      map['first_byte_ms'] = Variable<int>(firstByteMs.value);
    }
    if (ok.present) {
      map['ok'] = Variable<bool>(ok.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageLogCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('turnNo: $turnNo, ')
          ..write('role: $role, ')
          ..write('model: $model, ')
          ..write('tokensIn: $tokensIn, ')
          ..write('tokensOut: $tokensOut, ')
          ..write('estimated: $estimated, ')
          ..write('ms: $ms, ')
          ..write('firstByteMs: $firstByteMs, ')
          ..write('ok: $ok, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ImportJobsTable extends ImportJobs
    with TableInfo<$ImportJobsTable, ImportJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    clientDefault: () => 0,
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
    sourcePath,
    contentHash,
    stage,
    progress,
    error,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
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
  ImportJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
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
  $ImportJobsTable createAlias(String alias) {
    return $ImportJobsTable(attachedDatabase, alias);
  }
}

class ImportJob extends DataClass implements Insertable<ImportJob> {
  final String id;
  final String sourcePath;
  final String contentHash;
  final String stage;
  final double progress;
  final String? error;
  final int createdAt;
  final int updatedAt;
  const ImportJob({
    required this.id,
    required this.sourcePath,
    required this.contentHash,
    required this.stage,
    required this.progress,
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_path'] = Variable<String>(sourcePath);
    map['content_hash'] = Variable<String>(contentHash);
    map['stage'] = Variable<String>(stage);
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ImportJobsCompanion toCompanion(bool nullToAbsent) {
    return ImportJobsCompanion(
      id: Value(id),
      sourcePath: Value(sourcePath),
      contentHash: Value(contentHash),
      stage: Value(stage),
      progress: Value(progress),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ImportJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportJob(
      id: serializer.fromJson<String>(json['id']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      stage: serializer.fromJson<String>(json['stage']),
      progress: serializer.fromJson<double>(json['progress']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'contentHash': serializer.toJson<String>(contentHash),
      'stage': serializer.toJson<String>(stage),
      'progress': serializer.toJson<double>(progress),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ImportJob copyWith({
    String? id,
    String? sourcePath,
    String? contentHash,
    String? stage,
    double? progress,
    Value<String?> error = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => ImportJob(
    id: id ?? this.id,
    sourcePath: sourcePath ?? this.sourcePath,
    contentHash: contentHash ?? this.contentHash,
    stage: stage ?? this.stage,
    progress: progress ?? this.progress,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ImportJob copyWithCompanion(ImportJobsCompanion data) {
    return ImportJob(
      id: data.id.present ? data.id.value : this.id,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      stage: data.stage.present ? data.stage.value : this.stage,
      progress: data.progress.present ? data.progress.value : this.progress,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportJob(')
          ..write('id: $id, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('contentHash: $contentHash, ')
          ..write('stage: $stage, ')
          ..write('progress: $progress, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourcePath,
    contentHash,
    stage,
    progress,
    error,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportJob &&
          other.id == this.id &&
          other.sourcePath == this.sourcePath &&
          other.contentHash == this.contentHash &&
          other.stage == this.stage &&
          other.progress == this.progress &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ImportJobsCompanion extends UpdateCompanion<ImportJob> {
  final Value<String> id;
  final Value<String> sourcePath;
  final Value<String> contentHash;
  final Value<String> stage;
  final Value<double> progress;
  final Value<String?> error;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ImportJobsCompanion({
    this.id = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.stage = const Value.absent(),
    this.progress = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportJobsCompanion.insert({
    required String id,
    required String sourcePath,
    required String contentHash,
    required String stage,
    this.progress = const Value.absent(),
    this.error = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourcePath = Value(sourcePath),
       contentHash = Value(contentHash),
       stage = Value(stage),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ImportJob> custom({
    Expression<String>? id,
    Expression<String>? sourcePath,
    Expression<String>? contentHash,
    Expression<String>? stage,
    Expression<double>? progress,
    Expression<String>? error,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourcePath != null) 'source_path': sourcePath,
      if (contentHash != null) 'content_hash': contentHash,
      if (stage != null) 'stage': stage,
      if (progress != null) 'progress': progress,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourcePath,
    Value<String>? contentHash,
    Value<String>? stage,
    Value<double>? progress,
    Value<String?>? error,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ImportJobsCompanion(
      id: id ?? this.id,
      sourcePath: sourcePath ?? this.sourcePath,
      contentHash: contentHash ?? this.contentHash,
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      error: error ?? this.error,
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
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
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
    return (StringBuffer('ImportJobsCompanion(')
          ..write('id: $id, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('contentHash: $contentHash, ')
          ..write('stage: $stage, ')
          ..write('progress: $progress, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
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

class $LocalEventsTable extends LocalEvents
    with TableInfo<$LocalEventsTable, LocalEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _propsMeta = const VerificationMeta('props');
  @override
  late final GeneratedColumn<String> props = GeneratedColumn<String>(
    'props',
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
  List<GeneratedColumn> get $columns => [id, name, runId, props, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('props')) {
      context.handle(
        _propsMeta,
        props.isAcceptableOrUnknown(data['props']!, _propsMeta),
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
  LocalEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      props: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}props'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalEventsTable createAlias(String alias) {
    return $LocalEventsTable(attachedDatabase, alias);
  }
}

class LocalEvent extends DataClass implements Insertable<LocalEvent> {
  final int id;
  final String name;
  final String? runId;
  final String? props;
  final int createdAt;
  const LocalEvent({
    required this.id,
    required this.name,
    this.runId,
    this.props,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    if (!nullToAbsent || props != null) {
      map['props'] = Variable<String>(props);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  LocalEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalEventsCompanion(
      id: Value(id),
      name: Value(name),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      props: props == null && nullToAbsent
          ? const Value.absent()
          : Value(props),
      createdAt: Value(createdAt),
    );
  }

  factory LocalEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEvent(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      runId: serializer.fromJson<String?>(json['runId']),
      props: serializer.fromJson<String?>(json['props']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'runId': serializer.toJson<String?>(runId),
      'props': serializer.toJson<String?>(props),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  LocalEvent copyWith({
    int? id,
    String? name,
    Value<String?> runId = const Value.absent(),
    Value<String?> props = const Value.absent(),
    int? createdAt,
  }) => LocalEvent(
    id: id ?? this.id,
    name: name ?? this.name,
    runId: runId.present ? runId.value : this.runId,
    props: props.present ? props.value : this.props,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalEvent copyWithCompanion(LocalEventsCompanion data) {
    return LocalEvent(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      runId: data.runId.present ? data.runId.value : this.runId,
      props: data.props.present ? data.props.value : this.props,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEvent(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('runId: $runId, ')
          ..write('props: $props, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, runId, props, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEvent &&
          other.id == this.id &&
          other.name == this.name &&
          other.runId == this.runId &&
          other.props == this.props &&
          other.createdAt == this.createdAt);
}

class LocalEventsCompanion extends UpdateCompanion<LocalEvent> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> runId;
  final Value<String?> props;
  final Value<int> createdAt;
  const LocalEventsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.runId = const Value.absent(),
    this.props = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalEventsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.runId = const Value.absent(),
    this.props = const Value.absent(),
    required int createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<LocalEvent> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? runId,
    Expression<String>? props,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (runId != null) 'run_id': runId,
      if (props != null) 'props': props,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? runId,
    Value<String?>? props,
    Value<int>? createdAt,
  }) {
    return LocalEventsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      runId: runId ?? this.runId,
      props: props ?? this.props,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (props.present) {
      map['props'] = Variable<String>(props.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEventsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('runId: $runId, ')
          ..write('props: $props, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $WorldsTable worlds = $WorldsTable(this);
  late final $WorldVersionsTable worldVersions = $WorldVersionsTable(this);
  late final $RunsTable runs = $RunsTable(this);
  late final $RunSnapshotsTable runSnapshots = $RunSnapshotsTable(this);
  late final $RunEventsTable runEvents = $RunEventsTable(this);
  late final $UsageLogTable usageLog = $UsageLogTable(this);
  late final $ImportJobsTable importJobs = $ImportJobsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $LocalEventsTable localEvents = $LocalEventsTable(this);
  late final Index idxWvWorldVersion = Index(
    'idx_wv_world_version',
    'CREATE UNIQUE INDEX idx_wv_world_version ON world_versions (world_id, version)',
  );
  late final Index idxRunsWorld = Index(
    'idx_runs_world',
    'CREATE INDEX idx_runs_world ON runs (world_id, status, updated_at)',
  );
  late final Index idxSnapshotsRun = Index(
    'idx_snapshots_run',
    'CREATE INDEX idx_snapshots_run ON run_snapshots (run_id, turn_no)',
  );
  late final Index idxEventsRunTurn = Index(
    'idx_events_run_turn',
    'CREATE INDEX idx_events_run_turn ON run_events (run_id, turn_no)',
  );
  late final Index idxLocalEventsName = Index(
    'idx_local_events_name',
    'CREATE INDEX idx_local_events_name ON local_events (name, created_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    worlds,
    worldVersions,
    runs,
    runSnapshots,
    runEvents,
    usageLog,
    importJobs,
    appSettings,
    localEvents,
    idxWvWorldVersion,
    idxRunsWorld,
    idxSnapshotsRun,
    idxEventsRunTurn,
    idxLocalEventsName,
  ];
}

typedef $$WorldsTableCreateCompanionBuilder =
    WorldsCompanion Function({
      required String id,
      required String title,
      required String genre,
      Value<String?> summary,
      required String source,
      Value<bool> exportable,
      Value<String> license,
      Value<String?> author,
      Value<String?> sourceWorldId,
      Value<int> latestVersion,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$WorldsTableUpdateCompanionBuilder =
    WorldsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> genre,
      Value<String?> summary,
      Value<String> source,
      Value<bool> exportable,
      Value<String> license,
      Value<String?> author,
      Value<String?> sourceWorldId,
      Value<int> latestVersion,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$WorldsTableFilterComposer extends Composer<_$AppDb, $WorldsTable> {
  $$WorldsTableFilterComposer({
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

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get exportable => $composableBuilder(
    column: $table.exportable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceWorldId => $composableBuilder(
    column: $table.sourceWorldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latestVersion => $composableBuilder(
    column: $table.latestVersion,
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

class $$WorldsTableOrderingComposer extends Composer<_$AppDb, $WorldsTable> {
  $$WorldsTableOrderingComposer({
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

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get exportable => $composableBuilder(
    column: $table.exportable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get license => $composableBuilder(
    column: $table.license,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceWorldId => $composableBuilder(
    column: $table.sourceWorldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latestVersion => $composableBuilder(
    column: $table.latestVersion,
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

class $$WorldsTableAnnotationComposer extends Composer<_$AppDb, $WorldsTable> {
  $$WorldsTableAnnotationComposer({
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

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get exportable => $composableBuilder(
    column: $table.exportable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get license =>
      $composableBuilder(column: $table.license, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get sourceWorldId => $composableBuilder(
    column: $table.sourceWorldId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latestVersion => $composableBuilder(
    column: $table.latestVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorldsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $WorldsTable,
          World,
          $$WorldsTableFilterComposer,
          $$WorldsTableOrderingComposer,
          $$WorldsTableAnnotationComposer,
          $$WorldsTableCreateCompanionBuilder,
          $$WorldsTableUpdateCompanionBuilder,
          (World, BaseReferences<_$AppDb, $WorldsTable, World>),
          World,
          PrefetchHooks Function()
        > {
  $$WorldsTableTableManager(_$AppDb db, $WorldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> genre = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> exportable = const Value.absent(),
                Value<String> license = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> sourceWorldId = const Value.absent(),
                Value<int> latestVersion = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldsCompanion(
                id: id,
                title: title,
                genre: genre,
                summary: summary,
                source: source,
                exportable: exportable,
                license: license,
                author: author,
                sourceWorldId: sourceWorldId,
                latestVersion: latestVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String genre,
                Value<String?> summary = const Value.absent(),
                required String source,
                Value<bool> exportable = const Value.absent(),
                Value<String> license = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> sourceWorldId = const Value.absent(),
                Value<int> latestVersion = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WorldsCompanion.insert(
                id: id,
                title: title,
                genre: genre,
                summary: summary,
                source: source,
                exportable: exportable,
                license: license,
                author: author,
                sourceWorldId: sourceWorldId,
                latestVersion: latestVersion,
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

typedef $$WorldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $WorldsTable,
      World,
      $$WorldsTableFilterComposer,
      $$WorldsTableOrderingComposer,
      $$WorldsTableAnnotationComposer,
      $$WorldsTableCreateCompanionBuilder,
      $$WorldsTableUpdateCompanionBuilder,
      (World, BaseReferences<_$AppDb, $WorldsTable, World>),
      World,
      PrefetchHooks Function()
    >;
typedef $$WorldVersionsTableCreateCompanionBuilder =
    WorldVersionsCompanion Function({
      required String id,
      required String worldId,
      required int version,
      required String bible,
      required String identities,
      required String seeds,
      required String checksum,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$WorldVersionsTableUpdateCompanionBuilder =
    WorldVersionsCompanion Function({
      Value<String> id,
      Value<String> worldId,
      Value<int> version,
      Value<String> bible,
      Value<String> identities,
      Value<String> seeds,
      Value<String> checksum,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$WorldVersionsTableFilterComposer
    extends Composer<_$AppDb, $WorldVersionsTable> {
  $$WorldVersionsTableFilterComposer({
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

  ColumnFilters<String> get worldId => $composableBuilder(
    column: $table.worldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bible => $composableBuilder(
    column: $table.bible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identities => $composableBuilder(
    column: $table.identities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seeds => $composableBuilder(
    column: $table.seeds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorldVersionsTableOrderingComposer
    extends Composer<_$AppDb, $WorldVersionsTable> {
  $$WorldVersionsTableOrderingComposer({
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

  ColumnOrderings<String> get worldId => $composableBuilder(
    column: $table.worldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bible => $composableBuilder(
    column: $table.bible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identities => $composableBuilder(
    column: $table.identities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seeds => $composableBuilder(
    column: $table.seeds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorldVersionsTableAnnotationComposer
    extends Composer<_$AppDb, $WorldVersionsTable> {
  $$WorldVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get worldId =>
      $composableBuilder(column: $table.worldId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get bible =>
      $composableBuilder(column: $table.bible, builder: (column) => column);

  GeneratedColumn<String> get identities => $composableBuilder(
    column: $table.identities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seeds =>
      $composableBuilder(column: $table.seeds, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WorldVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $WorldVersionsTable,
          WorldVersion,
          $$WorldVersionsTableFilterComposer,
          $$WorldVersionsTableOrderingComposer,
          $$WorldVersionsTableAnnotationComposer,
          $$WorldVersionsTableCreateCompanionBuilder,
          $$WorldVersionsTableUpdateCompanionBuilder,
          (
            WorldVersion,
            BaseReferences<_$AppDb, $WorldVersionsTable, WorldVersion>,
          ),
          WorldVersion,
          PrefetchHooks Function()
        > {
  $$WorldVersionsTableTableManager(_$AppDb db, $WorldVersionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorldVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorldVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorldVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> worldId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> bible = const Value.absent(),
                Value<String> identities = const Value.absent(),
                Value<String> seeds = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldVersionsCompanion(
                id: id,
                worldId: worldId,
                version: version,
                bible: bible,
                identities: identities,
                seeds: seeds,
                checksum: checksum,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String worldId,
                required int version,
                required String bible,
                required String identities,
                required String seeds,
                required String checksum,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WorldVersionsCompanion.insert(
                id: id,
                worldId: worldId,
                version: version,
                bible: bible,
                identities: identities,
                seeds: seeds,
                checksum: checksum,
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

typedef $$WorldVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $WorldVersionsTable,
      WorldVersion,
      $$WorldVersionsTableFilterComposer,
      $$WorldVersionsTableOrderingComposer,
      $$WorldVersionsTableAnnotationComposer,
      $$WorldVersionsTableCreateCompanionBuilder,
      $$WorldVersionsTableUpdateCompanionBuilder,
      (
        WorldVersion,
        BaseReferences<_$AppDb, $WorldVersionsTable, WorldVersion>,
      ),
      WorldVersion,
      PrefetchHooks Function()
    >;
typedef $$RunsTableCreateCompanionBuilder =
    RunsCompanion Function({
      required String id,
      required String worldId,
      required int worldVersion,
      required String identityId,
      Value<String> status,
      Value<int> chapter,
      Value<int> turnNo,
      Value<String?> headSnapshotId,
      Value<String?> endingId,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$RunsTableUpdateCompanionBuilder =
    RunsCompanion Function({
      Value<String> id,
      Value<String> worldId,
      Value<int> worldVersion,
      Value<String> identityId,
      Value<String> status,
      Value<int> chapter,
      Value<int> turnNo,
      Value<String?> headSnapshotId,
      Value<String?> endingId,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$RunsTableFilterComposer extends Composer<_$AppDb, $RunsTable> {
  $$RunsTableFilterComposer({
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

  ColumnFilters<String> get worldId => $composableBuilder(
    column: $table.worldId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get worldVersion => $composableBuilder(
    column: $table.worldVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identityId => $composableBuilder(
    column: $table.identityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapter => $composableBuilder(
    column: $table.chapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turnNo => $composableBuilder(
    column: $table.turnNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headSnapshotId => $composableBuilder(
    column: $table.headSnapshotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endingId => $composableBuilder(
    column: $table.endingId,
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

class $$RunsTableOrderingComposer extends Composer<_$AppDb, $RunsTable> {
  $$RunsTableOrderingComposer({
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

  ColumnOrderings<String> get worldId => $composableBuilder(
    column: $table.worldId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get worldVersion => $composableBuilder(
    column: $table.worldVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identityId => $composableBuilder(
    column: $table.identityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapter => $composableBuilder(
    column: $table.chapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turnNo => $composableBuilder(
    column: $table.turnNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headSnapshotId => $composableBuilder(
    column: $table.headSnapshotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endingId => $composableBuilder(
    column: $table.endingId,
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

class $$RunsTableAnnotationComposer extends Composer<_$AppDb, $RunsTable> {
  $$RunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get worldId =>
      $composableBuilder(column: $table.worldId, builder: (column) => column);

  GeneratedColumn<int> get worldVersion => $composableBuilder(
    column: $table.worldVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get identityId => $composableBuilder(
    column: $table.identityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get chapter =>
      $composableBuilder(column: $table.chapter, builder: (column) => column);

  GeneratedColumn<int> get turnNo =>
      $composableBuilder(column: $table.turnNo, builder: (column) => column);

  GeneratedColumn<String> get headSnapshotId => $composableBuilder(
    column: $table.headSnapshotId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endingId =>
      $composableBuilder(column: $table.endingId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RunsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RunsTable,
          Run,
          $$RunsTableFilterComposer,
          $$RunsTableOrderingComposer,
          $$RunsTableAnnotationComposer,
          $$RunsTableCreateCompanionBuilder,
          $$RunsTableUpdateCompanionBuilder,
          (Run, BaseReferences<_$AppDb, $RunsTable, Run>),
          Run,
          PrefetchHooks Function()
        > {
  $$RunsTableTableManager(_$AppDb db, $RunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> worldId = const Value.absent(),
                Value<int> worldVersion = const Value.absent(),
                Value<String> identityId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> chapter = const Value.absent(),
                Value<int> turnNo = const Value.absent(),
                Value<String?> headSnapshotId = const Value.absent(),
                Value<String?> endingId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion(
                id: id,
                worldId: worldId,
                worldVersion: worldVersion,
                identityId: identityId,
                status: status,
                chapter: chapter,
                turnNo: turnNo,
                headSnapshotId: headSnapshotId,
                endingId: endingId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String worldId,
                required int worldVersion,
                required String identityId,
                Value<String> status = const Value.absent(),
                Value<int> chapter = const Value.absent(),
                Value<int> turnNo = const Value.absent(),
                Value<String?> headSnapshotId = const Value.absent(),
                Value<String?> endingId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion.insert(
                id: id,
                worldId: worldId,
                worldVersion: worldVersion,
                identityId: identityId,
                status: status,
                chapter: chapter,
                turnNo: turnNo,
                headSnapshotId: headSnapshotId,
                endingId: endingId,
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

typedef $$RunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RunsTable,
      Run,
      $$RunsTableFilterComposer,
      $$RunsTableOrderingComposer,
      $$RunsTableAnnotationComposer,
      $$RunsTableCreateCompanionBuilder,
      $$RunsTableUpdateCompanionBuilder,
      (Run, BaseReferences<_$AppDb, $RunsTable, Run>),
      Run,
      PrefetchHooks Function()
    >;
typedef $$RunSnapshotsTableCreateCompanionBuilder =
    RunSnapshotsCompanion Function({
      required String id,
      required String runId,
      required int turnNo,
      required int chapter,
      Value<String?> parentSnapshotId,
      Value<String?> parentRunId,
      required String state,
      Value<String?> memory,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$RunSnapshotsTableUpdateCompanionBuilder =
    RunSnapshotsCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<int> turnNo,
      Value<int> chapter,
      Value<String?> parentSnapshotId,
      Value<String?> parentRunId,
      Value<String> state,
      Value<String?> memory,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$RunSnapshotsTableFilterComposer
    extends Composer<_$AppDb, $RunSnapshotsTable> {
  $$RunSnapshotsTableFilterComposer({
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

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turnNo => $composableBuilder(
    column: $table.turnNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapter => $composableBuilder(
    column: $table.chapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentSnapshotId => $composableBuilder(
    column: $table.parentSnapshotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentRunId => $composableBuilder(
    column: $table.parentRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memory => $composableBuilder(
    column: $table.memory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunSnapshotsTableOrderingComposer
    extends Composer<_$AppDb, $RunSnapshotsTable> {
  $$RunSnapshotsTableOrderingComposer({
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

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turnNo => $composableBuilder(
    column: $table.turnNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapter => $composableBuilder(
    column: $table.chapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentSnapshotId => $composableBuilder(
    column: $table.parentSnapshotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentRunId => $composableBuilder(
    column: $table.parentRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memory => $composableBuilder(
    column: $table.memory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunSnapshotsTableAnnotationComposer
    extends Composer<_$AppDb, $RunSnapshotsTable> {
  $$RunSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<int> get turnNo =>
      $composableBuilder(column: $table.turnNo, builder: (column) => column);

  GeneratedColumn<int> get chapter =>
      $composableBuilder(column: $table.chapter, builder: (column) => column);

  GeneratedColumn<String> get parentSnapshotId => $composableBuilder(
    column: $table.parentSnapshotId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentRunId => $composableBuilder(
    column: $table.parentRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get memory =>
      $composableBuilder(column: $table.memory, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RunSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RunSnapshotsTable,
          RunSnapshot,
          $$RunSnapshotsTableFilterComposer,
          $$RunSnapshotsTableOrderingComposer,
          $$RunSnapshotsTableAnnotationComposer,
          $$RunSnapshotsTableCreateCompanionBuilder,
          $$RunSnapshotsTableUpdateCompanionBuilder,
          (
            RunSnapshot,
            BaseReferences<_$AppDb, $RunSnapshotsTable, RunSnapshot>,
          ),
          RunSnapshot,
          PrefetchHooks Function()
        > {
  $$RunSnapshotsTableTableManager(_$AppDb db, $RunSnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<int> turnNo = const Value.absent(),
                Value<int> chapter = const Value.absent(),
                Value<String?> parentSnapshotId = const Value.absent(),
                Value<String?> parentRunId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> memory = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunSnapshotsCompanion(
                id: id,
                runId: runId,
                turnNo: turnNo,
                chapter: chapter,
                parentSnapshotId: parentSnapshotId,
                parentRunId: parentRunId,
                state: state,
                memory: memory,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required int turnNo,
                required int chapter,
                Value<String?> parentSnapshotId = const Value.absent(),
                Value<String?> parentRunId = const Value.absent(),
                required String state,
                Value<String?> memory = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RunSnapshotsCompanion.insert(
                id: id,
                runId: runId,
                turnNo: turnNo,
                chapter: chapter,
                parentSnapshotId: parentSnapshotId,
                parentRunId: parentRunId,
                state: state,
                memory: memory,
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

typedef $$RunSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RunSnapshotsTable,
      RunSnapshot,
      $$RunSnapshotsTableFilterComposer,
      $$RunSnapshotsTableOrderingComposer,
      $$RunSnapshotsTableAnnotationComposer,
      $$RunSnapshotsTableCreateCompanionBuilder,
      $$RunSnapshotsTableUpdateCompanionBuilder,
      (RunSnapshot, BaseReferences<_$AppDb, $RunSnapshotsTable, RunSnapshot>),
      RunSnapshot,
      PrefetchHooks Function()
    >;
typedef $$RunEventsTableCreateCompanionBuilder =
    RunEventsCompanion Function({
      required String runId,
      required int seq,
      required int turnNo,
      required String type,
      required String payload,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$RunEventsTableUpdateCompanionBuilder =
    RunEventsCompanion Function({
      Value<String> runId,
      Value<int> seq,
      Value<int> turnNo,
      Value<String> type,
      Value<String> payload,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$RunEventsTableFilterComposer
    extends Composer<_$AppDb, $RunEventsTable> {
  $$RunEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turnNo => $composableBuilder(
    column: $table.turnNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunEventsTableOrderingComposer
    extends Composer<_$AppDb, $RunEventsTable> {
  $$RunEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turnNo => $composableBuilder(
    column: $table.turnNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunEventsTableAnnotationComposer
    extends Composer<_$AppDb, $RunEventsTable> {
  $$RunEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get turnNo =>
      $composableBuilder(column: $table.turnNo, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RunEventsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RunEventsTable,
          RunEvent,
          $$RunEventsTableFilterComposer,
          $$RunEventsTableOrderingComposer,
          $$RunEventsTableAnnotationComposer,
          $$RunEventsTableCreateCompanionBuilder,
          $$RunEventsTableUpdateCompanionBuilder,
          (RunEvent, BaseReferences<_$AppDb, $RunEventsTable, RunEvent>),
          RunEvent,
          PrefetchHooks Function()
        > {
  $$RunEventsTableTableManager(_$AppDb db, $RunEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> runId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> turnNo = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunEventsCompanion(
                runId: runId,
                seq: seq,
                turnNo: turnNo,
                type: type,
                payload: payload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String runId,
                required int seq,
                required int turnNo,
                required String type,
                required String payload,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RunEventsCompanion.insert(
                runId: runId,
                seq: seq,
                turnNo: turnNo,
                type: type,
                payload: payload,
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

typedef $$RunEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RunEventsTable,
      RunEvent,
      $$RunEventsTableFilterComposer,
      $$RunEventsTableOrderingComposer,
      $$RunEventsTableAnnotationComposer,
      $$RunEventsTableCreateCompanionBuilder,
      $$RunEventsTableUpdateCompanionBuilder,
      (RunEvent, BaseReferences<_$AppDb, $RunEventsTable, RunEvent>),
      RunEvent,
      PrefetchHooks Function()
    >;
typedef $$UsageLogTableCreateCompanionBuilder =
    UsageLogCompanion Function({
      Value<int> id,
      Value<String?> runId,
      Value<int?> turnNo,
      required String role,
      required String model,
      required int tokensIn,
      required int tokensOut,
      Value<bool> estimated,
      required int ms,
      Value<int?> firstByteMs,
      Value<bool> ok,
      required int createdAt,
    });
typedef $$UsageLogTableUpdateCompanionBuilder =
    UsageLogCompanion Function({
      Value<int> id,
      Value<String?> runId,
      Value<int?> turnNo,
      Value<String> role,
      Value<String> model,
      Value<int> tokensIn,
      Value<int> tokensOut,
      Value<bool> estimated,
      Value<int> ms,
      Value<int?> firstByteMs,
      Value<bool> ok,
      Value<int> createdAt,
    });

class $$UsageLogTableFilterComposer extends Composer<_$AppDb, $UsageLogTable> {
  $$UsageLogTableFilterComposer({
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

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turnNo => $composableBuilder(
    column: $table.turnNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokensIn => $composableBuilder(
    column: $table.tokensIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokensOut => $composableBuilder(
    column: $table.tokensOut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get estimated => $composableBuilder(
    column: $table.estimated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ms => $composableBuilder(
    column: $table.ms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstByteMs => $composableBuilder(
    column: $table.firstByteMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageLogTableOrderingComposer
    extends Composer<_$AppDb, $UsageLogTable> {
  $$UsageLogTableOrderingComposer({
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

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turnNo => $composableBuilder(
    column: $table.turnNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokensIn => $composableBuilder(
    column: $table.tokensIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokensOut => $composableBuilder(
    column: $table.tokensOut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get estimated => $composableBuilder(
    column: $table.estimated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ms => $composableBuilder(
    column: $table.ms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstByteMs => $composableBuilder(
    column: $table.firstByteMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageLogTableAnnotationComposer
    extends Composer<_$AppDb, $UsageLogTable> {
  $$UsageLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<int> get turnNo =>
      $composableBuilder(column: $table.turnNo, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get tokensIn =>
      $composableBuilder(column: $table.tokensIn, builder: (column) => column);

  GeneratedColumn<int> get tokensOut =>
      $composableBuilder(column: $table.tokensOut, builder: (column) => column);

  GeneratedColumn<bool> get estimated =>
      $composableBuilder(column: $table.estimated, builder: (column) => column);

  GeneratedColumn<int> get ms =>
      $composableBuilder(column: $table.ms, builder: (column) => column);

  GeneratedColumn<int> get firstByteMs => $composableBuilder(
    column: $table.firstByteMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ok =>
      $composableBuilder(column: $table.ok, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsageLogTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $UsageLogTable,
          UsageLogData,
          $$UsageLogTableFilterComposer,
          $$UsageLogTableOrderingComposer,
          $$UsageLogTableAnnotationComposer,
          $$UsageLogTableCreateCompanionBuilder,
          $$UsageLogTableUpdateCompanionBuilder,
          (UsageLogData, BaseReferences<_$AppDb, $UsageLogTable, UsageLogData>),
          UsageLogData,
          PrefetchHooks Function()
        > {
  $$UsageLogTableTableManager(_$AppDb db, $UsageLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<int?> turnNo = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> tokensIn = const Value.absent(),
                Value<int> tokensOut = const Value.absent(),
                Value<bool> estimated = const Value.absent(),
                Value<int> ms = const Value.absent(),
                Value<int?> firstByteMs = const Value.absent(),
                Value<bool> ok = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => UsageLogCompanion(
                id: id,
                runId: runId,
                turnNo: turnNo,
                role: role,
                model: model,
                tokensIn: tokensIn,
                tokensOut: tokensOut,
                estimated: estimated,
                ms: ms,
                firstByteMs: firstByteMs,
                ok: ok,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<int?> turnNo = const Value.absent(),
                required String role,
                required String model,
                required int tokensIn,
                required int tokensOut,
                Value<bool> estimated = const Value.absent(),
                required int ms,
                Value<int?> firstByteMs = const Value.absent(),
                Value<bool> ok = const Value.absent(),
                required int createdAt,
              }) => UsageLogCompanion.insert(
                id: id,
                runId: runId,
                turnNo: turnNo,
                role: role,
                model: model,
                tokensIn: tokensIn,
                tokensOut: tokensOut,
                estimated: estimated,
                ms: ms,
                firstByteMs: firstByteMs,
                ok: ok,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $UsageLogTable,
      UsageLogData,
      $$UsageLogTableFilterComposer,
      $$UsageLogTableOrderingComposer,
      $$UsageLogTableAnnotationComposer,
      $$UsageLogTableCreateCompanionBuilder,
      $$UsageLogTableUpdateCompanionBuilder,
      (UsageLogData, BaseReferences<_$AppDb, $UsageLogTable, UsageLogData>),
      UsageLogData,
      PrefetchHooks Function()
    >;
typedef $$ImportJobsTableCreateCompanionBuilder =
    ImportJobsCompanion Function({
      required String id,
      required String sourcePath,
      required String contentHash,
      required String stage,
      Value<double> progress,
      Value<String?> error,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ImportJobsTableUpdateCompanionBuilder =
    ImportJobsCompanion Function({
      Value<String> id,
      Value<String> sourcePath,
      Value<String> contentHash,
      Value<String> stage,
      Value<double> progress,
      Value<String?> error,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ImportJobsTableFilterComposer
    extends Composer<_$AppDb, $ImportJobsTable> {
  $$ImportJobsTableFilterComposer({
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

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
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

class $$ImportJobsTableOrderingComposer
    extends Composer<_$AppDb, $ImportJobsTable> {
  $$ImportJobsTableOrderingComposer({
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

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
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

class $$ImportJobsTableAnnotationComposer
    extends Composer<_$AppDb, $ImportJobsTable> {
  $$ImportJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ImportJobsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ImportJobsTable,
          ImportJob,
          $$ImportJobsTableFilterComposer,
          $$ImportJobsTableOrderingComposer,
          $$ImportJobsTableAnnotationComposer,
          $$ImportJobsTableCreateCompanionBuilder,
          $$ImportJobsTableUpdateCompanionBuilder,
          (ImportJob, BaseReferences<_$AppDb, $ImportJobsTable, ImportJob>),
          ImportJob,
          PrefetchHooks Function()
        > {
  $$ImportJobsTableTableManager(_$AppDb db, $ImportJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportJobsCompanion(
                id: id,
                sourcePath: sourcePath,
                contentHash: contentHash,
                stage: stage,
                progress: progress,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourcePath,
                required String contentHash,
                required String stage,
                Value<double> progress = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportJobsCompanion.insert(
                id: id,
                sourcePath: sourcePath,
                contentHash: contentHash,
                stage: stage,
                progress: progress,
                error: error,
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

typedef $$ImportJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ImportJobsTable,
      ImportJob,
      $$ImportJobsTableFilterComposer,
      $$ImportJobsTableOrderingComposer,
      $$ImportJobsTableAnnotationComposer,
      $$ImportJobsTableCreateCompanionBuilder,
      $$ImportJobsTableUpdateCompanionBuilder,
      (ImportJob, BaseReferences<_$AppDb, $ImportJobsTable, ImportJob>),
      ImportJob,
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
    extends Composer<_$AppDb, $AppSettingsTable> {
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
    extends Composer<_$AppDb, $AppSettingsTable> {
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
    extends Composer<_$AppDb, $AppSettingsTable> {
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
          _$AppDb,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (AppSetting, BaseReferences<_$AppDb, $AppSettingsTable, AppSetting>),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDb db, $AppSettingsTable table)
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
      _$AppDb,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (AppSetting, BaseReferences<_$AppDb, $AppSettingsTable, AppSetting>),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$LocalEventsTableCreateCompanionBuilder =
    LocalEventsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> runId,
      Value<String?> props,
      required int createdAt,
    });
typedef $$LocalEventsTableUpdateCompanionBuilder =
    LocalEventsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> runId,
      Value<String?> props,
      Value<int> createdAt,
    });

class $$LocalEventsTableFilterComposer
    extends Composer<_$AppDb, $LocalEventsTable> {
  $$LocalEventsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get props => $composableBuilder(
    column: $table.props,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEventsTableOrderingComposer
    extends Composer<_$AppDb, $LocalEventsTable> {
  $$LocalEventsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get props => $composableBuilder(
    column: $table.props,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEventsTableAnnotationComposer
    extends Composer<_$AppDb, $LocalEventsTable> {
  $$LocalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get props =>
      $composableBuilder(column: $table.props, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalEventsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalEventsTable,
          LocalEvent,
          $$LocalEventsTableFilterComposer,
          $$LocalEventsTableOrderingComposer,
          $$LocalEventsTableAnnotationComposer,
          $$LocalEventsTableCreateCompanionBuilder,
          $$LocalEventsTableUpdateCompanionBuilder,
          (LocalEvent, BaseReferences<_$AppDb, $LocalEventsTable, LocalEvent>),
          LocalEvent,
          PrefetchHooks Function()
        > {
  $$LocalEventsTableTableManager(_$AppDb db, $LocalEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<String?> props = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => LocalEventsCompanion(
                id: id,
                name: name,
                runId: runId,
                props: props,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> runId = const Value.absent(),
                Value<String?> props = const Value.absent(),
                required int createdAt,
              }) => LocalEventsCompanion.insert(
                id: id,
                name: name,
                runId: runId,
                props: props,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalEventsTable,
      LocalEvent,
      $$LocalEventsTableFilterComposer,
      $$LocalEventsTableOrderingComposer,
      $$LocalEventsTableAnnotationComposer,
      $$LocalEventsTableCreateCompanionBuilder,
      $$LocalEventsTableUpdateCompanionBuilder,
      (LocalEvent, BaseReferences<_$AppDb, $LocalEventsTable, LocalEvent>),
      LocalEvent,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$WorldsTableTableManager get worlds =>
      $$WorldsTableTableManager(_db, _db.worlds);
  $$WorldVersionsTableTableManager get worldVersions =>
      $$WorldVersionsTableTableManager(_db, _db.worldVersions);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
  $$RunSnapshotsTableTableManager get runSnapshots =>
      $$RunSnapshotsTableTableManager(_db, _db.runSnapshots);
  $$RunEventsTableTableManager get runEvents =>
      $$RunEventsTableTableManager(_db, _db.runEvents);
  $$UsageLogTableTableManager get usageLog =>
      $$UsageLogTableTableManager(_db, _db.usageLog);
  $$ImportJobsTableTableManager get importJobs =>
      $$ImportJobsTableTableManager(_db, _db.importJobs);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db, _db.localEvents);
}
