// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LibraryFoldersTable extends LibraryFolders
    with TableInfo<$LibraryFoldersTable, LibraryFolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryFoldersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDownloadFolderMeta = const VerificationMeta(
    'isDownloadFolder',
  );
  @override
  late final GeneratedColumn<bool> isDownloadFolder = GeneratedColumn<bool>(
    'is_download_folder',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_download_folder" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isAvailableMeta = const VerificationMeta(
    'isAvailable',
  );
  @override
  late final GeneratedColumn<bool> isAvailable = GeneratedColumn<bool>(
    'is_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastScanAtMeta = const VerificationMeta(
    'lastScanAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastScanAt = GeneratedColumn<DateTime>(
    'last_scan_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    label,
    isDownloadFolder,
    isAvailable,
    lastScanAt,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryFolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('is_download_folder')) {
      context.handle(
        _isDownloadFolderMeta,
        isDownloadFolder.isAcceptableOrUnknown(
          data['is_download_folder']!,
          _isDownloadFolderMeta,
        ),
      );
    }
    if (data.containsKey('is_available')) {
      context.handle(
        _isAvailableMeta,
        isAvailable.isAcceptableOrUnknown(
          data['is_available']!,
          _isAvailableMeta,
        ),
      );
    }
    if (data.containsKey('last_scan_at')) {
      context.handle(
        _lastScanAtMeta,
        lastScanAt.isAcceptableOrUnknown(
          data['last_scan_at']!,
          _lastScanAtMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryFolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryFolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      isDownloadFolder: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_download_folder'],
      )!,
      isAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_available'],
      )!,
      lastScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_scan_at'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $LibraryFoldersTable createAlias(String alias) {
    return $LibraryFoldersTable(attachedDatabase, alias);
  }
}

class LibraryFolderRow extends DataClass
    implements Insertable<LibraryFolderRow> {
  final int id;

  /// Absolute, as the system gave it.
  final String path;

  /// What the screens call it ("Movies HDD"; the canvas's, v9).
  final String label;
  final bool isDownloadFolder;
  final bool isAvailable;
  final DateTime? lastScanAt;
  final DateTime addedAt;
  const LibraryFolderRow({
    required this.id,
    required this.path,
    required this.label,
    required this.isDownloadFolder,
    required this.isAvailable,
    this.lastScanAt,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['label'] = Variable<String>(label);
    map['is_download_folder'] = Variable<bool>(isDownloadFolder);
    map['is_available'] = Variable<bool>(isAvailable);
    if (!nullToAbsent || lastScanAt != null) {
      map['last_scan_at'] = Variable<DateTime>(lastScanAt);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  LibraryFoldersCompanion toCompanion(bool nullToAbsent) {
    return LibraryFoldersCompanion(
      id: Value(id),
      path: Value(path),
      label: Value(label),
      isDownloadFolder: Value(isDownloadFolder),
      isAvailable: Value(isAvailable),
      lastScanAt: lastScanAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScanAt),
      addedAt: Value(addedAt),
    );
  }

  factory LibraryFolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryFolderRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      label: serializer.fromJson<String>(json['label']),
      isDownloadFolder: serializer.fromJson<bool>(json['isDownloadFolder']),
      isAvailable: serializer.fromJson<bool>(json['isAvailable']),
      lastScanAt: serializer.fromJson<DateTime?>(json['lastScanAt']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'label': serializer.toJson<String>(label),
      'isDownloadFolder': serializer.toJson<bool>(isDownloadFolder),
      'isAvailable': serializer.toJson<bool>(isAvailable),
      'lastScanAt': serializer.toJson<DateTime?>(lastScanAt),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  LibraryFolderRow copyWith({
    int? id,
    String? path,
    String? label,
    bool? isDownloadFolder,
    bool? isAvailable,
    Value<DateTime?> lastScanAt = const Value.absent(),
    DateTime? addedAt,
  }) => LibraryFolderRow(
    id: id ?? this.id,
    path: path ?? this.path,
    label: label ?? this.label,
    isDownloadFolder: isDownloadFolder ?? this.isDownloadFolder,
    isAvailable: isAvailable ?? this.isAvailable,
    lastScanAt: lastScanAt.present ? lastScanAt.value : this.lastScanAt,
    addedAt: addedAt ?? this.addedAt,
  );
  LibraryFolderRow copyWithCompanion(LibraryFoldersCompanion data) {
    return LibraryFolderRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      label: data.label.present ? data.label.value : this.label,
      isDownloadFolder: data.isDownloadFolder.present
          ? data.isDownloadFolder.value
          : this.isDownloadFolder,
      isAvailable: data.isAvailable.present
          ? data.isAvailable.value
          : this.isAvailable,
      lastScanAt: data.lastScanAt.present
          ? data.lastScanAt.value
          : this.lastScanAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFolderRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('label: $label, ')
          ..write('isDownloadFolder: $isDownloadFolder, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('lastScanAt: $lastScanAt, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    path,
    label,
    isDownloadFolder,
    isAvailable,
    lastScanAt,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryFolderRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.label == this.label &&
          other.isDownloadFolder == this.isDownloadFolder &&
          other.isAvailable == this.isAvailable &&
          other.lastScanAt == this.lastScanAt &&
          other.addedAt == this.addedAt);
}

class LibraryFoldersCompanion extends UpdateCompanion<LibraryFolderRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> label;
  final Value<bool> isDownloadFolder;
  final Value<bool> isAvailable;
  final Value<DateTime?> lastScanAt;
  final Value<DateTime> addedAt;
  const LibraryFoldersCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.label = const Value.absent(),
    this.isDownloadFolder = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.lastScanAt = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  LibraryFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String label,
    this.isDownloadFolder = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.lastScanAt = const Value.absent(),
    required DateTime addedAt,
  }) : path = Value(path),
       label = Value(label),
       addedAt = Value(addedAt);
  static Insertable<LibraryFolderRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? label,
    Expression<bool>? isDownloadFolder,
    Expression<bool>? isAvailable,
    Expression<DateTime>? lastScanAt,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (label != null) 'label': label,
      if (isDownloadFolder != null) 'is_download_folder': isDownloadFolder,
      if (isAvailable != null) 'is_available': isAvailable,
      if (lastScanAt != null) 'last_scan_at': lastScanAt,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  LibraryFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? label,
    Value<bool>? isDownloadFolder,
    Value<bool>? isAvailable,
    Value<DateTime?>? lastScanAt,
    Value<DateTime>? addedAt,
  }) {
    return LibraryFoldersCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      label: label ?? this.label,
      isDownloadFolder: isDownloadFolder ?? this.isDownloadFolder,
      isAvailable: isAvailable ?? this.isAvailable,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (isDownloadFolder.present) {
      map['is_download_folder'] = Variable<bool>(isDownloadFolder.value);
    }
    if (isAvailable.present) {
      map['is_available'] = Variable<bool>(isAvailable.value);
    }
    if (lastScanAt.present) {
      map['last_scan_at'] = Variable<DateTime>(lastScanAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFoldersCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('label: $label, ')
          ..write('isDownloadFolder: $isDownloadFolder, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('lastScanAt: $lastScanAt, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $SourcesTable extends Sources with TableInfo<$SourcesTable, SourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SourceType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SourceType>($SourcesTable.$convertertype);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialRefMeta = const VerificationMeta(
    'credentialRef',
  );
  @override
  late final GeneratedColumn<String> credentialRef = GeneratedColumn<String>(
    'credential_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epgUrlMeta = const VerificationMeta('epgUrl');
  @override
  late final GeneratedColumn<String> epgUrl = GeneratedColumn<String>(
    'epg_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userAgentMeta = const VerificationMeta(
    'userAgent',
  );
  @override
  late final GeneratedColumn<String> userAgent = GeneratedColumn<String>(
    'user_agent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LiveFormat, String> liveFormat =
      GeneratedColumn<String>(
        'live_format',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('ts'),
      ).withConverter<LiveFormat>($SourcesTable.$converterliveFormat);
  static const VerificationMeta _epgOffsetMinutesMeta = const VerificationMeta(
    'epgOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> epgOffsetMinutes = GeneratedColumn<int>(
    'epg_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _refreshHoursMeta = const VerificationMeta(
    'refreshHours',
  );
  @override
  late final GeneratedColumn<int> refreshHours = GeneratedColumn<int>(
    'refresh_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(12),
  );
  static const VerificationMeta _maxConnectionsOverrideMeta =
      const VerificationMeta('maxConnectionsOverride');
  @override
  late final GeneratedColumn<int> maxConnectionsOverride = GeneratedColumn<int>(
    'max_connections_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountJsonMeta = const VerificationMeta(
    'accountJson',
  );
  @override
  late final GeneratedColumn<String> accountJson = GeneratedColumn<String>(
    'account_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    url,
    username,
    credentialRef,
    epgUrl,
    userAgent,
    liveFormat,
    epgOffsetMinutes,
    refreshHours,
    maxConnectionsOverride,
    accountJson,
    expiresAt,
    lastSyncedAt,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceRow> instance, {
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
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('credential_ref')) {
      context.handle(
        _credentialRefMeta,
        credentialRef.isAcceptableOrUnknown(
          data['credential_ref']!,
          _credentialRefMeta,
        ),
      );
    }
    if (data.containsKey('epg_url')) {
      context.handle(
        _epgUrlMeta,
        epgUrl.isAcceptableOrUnknown(data['epg_url']!, _epgUrlMeta),
      );
    }
    if (data.containsKey('user_agent')) {
      context.handle(
        _userAgentMeta,
        userAgent.isAcceptableOrUnknown(data['user_agent']!, _userAgentMeta),
      );
    }
    if (data.containsKey('epg_offset_minutes')) {
      context.handle(
        _epgOffsetMinutesMeta,
        epgOffsetMinutes.isAcceptableOrUnknown(
          data['epg_offset_minutes']!,
          _epgOffsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('refresh_hours')) {
      context.handle(
        _refreshHoursMeta,
        refreshHours.isAcceptableOrUnknown(
          data['refresh_hours']!,
          _refreshHoursMeta,
        ),
      );
    }
    if (data.containsKey('max_connections_override')) {
      context.handle(
        _maxConnectionsOverrideMeta,
        maxConnectionsOverride.isAcceptableOrUnknown(
          data['max_connections_override']!,
          _maxConnectionsOverrideMeta,
        ),
      );
    }
    if (data.containsKey('account_json')) {
      context.handle(
        _accountJsonMeta,
        accountJson.isAcceptableOrUnknown(
          data['account_json']!,
          _accountJsonMeta,
        ),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
  SourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $SourcesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      credentialRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_ref'],
      ),
      epgUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_url'],
      ),
      userAgent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_agent'],
      ),
      liveFormat: $SourcesTable.$converterliveFormat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}live_format'],
        )!,
      ),
      epgOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epg_offset_minutes'],
      )!,
      refreshHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refresh_hours'],
      )!,
      maxConnectionsOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_connections_override'],
      ),
      accountJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_json'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SourceType, String, String> $convertertype =
      const EnumNameConverter<SourceType>(SourceType.values);
  static JsonTypeConverter2<LiveFormat, String, String> $converterliveFormat =
      const EnumNameConverter<LiveFormat>(LiveFormat.values);
}

class SourceRow extends DataClass implements Insertable<SourceRow> {
  final String id;
  final SourceType type;
  final String name;

  /// The Xtream server base URL (never with credentials in it), the
  /// playlist URL's origin only (`http://host/…`), or the local file path,
  /// depending on [type]. A playlist URL's real value is in the secure
  /// store: playlist URLs usually carry the username and password, and
  /// some carry a token no masking pattern recognizes.
  final String url;

  /// Xtream only. Not a secret, but it never reaches a log unredacted.
  final String? username;

  /// The secure-store key holding this source's secrets (password,
  /// playlist URL, EPG URL), or null when it has none.
  final String? credentialRef;

  /// Overrides the XMLTV URL the provider advertises. Its origin only,
  /// like [url]; the real value is in the secure store.
  final String? epgUrl;
  final String? userAgent;
  final LiveFormat liveFormat;

  /// Added to every EPG time, for providers that publish the wrong zone.
  final int epgOffsetMinutes;

  /// How old the data may get before a sync runs on launch.
  final int refreshHours;

  /// Set only when the user knows better than the provider's
  /// `max_connections` (hard rule 7).
  final int? maxConnectionsOverride;

  /// The provider's raw account payload, kept for the Settings screen.
  final String? accountJson;
  final DateTime? expiresAt;
  final DateTime? lastSyncedAt;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SourceRow({
    required this.id,
    required this.type,
    required this.name,
    required this.url,
    this.username,
    this.credentialRef,
    this.epgUrl,
    this.userAgent,
    required this.liveFormat,
    required this.epgOffsetMinutes,
    required this.refreshHours,
    this.maxConnectionsOverride,
    this.accountJson,
    this.expiresAt,
    this.lastSyncedAt,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<String>($SourcesTable.$convertertype.toSql(type));
    }
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || credentialRef != null) {
      map['credential_ref'] = Variable<String>(credentialRef);
    }
    if (!nullToAbsent || epgUrl != null) {
      map['epg_url'] = Variable<String>(epgUrl);
    }
    if (!nullToAbsent || userAgent != null) {
      map['user_agent'] = Variable<String>(userAgent);
    }
    {
      map['live_format'] = Variable<String>(
        $SourcesTable.$converterliveFormat.toSql(liveFormat),
      );
    }
    map['epg_offset_minutes'] = Variable<int>(epgOffsetMinutes);
    map['refresh_hours'] = Variable<int>(refreshHours);
    if (!nullToAbsent || maxConnectionsOverride != null) {
      map['max_connections_override'] = Variable<int>(maxConnectionsOverride);
    }
    if (!nullToAbsent || accountJson != null) {
      map['account_json'] = Variable<String>(accountJson);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      url: Value(url),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      credentialRef: credentialRef == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialRef),
      epgUrl: epgUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(epgUrl),
      userAgent: userAgent == null && nullToAbsent
          ? const Value.absent()
          : Value(userAgent),
      liveFormat: Value(liveFormat),
      epgOffsetMinutes: Value(epgOffsetMinutes),
      refreshHours: Value(refreshHours),
      maxConnectionsOverride: maxConnectionsOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(maxConnectionsOverride),
      accountJson: accountJson == null && nullToAbsent
          ? const Value.absent()
          : Value(accountJson),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceRow(
      id: serializer.fromJson<String>(json['id']),
      type: $SourcesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      username: serializer.fromJson<String?>(json['username']),
      credentialRef: serializer.fromJson<String?>(json['credentialRef']),
      epgUrl: serializer.fromJson<String?>(json['epgUrl']),
      userAgent: serializer.fromJson<String?>(json['userAgent']),
      liveFormat: $SourcesTable.$converterliveFormat.fromJson(
        serializer.fromJson<String>(json['liveFormat']),
      ),
      epgOffsetMinutes: serializer.fromJson<int>(json['epgOffsetMinutes']),
      refreshHours: serializer.fromJson<int>(json['refreshHours']),
      maxConnectionsOverride: serializer.fromJson<int?>(
        json['maxConnectionsOverride'],
      ),
      accountJson: serializer.fromJson<String?>(json['accountJson']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(
        $SourcesTable.$convertertype.toJson(type),
      ),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'username': serializer.toJson<String?>(username),
      'credentialRef': serializer.toJson<String?>(credentialRef),
      'epgUrl': serializer.toJson<String?>(epgUrl),
      'userAgent': serializer.toJson<String?>(userAgent),
      'liveFormat': serializer.toJson<String>(
        $SourcesTable.$converterliveFormat.toJson(liveFormat),
      ),
      'epgOffsetMinutes': serializer.toJson<int>(epgOffsetMinutes),
      'refreshHours': serializer.toJson<int>(refreshHours),
      'maxConnectionsOverride': serializer.toJson<int?>(maxConnectionsOverride),
      'accountJson': serializer.toJson<String?>(accountJson),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SourceRow copyWith({
    String? id,
    SourceType? type,
    String? name,
    String? url,
    Value<String?> username = const Value.absent(),
    Value<String?> credentialRef = const Value.absent(),
    Value<String?> epgUrl = const Value.absent(),
    Value<String?> userAgent = const Value.absent(),
    LiveFormat? liveFormat,
    int? epgOffsetMinutes,
    int? refreshHours,
    Value<int?> maxConnectionsOverride = const Value.absent(),
    Value<String?> accountJson = const Value.absent(),
    Value<DateTime?> expiresAt = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SourceRow(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    url: url ?? this.url,
    username: username.present ? username.value : this.username,
    credentialRef: credentialRef.present
        ? credentialRef.value
        : this.credentialRef,
    epgUrl: epgUrl.present ? epgUrl.value : this.epgUrl,
    userAgent: userAgent.present ? userAgent.value : this.userAgent,
    liveFormat: liveFormat ?? this.liveFormat,
    epgOffsetMinutes: epgOffsetMinutes ?? this.epgOffsetMinutes,
    refreshHours: refreshHours ?? this.refreshHours,
    maxConnectionsOverride: maxConnectionsOverride.present
        ? maxConnectionsOverride.value
        : this.maxConnectionsOverride,
    accountJson: accountJson.present ? accountJson.value : this.accountJson,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SourceRow copyWithCompanion(SourcesCompanion data) {
    return SourceRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      username: data.username.present ? data.username.value : this.username,
      credentialRef: data.credentialRef.present
          ? data.credentialRef.value
          : this.credentialRef,
      epgUrl: data.epgUrl.present ? data.epgUrl.value : this.epgUrl,
      userAgent: data.userAgent.present ? data.userAgent.value : this.userAgent,
      liveFormat: data.liveFormat.present
          ? data.liveFormat.value
          : this.liveFormat,
      epgOffsetMinutes: data.epgOffsetMinutes.present
          ? data.epgOffsetMinutes.value
          : this.epgOffsetMinutes,
      refreshHours: data.refreshHours.present
          ? data.refreshHours.value
          : this.refreshHours,
      maxConnectionsOverride: data.maxConnectionsOverride.present
          ? data.maxConnectionsOverride.value
          : this.maxConnectionsOverride,
      accountJson: data.accountJson.present
          ? data.accountJson.value
          : this.accountJson,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('username: $username, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('userAgent: $userAgent, ')
          ..write('liveFormat: $liveFormat, ')
          ..write('epgOffsetMinutes: $epgOffsetMinutes, ')
          ..write('refreshHours: $refreshHours, ')
          ..write('maxConnectionsOverride: $maxConnectionsOverride, ')
          ..write('accountJson: $accountJson, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    url,
    username,
    credentialRef,
    epgUrl,
    userAgent,
    liveFormat,
    epgOffsetMinutes,
    refreshHours,
    maxConnectionsOverride,
    accountJson,
    expiresAt,
    lastSyncedAt,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.url == this.url &&
          other.username == this.username &&
          other.credentialRef == this.credentialRef &&
          other.epgUrl == this.epgUrl &&
          other.userAgent == this.userAgent &&
          other.liveFormat == this.liveFormat &&
          other.epgOffsetMinutes == this.epgOffsetMinutes &&
          other.refreshHours == this.refreshHours &&
          other.maxConnectionsOverride == this.maxConnectionsOverride &&
          other.accountJson == this.accountJson &&
          other.expiresAt == this.expiresAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SourcesCompanion extends UpdateCompanion<SourceRow> {
  final Value<String> id;
  final Value<SourceType> type;
  final Value<String> name;
  final Value<String> url;
  final Value<String?> username;
  final Value<String?> credentialRef;
  final Value<String?> epgUrl;
  final Value<String?> userAgent;
  final Value<LiveFormat> liveFormat;
  final Value<int> epgOffsetMinutes;
  final Value<int> refreshHours;
  final Value<int?> maxConnectionsOverride;
  final Value<String?> accountJson;
  final Value<DateTime?> expiresAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.username = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.userAgent = const Value.absent(),
    this.liveFormat = const Value.absent(),
    this.epgOffsetMinutes = const Value.absent(),
    this.refreshHours = const Value.absent(),
    this.maxConnectionsOverride = const Value.absent(),
    this.accountJson = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required SourceType type,
    required String name,
    required String url,
    this.username = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.userAgent = const Value.absent(),
    this.liveFormat = const Value.absent(),
    this.epgOffsetMinutes = const Value.absent(),
    this.refreshHours = const Value.absent(),
    this.maxConnectionsOverride = const Value.absent(),
    this.accountJson = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       name = Value(name),
       url = Value(url),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SourceRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? username,
    Expression<String>? credentialRef,
    Expression<String>? epgUrl,
    Expression<String>? userAgent,
    Expression<String>? liveFormat,
    Expression<int>? epgOffsetMinutes,
    Expression<int>? refreshHours,
    Expression<int>? maxConnectionsOverride,
    Expression<String>? accountJson,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (username != null) 'username': username,
      if (credentialRef != null) 'credential_ref': credentialRef,
      if (epgUrl != null) 'epg_url': epgUrl,
      if (userAgent != null) 'user_agent': userAgent,
      if (liveFormat != null) 'live_format': liveFormat,
      if (epgOffsetMinutes != null) 'epg_offset_minutes': epgOffsetMinutes,
      if (refreshHours != null) 'refresh_hours': refreshHours,
      if (maxConnectionsOverride != null)
        'max_connections_override': maxConnectionsOverride,
      if (accountJson != null) 'account_json': accountJson,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith({
    Value<String>? id,
    Value<SourceType>? type,
    Value<String>? name,
    Value<String>? url,
    Value<String?>? username,
    Value<String?>? credentialRef,
    Value<String?>? epgUrl,
    Value<String?>? userAgent,
    Value<LiveFormat>? liveFormat,
    Value<int>? epgOffsetMinutes,
    Value<int>? refreshHours,
    Value<int?>? maxConnectionsOverride,
    Value<String?>? accountJson,
    Value<DateTime?>? expiresAt,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      url: url ?? this.url,
      username: username ?? this.username,
      credentialRef: credentialRef ?? this.credentialRef,
      epgUrl: epgUrl ?? this.epgUrl,
      userAgent: userAgent ?? this.userAgent,
      liveFormat: liveFormat ?? this.liveFormat,
      epgOffsetMinutes: epgOffsetMinutes ?? this.epgOffsetMinutes,
      refreshHours: refreshHours ?? this.refreshHours,
      maxConnectionsOverride:
          maxConnectionsOverride ?? this.maxConnectionsOverride,
      accountJson: accountJson ?? this.accountJson,
      expiresAt: expiresAt ?? this.expiresAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (type.present) {
      map['type'] = Variable<String>(
        $SourcesTable.$convertertype.toSql(type.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (credentialRef.present) {
      map['credential_ref'] = Variable<String>(credentialRef.value);
    }
    if (epgUrl.present) {
      map['epg_url'] = Variable<String>(epgUrl.value);
    }
    if (userAgent.present) {
      map['user_agent'] = Variable<String>(userAgent.value);
    }
    if (liveFormat.present) {
      map['live_format'] = Variable<String>(
        $SourcesTable.$converterliveFormat.toSql(liveFormat.value),
      );
    }
    if (epgOffsetMinutes.present) {
      map['epg_offset_minutes'] = Variable<int>(epgOffsetMinutes.value);
    }
    if (refreshHours.present) {
      map['refresh_hours'] = Variable<int>(refreshHours.value);
    }
    if (maxConnectionsOverride.present) {
      map['max_connections_override'] = Variable<int>(
        maxConnectionsOverride.value,
      );
    }
    if (accountJson.present) {
      map['account_json'] = Variable<String>(accountJson.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
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
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('username: $username, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('userAgent: $userAgent, ')
          ..write('liveFormat: $liveFormat, ')
          ..write('epgOffsetMinutes: $epgOffsetMinutes, ')
          ..write('refreshHours: $refreshHours, ')
          ..write('maxConnectionsOverride: $maxConnectionsOverride, ')
          ..write('accountJson: $accountJson, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryItemsTable extends LibraryItems
    with TableInfo<$LibraryItemsTable, LibraryItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_folders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quickHashMeta = const VerificationMeta(
    'quickHash',
  );
  @override
  late final GeneratedColumn<String> quickHash = GeneratedColumn<String>(
    'quick_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LibraryKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LibraryKind>($LibraryItemsTable.$converterkind);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _showTitleMeta = const VerificationMeta(
    'showTitle',
  );
  @override
  late final GeneratedColumn<String> showTitle = GeneratedColumn<String>(
    'show_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeEndMeta = const VerificationMeta(
    'episodeEnd',
  );
  @override
  late final GeneratedColumn<int> episodeEnd = GeneratedColumn<int>(
    'episode_end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _probeJsonMeta = const VerificationMeta(
    'probeJson',
  );
  @override
  late final GeneratedColumn<String> probeJson = GeneratedColumn<String>(
    'probe_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkPathMeta = const VerificationMeta(
    'artworkPath',
  );
  @override
  late final GeneratedColumn<String> artworkPath = GeneratedColumn<String>(
    'artwork_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subtitlesJsonMeta = const VerificationMeta(
    'subtitlesJson',
  );
  @override
  late final GeneratedColumn<String> subtitlesJson = GeneratedColumn<String>(
    'subtitles_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userEditsJsonMeta = const VerificationMeta(
    'userEditsJson',
  );
  @override
  late final GeneratedColumn<String> userEditsJson = GeneratedColumn<String>(
    'user_edits_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsJsonMeta = const VerificationMeta(
    'detailsJson',
  );
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
    'details_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerSourceIdMeta = const VerificationMeta(
    'providerSourceId',
  );
  @override
  late final GeneratedColumn<String> providerSourceId = GeneratedColumn<String>(
    'provider_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE SET NULL',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<VodType?, String>
  providerItemType = GeneratedColumn<String>(
    'provider_item_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<VodType?>($LibraryItemsTable.$converterproviderItemTypen);
  static const VerificationMeta _providerRemoteKeyMeta = const VerificationMeta(
    'providerRemoteKey',
  );
  @override
  late final GeneratedColumn<String> providerRemoteKey =
      GeneratedColumn<String>(
        'provider_remote_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _providerSeriesKeyMeta = const VerificationMeta(
    'providerSeriesKey',
  );
  @override
  late final GeneratedColumn<String> providerSeriesKey =
      GeneratedColumn<String>(
        'provider_series_key',
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
  static const VerificationMeta _unavailableSinceMeta = const VerificationMeta(
    'unavailableSince',
  );
  @override
  late final GeneratedColumn<DateTime> unavailableSince =
      GeneratedColumn<DateTime>(
        'unavailable_since',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folderId,
    relPath,
    sizeBytes,
    mtime,
    quickHash,
    kind,
    title,
    year,
    showTitle,
    season,
    episode,
    episodeEnd,
    durationMs,
    probeJson,
    thumbnailPath,
    artworkPath,
    subtitlesJson,
    userEditsJson,
    detailsJson,
    providerSourceId,
    providerItemType,
    providerRemoteKey,
    providerSeriesKey,
    isHidden,
    unavailableSince,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMeta);
    }
    if (data.containsKey('quick_hash')) {
      context.handle(
        _quickHashMeta,
        quickHash.isAcceptableOrUnknown(data['quick_hash']!, _quickHashMeta),
      );
    } else if (isInserting) {
      context.missing(_quickHashMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('show_title')) {
      context.handle(
        _showTitleMeta,
        showTitle.isAcceptableOrUnknown(data['show_title']!, _showTitleMeta),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('episode_end')) {
      context.handle(
        _episodeEndMeta,
        episodeEnd.isAcceptableOrUnknown(data['episode_end']!, _episodeEndMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('probe_json')) {
      context.handle(
        _probeJsonMeta,
        probeJson.isAcceptableOrUnknown(data['probe_json']!, _probeJsonMeta),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('artwork_path')) {
      context.handle(
        _artworkPathMeta,
        artworkPath.isAcceptableOrUnknown(
          data['artwork_path']!,
          _artworkPathMeta,
        ),
      );
    }
    if (data.containsKey('subtitles_json')) {
      context.handle(
        _subtitlesJsonMeta,
        subtitlesJson.isAcceptableOrUnknown(
          data['subtitles_json']!,
          _subtitlesJsonMeta,
        ),
      );
    }
    if (data.containsKey('user_edits_json')) {
      context.handle(
        _userEditsJsonMeta,
        userEditsJson.isAcceptableOrUnknown(
          data['user_edits_json']!,
          _userEditsJsonMeta,
        ),
      );
    }
    if (data.containsKey('details_json')) {
      context.handle(
        _detailsJsonMeta,
        detailsJson.isAcceptableOrUnknown(
          data['details_json']!,
          _detailsJsonMeta,
        ),
      );
    }
    if (data.containsKey('provider_source_id')) {
      context.handle(
        _providerSourceIdMeta,
        providerSourceId.isAcceptableOrUnknown(
          data['provider_source_id']!,
          _providerSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('provider_remote_key')) {
      context.handle(
        _providerRemoteKeyMeta,
        providerRemoteKey.isAcceptableOrUnknown(
          data['provider_remote_key']!,
          _providerRemoteKeyMeta,
        ),
      );
    }
    if (data.containsKey('provider_series_key')) {
      context.handle(
        _providerSeriesKeyMeta,
        providerSeriesKey.isAcceptableOrUnknown(
          data['provider_series_key']!,
          _providerSeriesKeyMeta,
        ),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('unavailable_since')) {
      context.handle(
        _unavailableSinceMeta,
        unavailableSince.isAcceptableOrUnknown(
          data['unavailable_since']!,
          _unavailableSinceMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {folderId, relPath},
  ];
  @override
  LibraryItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      )!,
      quickHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quick_hash'],
      )!,
      kind: $LibraryItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      showTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}show_title'],
      ),
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      ),
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      ),
      episodeEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_end'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      probeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}probe_json'],
      ),
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      artworkPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_path'],
      ),
      subtitlesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitles_json'],
      ),
      userEditsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_edits_json'],
      ),
      detailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details_json'],
      ),
      providerSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_source_id'],
      ),
      providerItemType: $LibraryItemsTable.$converterproviderItemTypen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}provider_item_type'],
        ),
      ),
      providerRemoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_remote_key'],
      ),
      providerSeriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_series_key'],
      ),
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      unavailableSince: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}unavailable_since'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $LibraryItemsTable createAlias(String alias) {
    return $LibraryItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LibraryKind, String, String> $converterkind =
      const EnumNameConverter<LibraryKind>(LibraryKind.values);
  static JsonTypeConverter2<VodType, String, String>
  $converterproviderItemType = const EnumNameConverter<VodType>(VodType.values);
  static JsonTypeConverter2<VodType?, String?, String?>
  $converterproviderItemTypen = JsonTypeConverter2.asNullable(
    $converterproviderItemType,
  );
}

class LibraryItemRow extends DataClass implements Insertable<LibraryItemRow> {
  final int id;
  final int folderId;

  /// Inside its folder, with `/` between parts on every system.
  final String relPath;
  final int sizeBytes;

  /// The file's modification time, in milliseconds since the epoch: a
  /// file with the same path, size and time is never read again.
  final int mtime;

  /// Size + the first and last 64 KB (docs/09).
  final String quickHash;
  final LibraryKind kind;
  final String title;
  final int? year;
  final String? showTitle;
  final int? season;
  final int? episode;
  final int? episodeEnd;
  final int? durationMs;

  /// What ffprobe said of it (step 4); null until it was probed.
  final String? probeJson;
  final String? thumbnailPath;
  final String? artworkPath;

  /// The subtitle files beside it (`ExternalSubtitle`s), as JSON.
  final String? subtitlesJson;

  /// What the user set in Edit details (`LibraryItemEdit`), as JSON.
  final String? userEditsJson;

  /// A download's copy of its title's details (plot, rating, genres,
  /// cast; an episode's title and still), so its page works offline and
  /// after the provider drops the title (v9, Phase 8 decision 5).
  final String? detailsJson;

  /// A download's title at its source. Removing the source leaves the
  /// file in the library, unlinked.
  final String? providerSourceId;
  final VodType? providerItemType;
  final String? providerRemoteKey;

  /// An episode's series at its source (v9: its history key needs it).
  final String? providerSeriesKey;
  final bool isHidden;

  /// When its folder stopped being readable (docs/09: 30 days, then it
  /// goes).
  final DateTime? unavailableSince;
  final DateTime addedAt;
  const LibraryItemRow({
    required this.id,
    required this.folderId,
    required this.relPath,
    required this.sizeBytes,
    required this.mtime,
    required this.quickHash,
    required this.kind,
    required this.title,
    this.year,
    this.showTitle,
    this.season,
    this.episode,
    this.episodeEnd,
    this.durationMs,
    this.probeJson,
    this.thumbnailPath,
    this.artworkPath,
    this.subtitlesJson,
    this.userEditsJson,
    this.detailsJson,
    this.providerSourceId,
    this.providerItemType,
    this.providerRemoteKey,
    this.providerSeriesKey,
    required this.isHidden,
    this.unavailableSince,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['folder_id'] = Variable<int>(folderId);
    map['rel_path'] = Variable<String>(relPath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['mtime'] = Variable<int>(mtime);
    map['quick_hash'] = Variable<String>(quickHash);
    {
      map['kind'] = Variable<String>(
        $LibraryItemsTable.$converterkind.toSql(kind),
      );
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || showTitle != null) {
      map['show_title'] = Variable<String>(showTitle);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<int>(season);
    }
    if (!nullToAbsent || episode != null) {
      map['episode'] = Variable<int>(episode);
    }
    if (!nullToAbsent || episodeEnd != null) {
      map['episode_end'] = Variable<int>(episodeEnd);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || probeJson != null) {
      map['probe_json'] = Variable<String>(probeJson);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || artworkPath != null) {
      map['artwork_path'] = Variable<String>(artworkPath);
    }
    if (!nullToAbsent || subtitlesJson != null) {
      map['subtitles_json'] = Variable<String>(subtitlesJson);
    }
    if (!nullToAbsent || userEditsJson != null) {
      map['user_edits_json'] = Variable<String>(userEditsJson);
    }
    if (!nullToAbsent || detailsJson != null) {
      map['details_json'] = Variable<String>(detailsJson);
    }
    if (!nullToAbsent || providerSourceId != null) {
      map['provider_source_id'] = Variable<String>(providerSourceId);
    }
    if (!nullToAbsent || providerItemType != null) {
      map['provider_item_type'] = Variable<String>(
        $LibraryItemsTable.$converterproviderItemTypen.toSql(providerItemType),
      );
    }
    if (!nullToAbsent || providerRemoteKey != null) {
      map['provider_remote_key'] = Variable<String>(providerRemoteKey);
    }
    if (!nullToAbsent || providerSeriesKey != null) {
      map['provider_series_key'] = Variable<String>(providerSeriesKey);
    }
    map['is_hidden'] = Variable<bool>(isHidden);
    if (!nullToAbsent || unavailableSince != null) {
      map['unavailable_since'] = Variable<DateTime>(unavailableSince);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  LibraryItemsCompanion toCompanion(bool nullToAbsent) {
    return LibraryItemsCompanion(
      id: Value(id),
      folderId: Value(folderId),
      relPath: Value(relPath),
      sizeBytes: Value(sizeBytes),
      mtime: Value(mtime),
      quickHash: Value(quickHash),
      kind: Value(kind),
      title: Value(title),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      showTitle: showTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(showTitle),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      episode: episode == null && nullToAbsent
          ? const Value.absent()
          : Value(episode),
      episodeEnd: episodeEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeEnd),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      probeJson: probeJson == null && nullToAbsent
          ? const Value.absent()
          : Value(probeJson),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      artworkPath: artworkPath == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkPath),
      subtitlesJson: subtitlesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitlesJson),
      userEditsJson: userEditsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(userEditsJson),
      detailsJson: detailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsJson),
      providerSourceId: providerSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerSourceId),
      providerItemType: providerItemType == null && nullToAbsent
          ? const Value.absent()
          : Value(providerItemType),
      providerRemoteKey: providerRemoteKey == null && nullToAbsent
          ? const Value.absent()
          : Value(providerRemoteKey),
      providerSeriesKey: providerSeriesKey == null && nullToAbsent
          ? const Value.absent()
          : Value(providerSeriesKey),
      isHidden: Value(isHidden),
      unavailableSince: unavailableSince == null && nullToAbsent
          ? const Value.absent()
          : Value(unavailableSince),
      addedAt: Value(addedAt),
    );
  }

  factory LibraryItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryItemRow(
      id: serializer.fromJson<int>(json['id']),
      folderId: serializer.fromJson<int>(json['folderId']),
      relPath: serializer.fromJson<String>(json['relPath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      mtime: serializer.fromJson<int>(json['mtime']),
      quickHash: serializer.fromJson<String>(json['quickHash']),
      kind: $LibraryItemsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      title: serializer.fromJson<String>(json['title']),
      year: serializer.fromJson<int?>(json['year']),
      showTitle: serializer.fromJson<String?>(json['showTitle']),
      season: serializer.fromJson<int?>(json['season']),
      episode: serializer.fromJson<int?>(json['episode']),
      episodeEnd: serializer.fromJson<int?>(json['episodeEnd']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      probeJson: serializer.fromJson<String?>(json['probeJson']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      artworkPath: serializer.fromJson<String?>(json['artworkPath']),
      subtitlesJson: serializer.fromJson<String?>(json['subtitlesJson']),
      userEditsJson: serializer.fromJson<String?>(json['userEditsJson']),
      detailsJson: serializer.fromJson<String?>(json['detailsJson']),
      providerSourceId: serializer.fromJson<String?>(json['providerSourceId']),
      providerItemType: $LibraryItemsTable.$converterproviderItemTypen.fromJson(
        serializer.fromJson<String?>(json['providerItemType']),
      ),
      providerRemoteKey: serializer.fromJson<String?>(
        json['providerRemoteKey'],
      ),
      providerSeriesKey: serializer.fromJson<String?>(
        json['providerSeriesKey'],
      ),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      unavailableSince: serializer.fromJson<DateTime?>(
        json['unavailableSince'],
      ),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'folderId': serializer.toJson<int>(folderId),
      'relPath': serializer.toJson<String>(relPath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'mtime': serializer.toJson<int>(mtime),
      'quickHash': serializer.toJson<String>(quickHash),
      'kind': serializer.toJson<String>(
        $LibraryItemsTable.$converterkind.toJson(kind),
      ),
      'title': serializer.toJson<String>(title),
      'year': serializer.toJson<int?>(year),
      'showTitle': serializer.toJson<String?>(showTitle),
      'season': serializer.toJson<int?>(season),
      'episode': serializer.toJson<int?>(episode),
      'episodeEnd': serializer.toJson<int?>(episodeEnd),
      'durationMs': serializer.toJson<int?>(durationMs),
      'probeJson': serializer.toJson<String?>(probeJson),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'artworkPath': serializer.toJson<String?>(artworkPath),
      'subtitlesJson': serializer.toJson<String?>(subtitlesJson),
      'userEditsJson': serializer.toJson<String?>(userEditsJson),
      'detailsJson': serializer.toJson<String?>(detailsJson),
      'providerSourceId': serializer.toJson<String?>(providerSourceId),
      'providerItemType': serializer.toJson<String?>(
        $LibraryItemsTable.$converterproviderItemTypen.toJson(providerItemType),
      ),
      'providerRemoteKey': serializer.toJson<String?>(providerRemoteKey),
      'providerSeriesKey': serializer.toJson<String?>(providerSeriesKey),
      'isHidden': serializer.toJson<bool>(isHidden),
      'unavailableSince': serializer.toJson<DateTime?>(unavailableSince),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  LibraryItemRow copyWith({
    int? id,
    int? folderId,
    String? relPath,
    int? sizeBytes,
    int? mtime,
    String? quickHash,
    LibraryKind? kind,
    String? title,
    Value<int?> year = const Value.absent(),
    Value<String?> showTitle = const Value.absent(),
    Value<int?> season = const Value.absent(),
    Value<int?> episode = const Value.absent(),
    Value<int?> episodeEnd = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> probeJson = const Value.absent(),
    Value<String?> thumbnailPath = const Value.absent(),
    Value<String?> artworkPath = const Value.absent(),
    Value<String?> subtitlesJson = const Value.absent(),
    Value<String?> userEditsJson = const Value.absent(),
    Value<String?> detailsJson = const Value.absent(),
    Value<String?> providerSourceId = const Value.absent(),
    Value<VodType?> providerItemType = const Value.absent(),
    Value<String?> providerRemoteKey = const Value.absent(),
    Value<String?> providerSeriesKey = const Value.absent(),
    bool? isHidden,
    Value<DateTime?> unavailableSince = const Value.absent(),
    DateTime? addedAt,
  }) => LibraryItemRow(
    id: id ?? this.id,
    folderId: folderId ?? this.folderId,
    relPath: relPath ?? this.relPath,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mtime: mtime ?? this.mtime,
    quickHash: quickHash ?? this.quickHash,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    year: year.present ? year.value : this.year,
    showTitle: showTitle.present ? showTitle.value : this.showTitle,
    season: season.present ? season.value : this.season,
    episode: episode.present ? episode.value : this.episode,
    episodeEnd: episodeEnd.present ? episodeEnd.value : this.episodeEnd,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    probeJson: probeJson.present ? probeJson.value : this.probeJson,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    artworkPath: artworkPath.present ? artworkPath.value : this.artworkPath,
    subtitlesJson: subtitlesJson.present
        ? subtitlesJson.value
        : this.subtitlesJson,
    userEditsJson: userEditsJson.present
        ? userEditsJson.value
        : this.userEditsJson,
    detailsJson: detailsJson.present ? detailsJson.value : this.detailsJson,
    providerSourceId: providerSourceId.present
        ? providerSourceId.value
        : this.providerSourceId,
    providerItemType: providerItemType.present
        ? providerItemType.value
        : this.providerItemType,
    providerRemoteKey: providerRemoteKey.present
        ? providerRemoteKey.value
        : this.providerRemoteKey,
    providerSeriesKey: providerSeriesKey.present
        ? providerSeriesKey.value
        : this.providerSeriesKey,
    isHidden: isHidden ?? this.isHidden,
    unavailableSince: unavailableSince.present
        ? unavailableSince.value
        : this.unavailableSince,
    addedAt: addedAt ?? this.addedAt,
  );
  LibraryItemRow copyWithCompanion(LibraryItemsCompanion data) {
    return LibraryItemRow(
      id: data.id.present ? data.id.value : this.id,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      quickHash: data.quickHash.present ? data.quickHash.value : this.quickHash,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      year: data.year.present ? data.year.value : this.year,
      showTitle: data.showTitle.present ? data.showTitle.value : this.showTitle,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      episodeEnd: data.episodeEnd.present
          ? data.episodeEnd.value
          : this.episodeEnd,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      probeJson: data.probeJson.present ? data.probeJson.value : this.probeJson,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      artworkPath: data.artworkPath.present
          ? data.artworkPath.value
          : this.artworkPath,
      subtitlesJson: data.subtitlesJson.present
          ? data.subtitlesJson.value
          : this.subtitlesJson,
      userEditsJson: data.userEditsJson.present
          ? data.userEditsJson.value
          : this.userEditsJson,
      detailsJson: data.detailsJson.present
          ? data.detailsJson.value
          : this.detailsJson,
      providerSourceId: data.providerSourceId.present
          ? data.providerSourceId.value
          : this.providerSourceId,
      providerItemType: data.providerItemType.present
          ? data.providerItemType.value
          : this.providerItemType,
      providerRemoteKey: data.providerRemoteKey.present
          ? data.providerRemoteKey.value
          : this.providerRemoteKey,
      providerSeriesKey: data.providerSeriesKey.present
          ? data.providerSeriesKey.value
          : this.providerSeriesKey,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      unavailableSince: data.unavailableSince.present
          ? data.unavailableSince.value
          : this.unavailableSince,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItemRow(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('relPath: $relPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtime: $mtime, ')
          ..write('quickHash: $quickHash, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('showTitle: $showTitle, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('episodeEnd: $episodeEnd, ')
          ..write('durationMs: $durationMs, ')
          ..write('probeJson: $probeJson, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('subtitlesJson: $subtitlesJson, ')
          ..write('userEditsJson: $userEditsJson, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('providerSourceId: $providerSourceId, ')
          ..write('providerItemType: $providerItemType, ')
          ..write('providerRemoteKey: $providerRemoteKey, ')
          ..write('providerSeriesKey: $providerSeriesKey, ')
          ..write('isHidden: $isHidden, ')
          ..write('unavailableSince: $unavailableSince, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    folderId,
    relPath,
    sizeBytes,
    mtime,
    quickHash,
    kind,
    title,
    year,
    showTitle,
    season,
    episode,
    episodeEnd,
    durationMs,
    probeJson,
    thumbnailPath,
    artworkPath,
    subtitlesJson,
    userEditsJson,
    detailsJson,
    providerSourceId,
    providerItemType,
    providerRemoteKey,
    providerSeriesKey,
    isHidden,
    unavailableSince,
    addedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryItemRow &&
          other.id == this.id &&
          other.folderId == this.folderId &&
          other.relPath == this.relPath &&
          other.sizeBytes == this.sizeBytes &&
          other.mtime == this.mtime &&
          other.quickHash == this.quickHash &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.year == this.year &&
          other.showTitle == this.showTitle &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.episodeEnd == this.episodeEnd &&
          other.durationMs == this.durationMs &&
          other.probeJson == this.probeJson &&
          other.thumbnailPath == this.thumbnailPath &&
          other.artworkPath == this.artworkPath &&
          other.subtitlesJson == this.subtitlesJson &&
          other.userEditsJson == this.userEditsJson &&
          other.detailsJson == this.detailsJson &&
          other.providerSourceId == this.providerSourceId &&
          other.providerItemType == this.providerItemType &&
          other.providerRemoteKey == this.providerRemoteKey &&
          other.providerSeriesKey == this.providerSeriesKey &&
          other.isHidden == this.isHidden &&
          other.unavailableSince == this.unavailableSince &&
          other.addedAt == this.addedAt);
}

class LibraryItemsCompanion extends UpdateCompanion<LibraryItemRow> {
  final Value<int> id;
  final Value<int> folderId;
  final Value<String> relPath;
  final Value<int> sizeBytes;
  final Value<int> mtime;
  final Value<String> quickHash;
  final Value<LibraryKind> kind;
  final Value<String> title;
  final Value<int?> year;
  final Value<String?> showTitle;
  final Value<int?> season;
  final Value<int?> episode;
  final Value<int?> episodeEnd;
  final Value<int?> durationMs;
  final Value<String?> probeJson;
  final Value<String?> thumbnailPath;
  final Value<String?> artworkPath;
  final Value<String?> subtitlesJson;
  final Value<String?> userEditsJson;
  final Value<String?> detailsJson;
  final Value<String?> providerSourceId;
  final Value<VodType?> providerItemType;
  final Value<String?> providerRemoteKey;
  final Value<String?> providerSeriesKey;
  final Value<bool> isHidden;
  final Value<DateTime?> unavailableSince;
  final Value<DateTime> addedAt;
  const LibraryItemsCompanion({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mtime = const Value.absent(),
    this.quickHash = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.year = const Value.absent(),
    this.showTitle = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.episodeEnd = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.probeJson = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.subtitlesJson = const Value.absent(),
    this.userEditsJson = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.providerSourceId = const Value.absent(),
    this.providerItemType = const Value.absent(),
    this.providerRemoteKey = const Value.absent(),
    this.providerSeriesKey = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.unavailableSince = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  LibraryItemsCompanion.insert({
    this.id = const Value.absent(),
    required int folderId,
    required String relPath,
    required int sizeBytes,
    required int mtime,
    required String quickHash,
    required LibraryKind kind,
    required String title,
    this.year = const Value.absent(),
    this.showTitle = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.episodeEnd = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.probeJson = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.subtitlesJson = const Value.absent(),
    this.userEditsJson = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.providerSourceId = const Value.absent(),
    this.providerItemType = const Value.absent(),
    this.providerRemoteKey = const Value.absent(),
    this.providerSeriesKey = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.unavailableSince = const Value.absent(),
    required DateTime addedAt,
  }) : folderId = Value(folderId),
       relPath = Value(relPath),
       sizeBytes = Value(sizeBytes),
       mtime = Value(mtime),
       quickHash = Value(quickHash),
       kind = Value(kind),
       title = Value(title),
       addedAt = Value(addedAt);
  static Insertable<LibraryItemRow> custom({
    Expression<int>? id,
    Expression<int>? folderId,
    Expression<String>? relPath,
    Expression<int>? sizeBytes,
    Expression<int>? mtime,
    Expression<String>? quickHash,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<int>? year,
    Expression<String>? showTitle,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<int>? episodeEnd,
    Expression<int>? durationMs,
    Expression<String>? probeJson,
    Expression<String>? thumbnailPath,
    Expression<String>? artworkPath,
    Expression<String>? subtitlesJson,
    Expression<String>? userEditsJson,
    Expression<String>? detailsJson,
    Expression<String>? providerSourceId,
    Expression<String>? providerItemType,
    Expression<String>? providerRemoteKey,
    Expression<String>? providerSeriesKey,
    Expression<bool>? isHidden,
    Expression<DateTime>? unavailableSince,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderId != null) 'folder_id': folderId,
      if (relPath != null) 'rel_path': relPath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mtime != null) 'mtime': mtime,
      if (quickHash != null) 'quick_hash': quickHash,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (year != null) 'year': year,
      if (showTitle != null) 'show_title': showTitle,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (episodeEnd != null) 'episode_end': episodeEnd,
      if (durationMs != null) 'duration_ms': durationMs,
      if (probeJson != null) 'probe_json': probeJson,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (artworkPath != null) 'artwork_path': artworkPath,
      if (subtitlesJson != null) 'subtitles_json': subtitlesJson,
      if (userEditsJson != null) 'user_edits_json': userEditsJson,
      if (detailsJson != null) 'details_json': detailsJson,
      if (providerSourceId != null) 'provider_source_id': providerSourceId,
      if (providerItemType != null) 'provider_item_type': providerItemType,
      if (providerRemoteKey != null) 'provider_remote_key': providerRemoteKey,
      if (providerSeriesKey != null) 'provider_series_key': providerSeriesKey,
      if (isHidden != null) 'is_hidden': isHidden,
      if (unavailableSince != null) 'unavailable_since': unavailableSince,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  LibraryItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? folderId,
    Value<String>? relPath,
    Value<int>? sizeBytes,
    Value<int>? mtime,
    Value<String>? quickHash,
    Value<LibraryKind>? kind,
    Value<String>? title,
    Value<int?>? year,
    Value<String?>? showTitle,
    Value<int?>? season,
    Value<int?>? episode,
    Value<int?>? episodeEnd,
    Value<int?>? durationMs,
    Value<String?>? probeJson,
    Value<String?>? thumbnailPath,
    Value<String?>? artworkPath,
    Value<String?>? subtitlesJson,
    Value<String?>? userEditsJson,
    Value<String?>? detailsJson,
    Value<String?>? providerSourceId,
    Value<VodType?>? providerItemType,
    Value<String?>? providerRemoteKey,
    Value<String?>? providerSeriesKey,
    Value<bool>? isHidden,
    Value<DateTime?>? unavailableSince,
    Value<DateTime>? addedAt,
  }) {
    return LibraryItemsCompanion(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      relPath: relPath ?? this.relPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mtime: mtime ?? this.mtime,
      quickHash: quickHash ?? this.quickHash,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      year: year ?? this.year,
      showTitle: showTitle ?? this.showTitle,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      episodeEnd: episodeEnd ?? this.episodeEnd,
      durationMs: durationMs ?? this.durationMs,
      probeJson: probeJson ?? this.probeJson,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      artworkPath: artworkPath ?? this.artworkPath,
      subtitlesJson: subtitlesJson ?? this.subtitlesJson,
      userEditsJson: userEditsJson ?? this.userEditsJson,
      detailsJson: detailsJson ?? this.detailsJson,
      providerSourceId: providerSourceId ?? this.providerSourceId,
      providerItemType: providerItemType ?? this.providerItemType,
      providerRemoteKey: providerRemoteKey ?? this.providerRemoteKey,
      providerSeriesKey: providerSeriesKey ?? this.providerSeriesKey,
      isHidden: isHidden ?? this.isHidden,
      unavailableSince: unavailableSince ?? this.unavailableSince,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (quickHash.present) {
      map['quick_hash'] = Variable<String>(quickHash.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $LibraryItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (showTitle.present) {
      map['show_title'] = Variable<String>(showTitle.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (episodeEnd.present) {
      map['episode_end'] = Variable<int>(episodeEnd.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (probeJson.present) {
      map['probe_json'] = Variable<String>(probeJson.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (artworkPath.present) {
      map['artwork_path'] = Variable<String>(artworkPath.value);
    }
    if (subtitlesJson.present) {
      map['subtitles_json'] = Variable<String>(subtitlesJson.value);
    }
    if (userEditsJson.present) {
      map['user_edits_json'] = Variable<String>(userEditsJson.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (providerSourceId.present) {
      map['provider_source_id'] = Variable<String>(providerSourceId.value);
    }
    if (providerItemType.present) {
      map['provider_item_type'] = Variable<String>(
        $LibraryItemsTable.$converterproviderItemTypen.toSql(
          providerItemType.value,
        ),
      );
    }
    if (providerRemoteKey.present) {
      map['provider_remote_key'] = Variable<String>(providerRemoteKey.value);
    }
    if (providerSeriesKey.present) {
      map['provider_series_key'] = Variable<String>(providerSeriesKey.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (unavailableSince.present) {
      map['unavailable_since'] = Variable<DateTime>(unavailableSince.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryItemsCompanion(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('relPath: $relPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtime: $mtime, ')
          ..write('quickHash: $quickHash, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('showTitle: $showTitle, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('episodeEnd: $episodeEnd, ')
          ..write('durationMs: $durationMs, ')
          ..write('probeJson: $probeJson, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('subtitlesJson: $subtitlesJson, ')
          ..write('userEditsJson: $userEditsJson, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('providerSourceId: $providerSourceId, ')
          ..write('providerItemType: $providerItemType, ')
          ..write('providerRemoteKey: $providerRemoteKey, ')
          ..write('providerSeriesKey: $providerSeriesKey, ')
          ..write('isHidden: $isHidden, ')
          ..write('unavailableSince: $unavailableSince, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class LibraryFts extends Table
    with
        TableInfo<LibraryFts, LibraryFt>,
        VirtualTableInfo<LibraryFts, LibraryFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LibraryFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _showTitleMeta = const VerificationMeta(
    'showTitle',
  );
  late final GeneratedColumn<String> showTitle = GeneratedColumn<String>(
    'show_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [title, showTitle];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('show_title')) {
      context.handle(
        _showTitleMeta,
        showTitle.isAcceptableOrUnknown(data['show_title']!, _showTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_showTitleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  LibraryFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryFt(
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      showTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}show_title'],
      )!,
    );
  }

  @override
  LibraryFts createAlias(String alias) {
    return LibraryFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(title, show_title, content=\'library_items\', content_rowid=\'id\', tokenize=\'unicode61 remove_diacritics 2\', prefix=\'2 3\')';
}

class LibraryFt extends DataClass implements Insertable<LibraryFt> {
  final String title;
  final String showTitle;
  const LibraryFt({required this.title, required this.showTitle});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title'] = Variable<String>(title);
    map['show_title'] = Variable<String>(showTitle);
    return map;
  }

  LibraryFtsCompanion toCompanion(bool nullToAbsent) {
    return LibraryFtsCompanion(
      title: Value(title),
      showTitle: Value(showTitle),
    );
  }

  factory LibraryFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryFt(
      title: serializer.fromJson<String>(json['title']),
      showTitle: serializer.fromJson<String>(json['show_title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title': serializer.toJson<String>(title),
      'show_title': serializer.toJson<String>(showTitle),
    };
  }

  LibraryFt copyWith({String? title, String? showTitle}) => LibraryFt(
    title: title ?? this.title,
    showTitle: showTitle ?? this.showTitle,
  );
  LibraryFt copyWithCompanion(LibraryFtsCompanion data) {
    return LibraryFt(
      title: data.title.present ? data.title.value : this.title,
      showTitle: data.showTitle.present ? data.showTitle.value : this.showTitle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFt(')
          ..write('title: $title, ')
          ..write('showTitle: $showTitle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(title, showTitle);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryFt &&
          other.title == this.title &&
          other.showTitle == this.showTitle);
}

class LibraryFtsCompanion extends UpdateCompanion<LibraryFt> {
  final Value<String> title;
  final Value<String> showTitle;
  final Value<int> rowid;
  const LibraryFtsCompanion({
    this.title = const Value.absent(),
    this.showTitle = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryFtsCompanion.insert({
    required String title,
    required String showTitle,
    this.rowid = const Value.absent(),
  }) : title = Value(title),
       showTitle = Value(showTitle);
  static Insertable<LibraryFt> custom({
    Expression<String>? title,
    Expression<String>? showTitle,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (title != null) 'title': title,
      if (showTitle != null) 'show_title': showTitle,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryFtsCompanion copyWith({
    Value<String>? title,
    Value<String>? showTitle,
    Value<int>? rowid,
  }) {
    return LibraryFtsCompanion(
      title: title ?? this.title,
      showTitle: showTitle ?? this.showTitle,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (showTitle.present) {
      map['show_title'] = Variable<String>(showTitle.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryFtsCompanion(')
          ..write('title: $title, ')
          ..write('showTitle: $showTitle, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteGroupsTable extends FavoriteGroups
    with TableInfo<$FavoriteGroupsTable, FavoriteGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _collapsedMeta = const VerificationMeta(
    'collapsed',
  );
  @override
  late final GeneratedColumn<bool> collapsed = GeneratedColumn<bool>(
    'collapsed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collapsed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    name,
    sortOrder,
    collapsed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('collapsed')) {
      context.handle(
        _collapsedMeta,
        collapsed.isAcceptableOrUnknown(data['collapsed']!, _collapsedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FavoriteGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      collapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collapsed'],
      )!,
    );
  }

  @override
  $FavoriteGroupsTable createAlias(String alias) {
    return $FavoriteGroupsTable(attachedDatabase, alias);
  }
}

class FavoriteGroupRow extends DataClass
    implements Insertable<FavoriteGroupRow> {
  final int id;
  final String sourceId;
  final String name;
  final int sortOrder;
  final bool collapsed;
  const FavoriteGroupRow({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.sortOrder,
    required this.collapsed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['collapsed'] = Variable<bool>(collapsed);
    return map;
  }

  FavoriteGroupsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteGroupsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      name: Value(name),
      sortOrder: Value(sortOrder),
      collapsed: Value(collapsed),
    );
  }

  factory FavoriteGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteGroupRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      collapsed: serializer.fromJson<bool>(json['collapsed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'collapsed': serializer.toJson<bool>(collapsed),
    };
  }

  FavoriteGroupRow copyWith({
    int? id,
    String? sourceId,
    String? name,
    int? sortOrder,
    bool? collapsed,
  }) => FavoriteGroupRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    collapsed: collapsed ?? this.collapsed,
  );
  FavoriteGroupRow copyWithCompanion(FavoriteGroupsCompanion data) {
    return FavoriteGroupRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      collapsed: data.collapsed.present ? data.collapsed.value : this.collapsed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteGroupRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('collapsed: $collapsed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, name, sortOrder, collapsed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteGroupRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.collapsed == this.collapsed);
}

class FavoriteGroupsCompanion extends UpdateCompanion<FavoriteGroupRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<bool> collapsed;
  const FavoriteGroupsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.collapsed = const Value.absent(),
  });
  FavoriteGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required String name,
    this.sortOrder = const Value.absent(),
    this.collapsed = const Value.absent(),
  }) : sourceId = Value(sourceId),
       name = Value(name);
  static Insertable<FavoriteGroupRow> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<bool>? collapsed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (collapsed != null) 'collapsed': collapsed,
    });
  }

  FavoriteGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<bool>? collapsed,
  }) {
    return FavoriteGroupsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      collapsed: collapsed ?? this.collapsed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (collapsed.present) {
      map['collapsed'] = Variable<bool>(collapsed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteGroupsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('collapsed: $collapsed')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<UserItemType, String> itemType =
      GeneratedColumn<String>(
        'item_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<UserItemType>($FavoritesTable.$converteritemType);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES favorite_groups (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemType,
    sourceId,
    remoteKey,
    groupId,
    sortOrder,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {itemType, sourceId, remoteKey},
  ];
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemType: $FavoritesTable.$converteritemType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}item_type'],
        )!,
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<UserItemType, String, String> $converteritemType =
      const EnumNameConverter<UserItemType>(UserItemType.values);
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final int id;
  final UserItemType itemType;

  /// Null only for local library files (Phase 8).
  final String? sourceId;
  final String remoteKey;

  /// The user's group of favorite channels it is in (v7); null is none.
  /// Deleting the group leaves it a favorite, in no group.
  final int? groupId;

  /// Its place in the user's order; null sorts after every placed one,
  /// by [addedAt].
  final int? sortOrder;
  final DateTime addedAt;
  const FavoriteRow({
    required this.id,
    required this.itemType,
    this.sourceId,
    required this.remoteKey,
    this.groupId,
    this.sortOrder,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['item_type'] = Variable<String>(
        $FavoritesTable.$converteritemType.toSql(itemType),
      );
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['remote_key'] = Variable<String>(remoteKey);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      id: Value(id),
      itemType: Value(itemType),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      remoteKey: Value(remoteKey),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
      addedAt: Value(addedAt),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      id: serializer.fromJson<int>(json['id']),
      itemType: $FavoritesTable.$converteritemType.fromJson(
        serializer.fromJson<String>(json['itemType']),
      ),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      remoteKey: serializer.fromJson<String>(json['remoteKey']),
      groupId: serializer.fromJson<int?>(json['groupId']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemType': serializer.toJson<String>(
        $FavoritesTable.$converteritemType.toJson(itemType),
      ),
      'sourceId': serializer.toJson<String?>(sourceId),
      'remoteKey': serializer.toJson<String>(remoteKey),
      'groupId': serializer.toJson<int?>(groupId),
      'sortOrder': serializer.toJson<int?>(sortOrder),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoriteRow copyWith({
    int? id,
    UserItemType? itemType,
    Value<String?> sourceId = const Value.absent(),
    String? remoteKey,
    Value<int?> groupId = const Value.absent(),
    Value<int?> sortOrder = const Value.absent(),
    DateTime? addedAt,
  }) => FavoriteRow(
    id: id ?? this.id,
    itemType: itemType ?? this.itemType,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    remoteKey: remoteKey ?? this.remoteKey,
    groupId: groupId.present ? groupId.value : this.groupId,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
    addedAt: addedAt ?? this.addedAt,
  );
  FavoriteRow copyWithCompanion(FavoritesCompanion data) {
    return FavoriteRow(
      id: data.id.present ? data.id.value : this.id,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('id: $id, ')
          ..write('itemType: $itemType, ')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('groupId: $groupId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemType,
    sourceId,
    remoteKey,
    groupId,
    sortOrder,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.id == this.id &&
          other.itemType == this.itemType &&
          other.sourceId == this.sourceId &&
          other.remoteKey == this.remoteKey &&
          other.groupId == this.groupId &&
          other.sortOrder == this.sortOrder &&
          other.addedAt == this.addedAt);
}

class FavoritesCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<int> id;
  final Value<UserItemType> itemType;
  final Value<String?> sourceId;
  final Value<String> remoteKey;
  final Value<int?> groupId;
  final Value<int?> sortOrder;
  final Value<DateTime> addedAt;
  const FavoritesCompanion({
    this.id = const Value.absent(),
    this.itemType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.groupId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  FavoritesCompanion.insert({
    this.id = const Value.absent(),
    required UserItemType itemType,
    this.sourceId = const Value.absent(),
    required String remoteKey,
    this.groupId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime addedAt,
  }) : itemType = Value(itemType),
       remoteKey = Value(remoteKey),
       addedAt = Value(addedAt);
  static Insertable<FavoriteRow> custom({
    Expression<int>? id,
    Expression<String>? itemType,
    Expression<String>? sourceId,
    Expression<String>? remoteKey,
    Expression<int>? groupId,
    Expression<int>? sortOrder,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemType != null) 'item_type': itemType,
      if (sourceId != null) 'source_id': sourceId,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (groupId != null) 'group_id': groupId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  FavoritesCompanion copyWith({
    Value<int>? id,
    Value<UserItemType>? itemType,
    Value<String?>? sourceId,
    Value<String>? remoteKey,
    Value<int?>? groupId,
    Value<int?>? sortOrder,
    Value<DateTime>? addedAt,
  }) {
    return FavoritesCompanion(
      id: id ?? this.id,
      itemType: itemType ?? this.itemType,
      sourceId: sourceId ?? this.sourceId,
      remoteKey: remoteKey ?? this.remoteKey,
      groupId: groupId ?? this.groupId,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(
        $FavoritesTable.$converteritemType.toSql(itemType.value),
      );
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('id: $id, ')
          ..write('itemType: $itemType, ')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('groupId: $groupId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $WatchHistoryTable extends WatchHistory
    with TableInfo<$WatchHistoryTable, WatchHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchHistoryTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<UserItemType, String> itemType =
      GeneratedColumn<String>(
        'item_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<UserItemType>($WatchHistoryTable.$converteritemType);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
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
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta(
    'dismissed',
  );
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dismissed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemType,
    sourceId,
    remoteKey,
    positionMs,
    durationMs,
    completed,
    seriesKey,
    dismissed,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    }
    if (data.containsKey('dismissed')) {
      context.handle(
        _dismissedMeta,
        dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {itemType, sourceId, remoteKey},
  ];
  @override
  WatchHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemType: $WatchHistoryTable.$converteritemType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}item_type'],
        )!,
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      ),
      dismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dismissed'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WatchHistoryTable createAlias(String alias) {
    return $WatchHistoryTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<UserItemType, String, String> $converteritemType =
      const EnumNameConverter<UserItemType>(UserItemType.values);
}

class WatchHistoryRow extends DataClass implements Insertable<WatchHistoryRow> {
  final int id;
  final UserItemType itemType;
  final String? sourceId;
  final String remoteKey;
  final int positionMs;
  final int? durationMs;
  final bool completed;

  /// An episode's series (its remote key), so Continue watching needs no
  /// join through the episode cache, which a re-fetch replaces (v6).
  final String? seriesKey;

  /// Taken out of Continue watching by the user; watching it again clears
  /// it (v6).
  final bool dismissed;
  final DateTime updatedAt;
  const WatchHistoryRow({
    required this.id,
    required this.itemType,
    this.sourceId,
    required this.remoteKey,
    required this.positionMs,
    this.durationMs,
    required this.completed,
    this.seriesKey,
    required this.dismissed,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['item_type'] = Variable<String>(
        $WatchHistoryTable.$converteritemType.toSql(itemType),
      );
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['remote_key'] = Variable<String>(remoteKey);
    map['position_ms'] = Variable<int>(positionMs);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || seriesKey != null) {
      map['series_key'] = Variable<String>(seriesKey);
    }
    map['dismissed'] = Variable<bool>(dismissed);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WatchHistoryCompanion toCompanion(bool nullToAbsent) {
    return WatchHistoryCompanion(
      id: Value(id),
      itemType: Value(itemType),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      remoteKey: Value(remoteKey),
      positionMs: Value(positionMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      completed: Value(completed),
      seriesKey: seriesKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesKey),
      dismissed: Value(dismissed),
      updatedAt: Value(updatedAt),
    );
  }

  factory WatchHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchHistoryRow(
      id: serializer.fromJson<int>(json['id']),
      itemType: $WatchHistoryTable.$converteritemType.fromJson(
        serializer.fromJson<String>(json['itemType']),
      ),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      remoteKey: serializer.fromJson<String>(json['remoteKey']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      completed: serializer.fromJson<bool>(json['completed']),
      seriesKey: serializer.fromJson<String?>(json['seriesKey']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemType': serializer.toJson<String>(
        $WatchHistoryTable.$converteritemType.toJson(itemType),
      ),
      'sourceId': serializer.toJson<String?>(sourceId),
      'remoteKey': serializer.toJson<String>(remoteKey),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'completed': serializer.toJson<bool>(completed),
      'seriesKey': serializer.toJson<String?>(seriesKey),
      'dismissed': serializer.toJson<bool>(dismissed),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WatchHistoryRow copyWith({
    int? id,
    UserItemType? itemType,
    Value<String?> sourceId = const Value.absent(),
    String? remoteKey,
    int? positionMs,
    Value<int?> durationMs = const Value.absent(),
    bool? completed,
    Value<String?> seriesKey = const Value.absent(),
    bool? dismissed,
    DateTime? updatedAt,
  }) => WatchHistoryRow(
    id: id ?? this.id,
    itemType: itemType ?? this.itemType,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    remoteKey: remoteKey ?? this.remoteKey,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    completed: completed ?? this.completed,
    seriesKey: seriesKey.present ? seriesKey.value : this.seriesKey,
    dismissed: dismissed ?? this.dismissed,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WatchHistoryRow copyWithCompanion(WatchHistoryCompanion data) {
    return WatchHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      completed: data.completed.present ? data.completed.value : this.completed,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryRow(')
          ..write('id: $id, ')
          ..write('itemType: $itemType, ')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('completed: $completed, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('dismissed: $dismissed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemType,
    sourceId,
    remoteKey,
    positionMs,
    durationMs,
    completed,
    seriesKey,
    dismissed,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryRow &&
          other.id == this.id &&
          other.itemType == this.itemType &&
          other.sourceId == this.sourceId &&
          other.remoteKey == this.remoteKey &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.completed == this.completed &&
          other.seriesKey == this.seriesKey &&
          other.dismissed == this.dismissed &&
          other.updatedAt == this.updatedAt);
}

class WatchHistoryCompanion extends UpdateCompanion<WatchHistoryRow> {
  final Value<int> id;
  final Value<UserItemType> itemType;
  final Value<String?> sourceId;
  final Value<String> remoteKey;
  final Value<int> positionMs;
  final Value<int?> durationMs;
  final Value<bool> completed;
  final Value<String?> seriesKey;
  final Value<bool> dismissed;
  final Value<DateTime> updatedAt;
  const WatchHistoryCompanion({
    this.id = const Value.absent(),
    this.itemType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  WatchHistoryCompanion.insert({
    this.id = const Value.absent(),
    required UserItemType itemType,
    this.sourceId = const Value.absent(),
    required String remoteKey,
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.dismissed = const Value.absent(),
    required DateTime updatedAt,
  }) : itemType = Value(itemType),
       remoteKey = Value(remoteKey),
       updatedAt = Value(updatedAt);
  static Insertable<WatchHistoryRow> custom({
    Expression<int>? id,
    Expression<String>? itemType,
    Expression<String>? sourceId,
    Expression<String>? remoteKey,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<bool>? completed,
    Expression<String>? seriesKey,
    Expression<bool>? dismissed,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemType != null) 'item_type': itemType,
      if (sourceId != null) 'source_id': sourceId,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (completed != null) 'completed': completed,
      if (seriesKey != null) 'series_key': seriesKey,
      if (dismissed != null) 'dismissed': dismissed,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  WatchHistoryCompanion copyWith({
    Value<int>? id,
    Value<UserItemType>? itemType,
    Value<String?>? sourceId,
    Value<String>? remoteKey,
    Value<int>? positionMs,
    Value<int?>? durationMs,
    Value<bool>? completed,
    Value<String?>? seriesKey,
    Value<bool>? dismissed,
    Value<DateTime>? updatedAt,
  }) {
    return WatchHistoryCompanion(
      id: id ?? this.id,
      itemType: itemType ?? this.itemType,
      sourceId: sourceId ?? this.sourceId,
      remoteKey: remoteKey ?? this.remoteKey,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      completed: completed ?? this.completed,
      seriesKey: seriesKey ?? this.seriesKey,
      dismissed: dismissed ?? this.dismissed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(
        $WatchHistoryTable.$converteritemType.toSql(itemType.value),
      );
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryCompanion(')
          ..write('id: $id, ')
          ..write('itemType: $itemType, ')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('completed: $completed, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('dismissed: $dismissed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
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
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;

  /// Always valid JSON, so a reader can decode without guessing. Readers
  /// still treat a bad value as missing (hard rule 1).
  final String valueJson;
  final DateTime updatedAt;
  const SettingRow({
    required this.key,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SettingRow copyWith({String? key, String? valueJson, DateTime? updatedAt}) =>
      SettingRow(
        key: key ?? this.key,
        valueJson: valueJson ?? this.valueJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String valueJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, DownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<VodType, String> itemType =
      GeneratedColumn<String>(
        'item_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<VodType>($DownloadsTable.$converteritemType);
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesRemoteKeyMeta = const VerificationMeta(
    'seriesRemoteKey',
  );
  @override
  late final GeneratedColumn<String> seriesRemoteKey = GeneratedColumn<String>(
    'series_remote_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _showTitleMeta = const VerificationMeta(
    'showTitle',
  );
  @override
  late final GeneratedColumn<String> showTitle = GeneratedColumn<String>(
    'show_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetPathMeta = const VerificationMeta(
    'targetPath',
  );
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
    'target_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
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
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<String> lastModified = GeneratedColumn<String>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadTaskState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DownloadTaskState>($DownloadsTable.$converterstate);
  @override
  late final GeneratedColumnWithTypeConverter<DownloadProblem?, String>
  errorClass = GeneratedColumn<String>(
    'error_class',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<DownloadProblem?>($DownloadsTable.$convertererrorClassn);
  static const VerificationMeta _errorDetailMeta = const VerificationMeta(
    'errorDetail',
  );
  @override
  late final GeneratedColumn<String> errorDetail = GeneratedColumn<String>(
    'error_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _libraryItemIdMeta = const VerificationMeta(
    'libraryItemId',
  );
  @override
  late final GeneratedColumn<int> libraryItemId = GeneratedColumn<int>(
    'library_item_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES library_items (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
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
    sourceId,
    itemType,
    remoteKey,
    seriesRemoteKey,
    season,
    episode,
    title,
    showTitle,
    year,
    artworkUrl,
    targetPath,
    totalBytes,
    downloadedBytes,
    etag,
    lastModified,
    state,
    errorClass,
    errorDetail,
    attempts,
    libraryItemId,
    sortOrder,
    createdAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('series_remote_key')) {
      context.handle(
        _seriesRemoteKeyMeta,
        seriesRemoteKey.isAcceptableOrUnknown(
          data['series_remote_key']!,
          _seriesRemoteKeyMeta,
        ),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('show_title')) {
      context.handle(
        _showTitleMeta,
        showTitle.isAcceptableOrUnknown(data['show_title']!, _showTitleMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('target_path')) {
      context.handle(
        _targetPathMeta,
        targetPath.isAcceptableOrUnknown(data['target_path']!, _targetPathMeta),
      );
    } else if (isInserting) {
      context.missing(_targetPathMeta);
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
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
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('error_detail')) {
      context.handle(
        _errorDetailMeta,
        errorDetail.isAcceptableOrUnknown(
          data['error_detail']!,
          _errorDetailMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('library_item_id')) {
      context.handle(
        _libraryItemIdMeta,
        libraryItemId.isAcceptableOrUnknown(
          data['library_item_id']!,
          _libraryItemIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
    {sourceId, itemType, remoteKey},
  ];
  @override
  DownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      itemType: $DownloadsTable.$converteritemType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}item_type'],
        )!,
      ),
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      seriesRemoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_remote_key'],
      ),
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      ),
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      showTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}show_title'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      targetPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_path'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified'],
      ),
      state: $DownloadsTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      errorClass: $DownloadsTable.$convertererrorClassn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}error_class'],
        ),
      ),
      errorDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_detail'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      libraryItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}library_item_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
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

  static JsonTypeConverter2<VodType, String, String> $converteritemType =
      const EnumNameConverter<VodType>(VodType.values);
  static JsonTypeConverter2<DownloadTaskState, String, String> $converterstate =
      const EnumNameConverter<DownloadTaskState>(DownloadTaskState.values);
  static JsonTypeConverter2<DownloadProblem, String, String>
  $convertererrorClass = const EnumNameConverter<DownloadProblem>(
    DownloadProblem.values,
  );
  static JsonTypeConverter2<DownloadProblem?, String?, String?>
  $convertererrorClassn = JsonTypeConverter2.asNullable($convertererrorClass);
}

class DownloadRow extends DataClass implements Insertable<DownloadRow> {
  final int id;
  final String sourceId;
  final VodType itemType;
  final String remoteKey;
  final String? seriesRemoteKey;
  final int? season;
  final int? episode;

  /// A movie's title, or an episode's own.
  final String title;

  /// An episode's series name (v9: the Downloads list shows it).
  final String? showTitle;

  /// A movie's year (v9: the Downloads list shows it).
  final int? year;
  final String? artworkUrl;

  /// The file it becomes; `<target_path>.part` until it is verified.
  final String targetPath;
  final int? totalBytes;
  final int downloadedBytes;

  /// What a resume's `If-Range` sends: the ETag, else Last-Modified.
  final String? etag;
  final String? lastModified;
  final DownloadTaskState state;
  final DownloadProblem? errorClass;

  /// Redacted before it is written (hard rule 3).
  final String? errorDetail;
  final int attempts;
  final int? libraryItemId;

  /// Its place in the queue, lower first (v9: docs/05's drag to
  /// reorder).
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? completedAt;
  const DownloadRow({
    required this.id,
    required this.sourceId,
    required this.itemType,
    required this.remoteKey,
    this.seriesRemoteKey,
    this.season,
    this.episode,
    required this.title,
    this.showTitle,
    this.year,
    this.artworkUrl,
    required this.targetPath,
    this.totalBytes,
    required this.downloadedBytes,
    this.etag,
    this.lastModified,
    required this.state,
    this.errorClass,
    this.errorDetail,
    required this.attempts,
    this.libraryItemId,
    required this.sortOrder,
    required this.createdAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    {
      map['item_type'] = Variable<String>(
        $DownloadsTable.$converteritemType.toSql(itemType),
      );
    }
    map['remote_key'] = Variable<String>(remoteKey);
    if (!nullToAbsent || seriesRemoteKey != null) {
      map['series_remote_key'] = Variable<String>(seriesRemoteKey);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<int>(season);
    }
    if (!nullToAbsent || episode != null) {
      map['episode'] = Variable<int>(episode);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || showTitle != null) {
      map['show_title'] = Variable<String>(showTitle);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    map['target_path'] = Variable<String>(targetPath);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<String>(lastModified);
    }
    {
      map['state'] = Variable<String>(
        $DownloadsTable.$converterstate.toSql(state),
      );
    }
    if (!nullToAbsent || errorClass != null) {
      map['error_class'] = Variable<String>(
        $DownloadsTable.$convertererrorClassn.toSql(errorClass),
      );
    }
    if (!nullToAbsent || errorDetail != null) {
      map['error_detail'] = Variable<String>(errorDetail);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || libraryItemId != null) {
      map['library_item_id'] = Variable<int>(libraryItemId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      itemType: Value(itemType),
      remoteKey: Value(remoteKey),
      seriesRemoteKey: seriesRemoteKey == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesRemoteKey),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      episode: episode == null && nullToAbsent
          ? const Value.absent()
          : Value(episode),
      title: Value(title),
      showTitle: showTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(showTitle),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      targetPath: Value(targetPath),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      downloadedBytes: Value(downloadedBytes),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      state: Value(state),
      errorClass: errorClass == null && nullToAbsent
          ? const Value.absent()
          : Value(errorClass),
      errorDetail: errorDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(errorDetail),
      attempts: Value(attempts),
      libraryItemId: libraryItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(libraryItemId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      itemType: $DownloadsTable.$converteritemType.fromJson(
        serializer.fromJson<String>(json['itemType']),
      ),
      remoteKey: serializer.fromJson<String>(json['remoteKey']),
      seriesRemoteKey: serializer.fromJson<String?>(json['seriesRemoteKey']),
      season: serializer.fromJson<int?>(json['season']),
      episode: serializer.fromJson<int?>(json['episode']),
      title: serializer.fromJson<String>(json['title']),
      showTitle: serializer.fromJson<String?>(json['showTitle']),
      year: serializer.fromJson<int?>(json['year']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      targetPath: serializer.fromJson<String>(json['targetPath']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      etag: serializer.fromJson<String?>(json['etag']),
      lastModified: serializer.fromJson<String?>(json['lastModified']),
      state: $DownloadsTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      errorClass: $DownloadsTable.$convertererrorClassn.fromJson(
        serializer.fromJson<String?>(json['errorClass']),
      ),
      errorDetail: serializer.fromJson<String?>(json['errorDetail']),
      attempts: serializer.fromJson<int>(json['attempts']),
      libraryItemId: serializer.fromJson<int?>(json['libraryItemId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'itemType': serializer.toJson<String>(
        $DownloadsTable.$converteritemType.toJson(itemType),
      ),
      'remoteKey': serializer.toJson<String>(remoteKey),
      'seriesRemoteKey': serializer.toJson<String?>(seriesRemoteKey),
      'season': serializer.toJson<int?>(season),
      'episode': serializer.toJson<int?>(episode),
      'title': serializer.toJson<String>(title),
      'showTitle': serializer.toJson<String?>(showTitle),
      'year': serializer.toJson<int?>(year),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'targetPath': serializer.toJson<String>(targetPath),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'etag': serializer.toJson<String?>(etag),
      'lastModified': serializer.toJson<String?>(lastModified),
      'state': serializer.toJson<String>(
        $DownloadsTable.$converterstate.toJson(state),
      ),
      'errorClass': serializer.toJson<String?>(
        $DownloadsTable.$convertererrorClassn.toJson(errorClass),
      ),
      'errorDetail': serializer.toJson<String?>(errorDetail),
      'attempts': serializer.toJson<int>(attempts),
      'libraryItemId': serializer.toJson<int?>(libraryItemId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadRow copyWith({
    int? id,
    String? sourceId,
    VodType? itemType,
    String? remoteKey,
    Value<String?> seriesRemoteKey = const Value.absent(),
    Value<int?> season = const Value.absent(),
    Value<int?> episode = const Value.absent(),
    String? title,
    Value<String?> showTitle = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    String? targetPath,
    Value<int?> totalBytes = const Value.absent(),
    int? downloadedBytes,
    Value<String?> etag = const Value.absent(),
    Value<String?> lastModified = const Value.absent(),
    DownloadTaskState? state,
    Value<DownloadProblem?> errorClass = const Value.absent(),
    Value<String?> errorDetail = const Value.absent(),
    int? attempts,
    Value<int?> libraryItemId = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    itemType: itemType ?? this.itemType,
    remoteKey: remoteKey ?? this.remoteKey,
    seriesRemoteKey: seriesRemoteKey.present
        ? seriesRemoteKey.value
        : this.seriesRemoteKey,
    season: season.present ? season.value : this.season,
    episode: episode.present ? episode.value : this.episode,
    title: title ?? this.title,
    showTitle: showTitle.present ? showTitle.value : this.showTitle,
    year: year.present ? year.value : this.year,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    targetPath: targetPath ?? this.targetPath,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    etag: etag.present ? etag.value : this.etag,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    state: state ?? this.state,
    errorClass: errorClass.present ? errorClass.value : this.errorClass,
    errorDetail: errorDetail.present ? errorDetail.value : this.errorDetail,
    attempts: attempts ?? this.attempts,
    libraryItemId: libraryItemId.present
        ? libraryItemId.value
        : this.libraryItemId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadRow copyWithCompanion(DownloadsCompanion data) {
    return DownloadRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      seriesRemoteKey: data.seriesRemoteKey.present
          ? data.seriesRemoteKey.value
          : this.seriesRemoteKey,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      title: data.title.present ? data.title.value : this.title,
      showTitle: data.showTitle.present ? data.showTitle.value : this.showTitle,
      year: data.year.present ? data.year.value : this.year,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      targetPath: data.targetPath.present
          ? data.targetPath.value
          : this.targetPath,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      etag: data.etag.present ? data.etag.value : this.etag,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      state: data.state.present ? data.state.value : this.state,
      errorClass: data.errorClass.present
          ? data.errorClass.value
          : this.errorClass,
      errorDetail: data.errorDetail.present
          ? data.errorDetail.value
          : this.errorDetail,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      libraryItemId: data.libraryItemId.present
          ? data.libraryItemId.value
          : this.libraryItemId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('itemType: $itemType, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('seriesRemoteKey: $seriesRemoteKey, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('title: $title, ')
          ..write('showTitle: $showTitle, ')
          ..write('year: $year, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('targetPath: $targetPath, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('state: $state, ')
          ..write('errorClass: $errorClass, ')
          ..write('errorDetail: $errorDetail, ')
          ..write('attempts: $attempts, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    sourceId,
    itemType,
    remoteKey,
    seriesRemoteKey,
    season,
    episode,
    title,
    showTitle,
    year,
    artworkUrl,
    targetPath,
    totalBytes,
    downloadedBytes,
    etag,
    lastModified,
    state,
    errorClass,
    errorDetail,
    attempts,
    libraryItemId,
    sortOrder,
    createdAt,
    completedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.itemType == this.itemType &&
          other.remoteKey == this.remoteKey &&
          other.seriesRemoteKey == this.seriesRemoteKey &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.title == this.title &&
          other.showTitle == this.showTitle &&
          other.year == this.year &&
          other.artworkUrl == this.artworkUrl &&
          other.targetPath == this.targetPath &&
          other.totalBytes == this.totalBytes &&
          other.downloadedBytes == this.downloadedBytes &&
          other.etag == this.etag &&
          other.lastModified == this.lastModified &&
          other.state == this.state &&
          other.errorClass == this.errorClass &&
          other.errorDetail == this.errorDetail &&
          other.attempts == this.attempts &&
          other.libraryItemId == this.libraryItemId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt);
}

class DownloadsCompanion extends UpdateCompanion<DownloadRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<VodType> itemType;
  final Value<String> remoteKey;
  final Value<String?> seriesRemoteKey;
  final Value<int?> season;
  final Value<int?> episode;
  final Value<String> title;
  final Value<String?> showTitle;
  final Value<int?> year;
  final Value<String?> artworkUrl;
  final Value<String> targetPath;
  final Value<int?> totalBytes;
  final Value<int> downloadedBytes;
  final Value<String?> etag;
  final Value<String?> lastModified;
  final Value<DownloadTaskState> state;
  final Value<DownloadProblem?> errorClass;
  final Value<String?> errorDetail;
  final Value<int> attempts;
  final Value<int?> libraryItemId;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime?> completedAt;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.seriesRemoteKey = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.title = const Value.absent(),
    this.showTitle = const Value.absent(),
    this.year = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.state = const Value.absent(),
    this.errorClass = const Value.absent(),
    this.errorDetail = const Value.absent(),
    this.attempts = const Value.absent(),
    this.libraryItemId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  DownloadsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required VodType itemType,
    required String remoteKey,
    this.seriesRemoteKey = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    required String title,
    this.showTitle = const Value.absent(),
    this.year = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    required String targetPath,
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.etag = const Value.absent(),
    this.lastModified = const Value.absent(),
    required DownloadTaskState state,
    this.errorClass = const Value.absent(),
    this.errorDetail = const Value.absent(),
    this.attempts = const Value.absent(),
    this.libraryItemId = const Value.absent(),
    required int sortOrder,
    required DateTime createdAt,
    this.completedAt = const Value.absent(),
  }) : sourceId = Value(sourceId),
       itemType = Value(itemType),
       remoteKey = Value(remoteKey),
       title = Value(title),
       targetPath = Value(targetPath),
       state = Value(state),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt);
  static Insertable<DownloadRow> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<String>? itemType,
    Expression<String>? remoteKey,
    Expression<String>? seriesRemoteKey,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<String>? title,
    Expression<String>? showTitle,
    Expression<int>? year,
    Expression<String>? artworkUrl,
    Expression<String>? targetPath,
    Expression<int>? totalBytes,
    Expression<int>? downloadedBytes,
    Expression<String>? etag,
    Expression<String>? lastModified,
    Expression<String>? state,
    Expression<String>? errorClass,
    Expression<String>? errorDetail,
    Expression<int>? attempts,
    Expression<int>? libraryItemId,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (itemType != null) 'item_type': itemType,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (seriesRemoteKey != null) 'series_remote_key': seriesRemoteKey,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (title != null) 'title': title,
      if (showTitle != null) 'show_title': showTitle,
      if (year != null) 'year': year,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (targetPath != null) 'target_path': targetPath,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (etag != null) 'etag': etag,
      if (lastModified != null) 'last_modified': lastModified,
      if (state != null) 'state': state,
      if (errorClass != null) 'error_class': errorClass,
      if (errorDetail != null) 'error_detail': errorDetail,
      if (attempts != null) 'attempts': attempts,
      if (libraryItemId != null) 'library_item_id': libraryItemId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  DownloadsCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<VodType>? itemType,
    Value<String>? remoteKey,
    Value<String?>? seriesRemoteKey,
    Value<int?>? season,
    Value<int?>? episode,
    Value<String>? title,
    Value<String?>? showTitle,
    Value<int?>? year,
    Value<String?>? artworkUrl,
    Value<String>? targetPath,
    Value<int?>? totalBytes,
    Value<int>? downloadedBytes,
    Value<String?>? etag,
    Value<String?>? lastModified,
    Value<DownloadTaskState>? state,
    Value<DownloadProblem?>? errorClass,
    Value<String?>? errorDetail,
    Value<int>? attempts,
    Value<int?>? libraryItemId,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime?>? completedAt,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      itemType: itemType ?? this.itemType,
      remoteKey: remoteKey ?? this.remoteKey,
      seriesRemoteKey: seriesRemoteKey ?? this.seriesRemoteKey,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      title: title ?? this.title,
      showTitle: showTitle ?? this.showTitle,
      year: year ?? this.year,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      targetPath: targetPath ?? this.targetPath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      state: state ?? this.state,
      errorClass: errorClass ?? this.errorClass,
      errorDetail: errorDetail ?? this.errorDetail,
      attempts: attempts ?? this.attempts,
      libraryItemId: libraryItemId ?? this.libraryItemId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(
        $DownloadsTable.$converteritemType.toSql(itemType.value),
      );
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (seriesRemoteKey.present) {
      map['series_remote_key'] = Variable<String>(seriesRemoteKey.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (showTitle.present) {
      map['show_title'] = Variable<String>(showTitle.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<String>(lastModified.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $DownloadsTable.$converterstate.toSql(state.value),
      );
    }
    if (errorClass.present) {
      map['error_class'] = Variable<String>(
        $DownloadsTable.$convertererrorClassn.toSql(errorClass.value),
      );
    }
    if (errorDetail.present) {
      map['error_detail'] = Variable<String>(errorDetail.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (libraryItemId.present) {
      map['library_item_id'] = Variable<int>(libraryItemId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('itemType: $itemType, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('seriesRemoteKey: $seriesRemoteKey, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('title: $title, ')
          ..write('showTitle: $showTitle, ')
          ..write('year: $year, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('targetPath: $targetPath, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('etag: $etag, ')
          ..write('lastModified: $lastModified, ')
          ..write('state: $state, ')
          ..write('errorClass: $errorClass, ')
          ..write('errorDetail: $errorDetail, ')
          ..write('attempts: $attempts, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seenRunMeta = const VerificationMeta(
    'seenRun',
  );
  @override
  late final GeneratedColumn<int> seenRun = GeneratedColumn<int>(
    'seen_run',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
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
  @override
  late final GeneratedColumnWithTypeConverter<CatalogueKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CatalogueKind>($CategoriesTable.$converterkind);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteKey,
    position,
    seenRun,
    id,
    kind,
    name,
    displayName,
    isHidden,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('seen_run')) {
      context.handle(
        _seenRunMeta,
        seenRun.isAcceptableOrUnknown(data['seen_run']!, _seenRunMeta),
      );
    }
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
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, kind, remoteKey},
  ];
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      seenRun: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_run'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: $CategoriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CatalogueKind, String, String> $converterkind =
      const EnumNameConverter<CatalogueKind>(CatalogueKind.values);
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String sourceId;
  final String remoteKey;

  /// The provider's own order, rewritten by every sync.
  final int position;

  /// The sync run that last saw this row. See [SyncRuns].
  final int? seenRun;
  final int id;
  final CatalogueKind kind;
  final String name;

  /// The user's rename. Sync never writes it.
  final String? displayName;

  /// Sync never writes it.
  final bool isHidden;

  /// The user's order, set by the Categories manager; null until the user
  /// reorders, and categories without one follow in [position] order.
  /// Sync never writes it.
  final int? sortOrder;
  const CategoryRow({
    required this.sourceId,
    required this.remoteKey,
    required this.position,
    this.seenRun,
    required this.id,
    required this.kind,
    required this.name,
    this.displayName,
    required this.isHidden,
    this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['remote_key'] = Variable<String>(remoteKey);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || seenRun != null) {
      map['seen_run'] = Variable<int>(seenRun);
    }
    map['id'] = Variable<int>(id);
    {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind),
      );
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['is_hidden'] = Variable<bool>(isHidden);
    if (!nullToAbsent || sortOrder != null) {
      map['sort_order'] = Variable<int>(sortOrder);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      sourceId: Value(sourceId),
      remoteKey: Value(remoteKey),
      position: Value(position),
      seenRun: seenRun == null && nullToAbsent
          ? const Value.absent()
          : Value(seenRun),
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      isHidden: Value(isHidden),
      sortOrder: sortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sortOrder),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      remoteKey: serializer.fromJson<String>(json['remoteKey']),
      position: serializer.fromJson<int>(json['position']),
      seenRun: serializer.fromJson<int?>(json['seenRun']),
      id: serializer.fromJson<int>(json['id']),
      kind: $CategoriesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      sortOrder: serializer.fromJson<int?>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'remoteKey': serializer.toJson<String>(remoteKey),
      'position': serializer.toJson<int>(position),
      'seenRun': serializer.toJson<int?>(seenRun),
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(
        $CategoriesTable.$converterkind.toJson(kind),
      ),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String?>(displayName),
      'isHidden': serializer.toJson<bool>(isHidden),
      'sortOrder': serializer.toJson<int?>(sortOrder),
    };
  }

  CategoryRow copyWith({
    String? sourceId,
    String? remoteKey,
    int? position,
    Value<int?> seenRun = const Value.absent(),
    int? id,
    CatalogueKind? kind,
    String? name,
    Value<String?> displayName = const Value.absent(),
    bool? isHidden,
    Value<int?> sortOrder = const Value.absent(),
  }) => CategoryRow(
    sourceId: sourceId ?? this.sourceId,
    remoteKey: remoteKey ?? this.remoteKey,
    position: position ?? this.position,
    seenRun: seenRun.present ? seenRun.value : this.seenRun,
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    displayName: displayName.present ? displayName.value : this.displayName,
    isHidden: isHidden ?? this.isHidden,
    sortOrder: sortOrder.present ? sortOrder.value : this.sortOrder,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      position: data.position.present ? data.position.value : this.position,
      seenRun: data.seenRun.present ? data.seenRun.value : this.seenRun,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('position: $position, ')
          ..write('seenRun: $seenRun, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('isHidden: $isHidden, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    remoteKey,
    position,
    seenRun,
    id,
    kind,
    name,
    displayName,
    isHidden,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.sourceId == this.sourceId &&
          other.remoteKey == this.remoteKey &&
          other.position == this.position &&
          other.seenRun == this.seenRun &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.isHidden == this.isHidden &&
          other.sortOrder == this.sortOrder);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> sourceId;
  final Value<String> remoteKey;
  final Value<int> position;
  final Value<int?> seenRun;
  final Value<int> id;
  final Value<CatalogueKind> kind;
  final Value<String> name;
  final Value<String?> displayName;
  final Value<bool> isHidden;
  final Value<int?> sortOrder;
  const CategoriesCompanion({
    this.sourceId = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.position = const Value.absent(),
    this.seenRun = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String sourceId,
    required String remoteKey,
    this.position = const Value.absent(),
    this.seenRun = const Value.absent(),
    this.id = const Value.absent(),
    required CatalogueKind kind,
    required String name,
    this.displayName = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteKey = Value(remoteKey),
       kind = Value(kind),
       name = Value(name);
  static Insertable<CategoryRow> custom({
    Expression<String>? sourceId,
    Expression<String>? remoteKey,
    Expression<int>? position,
    Expression<int>? seenRun,
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<bool>? isHidden,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (position != null) 'position': position,
      if (seenRun != null) 'seen_run': seenRun,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (isHidden != null) 'is_hidden': isHidden,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? remoteKey,
    Value<int>? position,
    Value<int?>? seenRun,
    Value<int>? id,
    Value<CatalogueKind>? kind,
    Value<String>? name,
    Value<String?>? displayName,
    Value<bool>? isHidden,
    Value<int?>? sortOrder,
  }) {
    return CategoriesCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteKey: remoteKey ?? this.remoteKey,
      position: position ?? this.position,
      seenRun: seenRun ?? this.seenRun,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      isHidden: isHidden ?? this.isHidden,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (seenRun.present) {
      map['seen_run'] = Variable<int>(seenRun.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('position: $position, ')
          ..write('seenRun: $seenRun, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('isHidden: $isHidden, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels
    with TableInfo<$ChannelsTable, ChannelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seenRunMeta = const VerificationMeta(
    'seenRun',
  );
  @override
  late final GeneratedColumn<int> seenRun = GeneratedColumn<int>(
    'seen_run',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cleanNameMeta = const VerificationMeta(
    'cleanName',
  );
  @override
  late final GeneratedColumn<String> cleanName = GeneratedColumn<String>(
    'clean_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoUrlMeta = const VerificationMeta(
    'logoUrl',
  );
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
    'logo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epgKeyMeta = const VerificationMeta('epgKey');
  @override
  late final GeneratedColumn<String> epgKey = GeneratedColumn<String>(
    'epg_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archiveDaysMeta = const VerificationMeta(
    'archiveDays',
  );
  @override
  late final GeneratedColumn<int> archiveDays = GeneratedColumn<int>(
    'archive_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extrasJsonMeta = const VerificationMeta(
    'extrasJson',
  );
  @override
  late final GeneratedColumn<String> extrasJson = GeneratedColumn<String>(
    'extras_json',
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
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteKey,
    position,
    seenRun,
    id,
    categoryId,
    number,
    name,
    displayName,
    cleanName,
    quality,
    logoUrl,
    epgKey,
    archiveDays,
    streamUrl,
    extrasJson,
    isHidden,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChannelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('seen_run')) {
      context.handle(
        _seenRunMeta,
        seenRun.isAcceptableOrUnknown(data['seen_run']!, _seenRunMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('clean_name')) {
      context.handle(
        _cleanNameMeta,
        cleanName.isAcceptableOrUnknown(data['clean_name']!, _cleanNameMeta),
      );
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('logo_url')) {
      context.handle(
        _logoUrlMeta,
        logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta),
      );
    }
    if (data.containsKey('epg_key')) {
      context.handle(
        _epgKeyMeta,
        epgKey.isAcceptableOrUnknown(data['epg_key']!, _epgKeyMeta),
      );
    }
    if (data.containsKey('archive_days')) {
      context.handle(
        _archiveDaysMeta,
        archiveDays.isAcceptableOrUnknown(
          data['archive_days']!,
          _archiveDaysMeta,
        ),
      );
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    }
    if (data.containsKey('extras_json')) {
      context.handle(
        _extrasJsonMeta,
        extrasJson.isAcceptableOrUnknown(data['extras_json']!, _extrasJsonMeta),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, remoteKey},
  ];
  @override
  ChannelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      seenRun: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_run'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      cleanName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clean_name'],
      ),
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality'],
      ),
      logoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_url'],
      ),
      epgKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_key'],
      ),
      archiveDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archive_days'],
      )!,
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      ),
      extrasJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extras_json'],
      ),
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class ChannelRow extends DataClass implements Insertable<ChannelRow> {
  final String sourceId;
  final String remoteKey;

  /// The provider's own order, rewritten by every sync.
  final int position;

  /// The sync run that last saw this row. See [SyncRuns].
  final int? seenRun;
  final int id;

  /// Null when the provider gave none or pointed at a category it does
  /// not have; the UI files those under "Uncategorized".
  final int? categoryId;
  final int? number;
  final String name;

  /// The user's rename. Sync never writes it.
  final String? displayName;

  /// [name] as the screens show it (`cleanChannelName`): sync writes it
  /// with [name], so it is the provider's, not the user's. Null only
  /// between the upgrade to v7 and the fill that follows it
  /// (`ChannelNameFill`); a screen then shows [name].
  final String? cleanName;

  /// The badge [name]'s tags gave (`ChannelQuality.name`), written with
  /// [cleanName]. Null for none.
  final String? quality;
  final String? logoUrl;

  /// Xtream `epg_channel_id` or M3U `tvg-id`.
  final String? epgKey;
  final int archiveDays;

  /// M3U only: the stream URL with the source's credentials replaced by
  /// placeholders. Xtream URLs are built from the source instead.
  final String? streamUrl;

  /// M3U only: per-item options (`#EXTVLCOPT` user agent and referrer,
  /// catch-up attributes), as JSON.
  final String? extrasJson;

  /// Sync never writes it.
  final bool isHidden;
  final DateTime? addedAt;
  const ChannelRow({
    required this.sourceId,
    required this.remoteKey,
    required this.position,
    this.seenRun,
    required this.id,
    this.categoryId,
    this.number,
    required this.name,
    this.displayName,
    this.cleanName,
    this.quality,
    this.logoUrl,
    this.epgKey,
    required this.archiveDays,
    this.streamUrl,
    this.extrasJson,
    required this.isHidden,
    this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['remote_key'] = Variable<String>(remoteKey);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || seenRun != null) {
      map['seen_run'] = Variable<int>(seenRun);
    }
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<int>(number);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || cleanName != null) {
      map['clean_name'] = Variable<String>(cleanName);
    }
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<String>(quality);
    }
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    if (!nullToAbsent || epgKey != null) {
      map['epg_key'] = Variable<String>(epgKey);
    }
    map['archive_days'] = Variable<int>(archiveDays);
    if (!nullToAbsent || streamUrl != null) {
      map['stream_url'] = Variable<String>(streamUrl);
    }
    if (!nullToAbsent || extrasJson != null) {
      map['extras_json'] = Variable<String>(extrasJson);
    }
    map['is_hidden'] = Variable<bool>(isHidden);
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      sourceId: Value(sourceId),
      remoteKey: Value(remoteKey),
      position: Value(position),
      seenRun: seenRun == null && nullToAbsent
          ? const Value.absent()
          : Value(seenRun),
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      number: number == null && nullToAbsent
          ? const Value.absent()
          : Value(number),
      name: Value(name),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      cleanName: cleanName == null && nullToAbsent
          ? const Value.absent()
          : Value(cleanName),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      epgKey: epgKey == null && nullToAbsent
          ? const Value.absent()
          : Value(epgKey),
      archiveDays: Value(archiveDays),
      streamUrl: streamUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(streamUrl),
      extrasJson: extrasJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extrasJson),
      isHidden: Value(isHidden),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
    );
  }

  factory ChannelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      remoteKey: serializer.fromJson<String>(json['remoteKey']),
      position: serializer.fromJson<int>(json['position']),
      seenRun: serializer.fromJson<int?>(json['seenRun']),
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      number: serializer.fromJson<int?>(json['number']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      cleanName: serializer.fromJson<String?>(json['cleanName']),
      quality: serializer.fromJson<String?>(json['quality']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      epgKey: serializer.fromJson<String?>(json['epgKey']),
      archiveDays: serializer.fromJson<int>(json['archiveDays']),
      streamUrl: serializer.fromJson<String?>(json['streamUrl']),
      extrasJson: serializer.fromJson<String?>(json['extrasJson']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'remoteKey': serializer.toJson<String>(remoteKey),
      'position': serializer.toJson<int>(position),
      'seenRun': serializer.toJson<int?>(seenRun),
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int?>(categoryId),
      'number': serializer.toJson<int?>(number),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String?>(displayName),
      'cleanName': serializer.toJson<String?>(cleanName),
      'quality': serializer.toJson<String?>(quality),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'epgKey': serializer.toJson<String?>(epgKey),
      'archiveDays': serializer.toJson<int>(archiveDays),
      'streamUrl': serializer.toJson<String?>(streamUrl),
      'extrasJson': serializer.toJson<String?>(extrasJson),
      'isHidden': serializer.toJson<bool>(isHidden),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
    };
  }

  ChannelRow copyWith({
    String? sourceId,
    String? remoteKey,
    int? position,
    Value<int?> seenRun = const Value.absent(),
    int? id,
    Value<int?> categoryId = const Value.absent(),
    Value<int?> number = const Value.absent(),
    String? name,
    Value<String?> displayName = const Value.absent(),
    Value<String?> cleanName = const Value.absent(),
    Value<String?> quality = const Value.absent(),
    Value<String?> logoUrl = const Value.absent(),
    Value<String?> epgKey = const Value.absent(),
    int? archiveDays,
    Value<String?> streamUrl = const Value.absent(),
    Value<String?> extrasJson = const Value.absent(),
    bool? isHidden,
    Value<DateTime?> addedAt = const Value.absent(),
  }) => ChannelRow(
    sourceId: sourceId ?? this.sourceId,
    remoteKey: remoteKey ?? this.remoteKey,
    position: position ?? this.position,
    seenRun: seenRun.present ? seenRun.value : this.seenRun,
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    number: number.present ? number.value : this.number,
    name: name ?? this.name,
    displayName: displayName.present ? displayName.value : this.displayName,
    cleanName: cleanName.present ? cleanName.value : this.cleanName,
    quality: quality.present ? quality.value : this.quality,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    epgKey: epgKey.present ? epgKey.value : this.epgKey,
    archiveDays: archiveDays ?? this.archiveDays,
    streamUrl: streamUrl.present ? streamUrl.value : this.streamUrl,
    extrasJson: extrasJson.present ? extrasJson.value : this.extrasJson,
    isHidden: isHidden ?? this.isHidden,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
  );
  ChannelRow copyWithCompanion(ChannelsCompanion data) {
    return ChannelRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      position: data.position.present ? data.position.value : this.position,
      seenRun: data.seenRun.present ? data.seenRun.value : this.seenRun,
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      number: data.number.present ? data.number.value : this.number,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      cleanName: data.cleanName.present ? data.cleanName.value : this.cleanName,
      quality: data.quality.present ? data.quality.value : this.quality,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      epgKey: data.epgKey.present ? data.epgKey.value : this.epgKey,
      archiveDays: data.archiveDays.present
          ? data.archiveDays.value
          : this.archiveDays,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      extrasJson: data.extrasJson.present
          ? data.extrasJson.value
          : this.extrasJson,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelRow(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('position: $position, ')
          ..write('seenRun: $seenRun, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('number: $number, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('cleanName: $cleanName, ')
          ..write('quality: $quality, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('epgKey: $epgKey, ')
          ..write('archiveDays: $archiveDays, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('isHidden: $isHidden, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    remoteKey,
    position,
    seenRun,
    id,
    categoryId,
    number,
    name,
    displayName,
    cleanName,
    quality,
    logoUrl,
    epgKey,
    archiveDays,
    streamUrl,
    extrasJson,
    isHidden,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelRow &&
          other.sourceId == this.sourceId &&
          other.remoteKey == this.remoteKey &&
          other.position == this.position &&
          other.seenRun == this.seenRun &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.number == this.number &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.cleanName == this.cleanName &&
          other.quality == this.quality &&
          other.logoUrl == this.logoUrl &&
          other.epgKey == this.epgKey &&
          other.archiveDays == this.archiveDays &&
          other.streamUrl == this.streamUrl &&
          other.extrasJson == this.extrasJson &&
          other.isHidden == this.isHidden &&
          other.addedAt == this.addedAt);
}

class ChannelsCompanion extends UpdateCompanion<ChannelRow> {
  final Value<String> sourceId;
  final Value<String> remoteKey;
  final Value<int> position;
  final Value<int?> seenRun;
  final Value<int> id;
  final Value<int?> categoryId;
  final Value<int?> number;
  final Value<String> name;
  final Value<String?> displayName;
  final Value<String?> cleanName;
  final Value<String?> quality;
  final Value<String?> logoUrl;
  final Value<String?> epgKey;
  final Value<int> archiveDays;
  final Value<String?> streamUrl;
  final Value<String?> extrasJson;
  final Value<bool> isHidden;
  final Value<DateTime?> addedAt;
  const ChannelsCompanion({
    this.sourceId = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.position = const Value.absent(),
    this.seenRun = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.number = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.cleanName = const Value.absent(),
    this.quality = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.epgKey = const Value.absent(),
    this.archiveDays = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  ChannelsCompanion.insert({
    required String sourceId,
    required String remoteKey,
    this.position = const Value.absent(),
    this.seenRun = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.number = const Value.absent(),
    required String name,
    this.displayName = const Value.absent(),
    this.cleanName = const Value.absent(),
    this.quality = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.epgKey = const Value.absent(),
    this.archiveDays = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.addedAt = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteKey = Value(remoteKey),
       name = Value(name);
  static Insertable<ChannelRow> custom({
    Expression<String>? sourceId,
    Expression<String>? remoteKey,
    Expression<int>? position,
    Expression<int>? seenRun,
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<int>? number,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? cleanName,
    Expression<String>? quality,
    Expression<String>? logoUrl,
    Expression<String>? epgKey,
    Expression<int>? archiveDays,
    Expression<String>? streamUrl,
    Expression<String>? extrasJson,
    Expression<bool>? isHidden,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (position != null) 'position': position,
      if (seenRun != null) 'seen_run': seenRun,
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (number != null) 'number': number,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (cleanName != null) 'clean_name': cleanName,
      if (quality != null) 'quality': quality,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (epgKey != null) 'epg_key': epgKey,
      if (archiveDays != null) 'archive_days': archiveDays,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (extrasJson != null) 'extras_json': extrasJson,
      if (isHidden != null) 'is_hidden': isHidden,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  ChannelsCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? remoteKey,
    Value<int>? position,
    Value<int?>? seenRun,
    Value<int>? id,
    Value<int?>? categoryId,
    Value<int?>? number,
    Value<String>? name,
    Value<String?>? displayName,
    Value<String?>? cleanName,
    Value<String?>? quality,
    Value<String?>? logoUrl,
    Value<String?>? epgKey,
    Value<int>? archiveDays,
    Value<String?>? streamUrl,
    Value<String?>? extrasJson,
    Value<bool>? isHidden,
    Value<DateTime?>? addedAt,
  }) {
    return ChannelsCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteKey: remoteKey ?? this.remoteKey,
      position: position ?? this.position,
      seenRun: seenRun ?? this.seenRun,
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      number: number ?? this.number,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      cleanName: cleanName ?? this.cleanName,
      quality: quality ?? this.quality,
      logoUrl: logoUrl ?? this.logoUrl,
      epgKey: epgKey ?? this.epgKey,
      archiveDays: archiveDays ?? this.archiveDays,
      streamUrl: streamUrl ?? this.streamUrl,
      extrasJson: extrasJson ?? this.extrasJson,
      isHidden: isHidden ?? this.isHidden,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (seenRun.present) {
      map['seen_run'] = Variable<int>(seenRun.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (cleanName.present) {
      map['clean_name'] = Variable<String>(cleanName.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (epgKey.present) {
      map['epg_key'] = Variable<String>(epgKey.value);
    }
    if (archiveDays.present) {
      map['archive_days'] = Variable<int>(archiveDays.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (extrasJson.present) {
      map['extras_json'] = Variable<String>(extrasJson.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('position: $position, ')
          ..write('seenRun: $seenRun, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('number: $number, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('cleanName: $cleanName, ')
          ..write('quality: $quality, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('epgKey: $epgKey, ')
          ..write('archiveDays: $archiveDays, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('isHidden: $isHidden, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class ChannelsFts extends Table
    with
        TableInfo<ChannelsFts, ChannelsFt>,
        VirtualTableInfo<ChannelsFts, ChannelsFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ChannelsFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cleanNameMeta = const VerificationMeta(
    'cleanName',
  );
  late final GeneratedColumn<String> cleanName = GeneratedColumn<String>(
    'clean_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [cleanName, displayName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChannelsFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('clean_name')) {
      context.handle(
        _cleanNameMeta,
        cleanName.isAcceptableOrUnknown(data['clean_name']!, _cleanNameMeta),
      );
    } else if (isInserting) {
      context.missing(_cleanNameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  ChannelsFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelsFt(
      cleanName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clean_name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
    );
  }

  @override
  ChannelsFts createAlias(String alias) {
    return ChannelsFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(clean_name, display_name, content=\'channels\', content_rowid=\'id\', tokenize=\'unicode61 remove_diacritics 2\', prefix=\'2 3\')';
}

class ChannelsFt extends DataClass implements Insertable<ChannelsFt> {
  final String cleanName;
  final String displayName;
  const ChannelsFt({required this.cleanName, required this.displayName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['clean_name'] = Variable<String>(cleanName);
    map['display_name'] = Variable<String>(displayName);
    return map;
  }

  ChannelsFtsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsFtsCompanion(
      cleanName: Value(cleanName),
      displayName: Value(displayName),
    );
  }

  factory ChannelsFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelsFt(
      cleanName: serializer.fromJson<String>(json['clean_name']),
      displayName: serializer.fromJson<String>(json['display_name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clean_name': serializer.toJson<String>(cleanName),
      'display_name': serializer.toJson<String>(displayName),
    };
  }

  ChannelsFt copyWith({String? cleanName, String? displayName}) => ChannelsFt(
    cleanName: cleanName ?? this.cleanName,
    displayName: displayName ?? this.displayName,
  );
  ChannelsFt copyWithCompanion(ChannelsFtsCompanion data) {
    return ChannelsFt(
      cleanName: data.cleanName.present ? data.cleanName.value : this.cleanName,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsFt(')
          ..write('cleanName: $cleanName, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cleanName, displayName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelsFt &&
          other.cleanName == this.cleanName &&
          other.displayName == this.displayName);
}

class ChannelsFtsCompanion extends UpdateCompanion<ChannelsFt> {
  final Value<String> cleanName;
  final Value<String> displayName;
  final Value<int> rowid;
  const ChannelsFtsCompanion({
    this.cleanName = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsFtsCompanion.insert({
    required String cleanName,
    required String displayName,
    this.rowid = const Value.absent(),
  }) : cleanName = Value(cleanName),
       displayName = Value(displayName);
  static Insertable<ChannelsFt> custom({
    Expression<String>? cleanName,
    Expression<String>? displayName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cleanName != null) 'clean_name': cleanName,
      if (displayName != null) 'display_name': displayName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsFtsCompanion copyWith({
    Value<String>? cleanName,
    Value<String>? displayName,
    Value<int>? rowid,
  }) {
    return ChannelsFtsCompanion(
      cleanName: cleanName ?? this.cleanName,
      displayName: displayName ?? this.displayName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cleanName.present) {
      map['clean_name'] = Variable<String>(cleanName.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsFtsCompanion(')
          ..write('cleanName: $cleanName, ')
          ..write('displayName: $displayName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoviesTable extends Movies with TableInfo<$MoviesTable, MovieRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoviesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seenRunMeta = const VerificationMeta(
    'seenRun',
  );
  @override
  late final GeneratedColumn<int> seenRun = GeneratedColumn<int>(
    'seen_run',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE SET NULL',
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
  static const VerificationMeta _posterUrlMeta = const VerificationMeta(
    'posterUrl',
  );
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
    'poster_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  @override
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extrasJsonMeta = const VerificationMeta(
    'extrasJson',
  );
  @override
  late final GeneratedColumn<String> extrasJson = GeneratedColumn<String>(
    'extras_json',
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
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteKey,
    position,
    seenRun,
    id,
    categoryId,
    name,
    posterUrl,
    rating,
    year,
    ext,
    streamUrl,
    extrasJson,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movies';
  @override
  VerificationContext validateIntegrity(
    Insertable<MovieRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('seen_run')) {
      context.handle(
        _seenRunMeta,
        seenRun.isAcceptableOrUnknown(data['seen_run']!, _seenRunMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('poster_url')) {
      context.handle(
        _posterUrlMeta,
        posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    }
    if (data.containsKey('extras_json')) {
      context.handle(
        _extrasJsonMeta,
        extrasJson.isAcceptableOrUnknown(data['extras_json']!, _extrasJsonMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, remoteKey},
  ];
  @override
  MovieRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MovieRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      seenRun: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_run'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      posterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_url'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      ),
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      ),
      extrasJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extras_json'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
    );
  }

  @override
  $MoviesTable createAlias(String alias) {
    return $MoviesTable(attachedDatabase, alias);
  }
}

class MovieRow extends DataClass implements Insertable<MovieRow> {
  final String sourceId;
  final String remoteKey;

  /// The provider's own order, rewritten by every sync.
  final int position;

  /// The sync run that last saw this row. See [SyncRuns].
  final int? seenRun;
  final int id;
  final int? categoryId;
  final String name;
  final String? posterUrl;

  /// Out of 10, as Xtream sends it.
  final double? rating;
  final int? year;

  /// The container extension (`mkv`, `mp4`), which the stream URL needs.
  final String? ext;

  /// See [Channels.streamUrl].
  final String? streamUrl;
  final String? extrasJson;
  final DateTime? addedAt;
  const MovieRow({
    required this.sourceId,
    required this.remoteKey,
    required this.position,
    this.seenRun,
    required this.id,
    this.categoryId,
    required this.name,
    this.posterUrl,
    this.rating,
    this.year,
    this.ext,
    this.streamUrl,
    this.extrasJson,
    this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['remote_key'] = Variable<String>(remoteKey);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || seenRun != null) {
      map['seen_run'] = Variable<int>(seenRun);
    }
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || ext != null) {
      map['ext'] = Variable<String>(ext);
    }
    if (!nullToAbsent || streamUrl != null) {
      map['stream_url'] = Variable<String>(streamUrl);
    }
    if (!nullToAbsent || extrasJson != null) {
      map['extras_json'] = Variable<String>(extrasJson);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    return map;
  }

  MoviesCompanion toCompanion(bool nullToAbsent) {
    return MoviesCompanion(
      sourceId: Value(sourceId),
      remoteKey: Value(remoteKey),
      position: Value(position),
      seenRun: seenRun == null && nullToAbsent
          ? const Value.absent()
          : Value(seenRun),
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      name: Value(name),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      ext: ext == null && nullToAbsent ? const Value.absent() : Value(ext),
      streamUrl: streamUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(streamUrl),
      extrasJson: extrasJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extrasJson),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
    );
  }

  factory MovieRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MovieRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      remoteKey: serializer.fromJson<String>(json['remoteKey']),
      position: serializer.fromJson<int>(json['position']),
      seenRun: serializer.fromJson<int?>(json['seenRun']),
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      rating: serializer.fromJson<double?>(json['rating']),
      year: serializer.fromJson<int?>(json['year']),
      ext: serializer.fromJson<String?>(json['ext']),
      streamUrl: serializer.fromJson<String?>(json['streamUrl']),
      extrasJson: serializer.fromJson<String?>(json['extrasJson']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'remoteKey': serializer.toJson<String>(remoteKey),
      'position': serializer.toJson<int>(position),
      'seenRun': serializer.toJson<int?>(seenRun),
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int?>(categoryId),
      'name': serializer.toJson<String>(name),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'rating': serializer.toJson<double?>(rating),
      'year': serializer.toJson<int?>(year),
      'ext': serializer.toJson<String?>(ext),
      'streamUrl': serializer.toJson<String?>(streamUrl),
      'extrasJson': serializer.toJson<String?>(extrasJson),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
    };
  }

  MovieRow copyWith({
    String? sourceId,
    String? remoteKey,
    int? position,
    Value<int?> seenRun = const Value.absent(),
    int? id,
    Value<int?> categoryId = const Value.absent(),
    String? name,
    Value<String?> posterUrl = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> ext = const Value.absent(),
    Value<String?> streamUrl = const Value.absent(),
    Value<String?> extrasJson = const Value.absent(),
    Value<DateTime?> addedAt = const Value.absent(),
  }) => MovieRow(
    sourceId: sourceId ?? this.sourceId,
    remoteKey: remoteKey ?? this.remoteKey,
    position: position ?? this.position,
    seenRun: seenRun.present ? seenRun.value : this.seenRun,
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    name: name ?? this.name,
    posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
    rating: rating.present ? rating.value : this.rating,
    year: year.present ? year.value : this.year,
    ext: ext.present ? ext.value : this.ext,
    streamUrl: streamUrl.present ? streamUrl.value : this.streamUrl,
    extrasJson: extrasJson.present ? extrasJson.value : this.extrasJson,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
  );
  MovieRow copyWithCompanion(MoviesCompanion data) {
    return MovieRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      position: data.position.present ? data.position.value : this.position,
      seenRun: data.seenRun.present ? data.seenRun.value : this.seenRun,
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      rating: data.rating.present ? data.rating.value : this.rating,
      year: data.year.present ? data.year.value : this.year,
      ext: data.ext.present ? data.ext.value : this.ext,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      extrasJson: data.extrasJson.present
          ? data.extrasJson.value
          : this.extrasJson,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MovieRow(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('position: $position, ')
          ..write('seenRun: $seenRun, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('rating: $rating, ')
          ..write('year: $year, ')
          ..write('ext: $ext, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    remoteKey,
    position,
    seenRun,
    id,
    categoryId,
    name,
    posterUrl,
    rating,
    year,
    ext,
    streamUrl,
    extrasJson,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovieRow &&
          other.sourceId == this.sourceId &&
          other.remoteKey == this.remoteKey &&
          other.position == this.position &&
          other.seenRun == this.seenRun &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.posterUrl == this.posterUrl &&
          other.rating == this.rating &&
          other.year == this.year &&
          other.ext == this.ext &&
          other.streamUrl == this.streamUrl &&
          other.extrasJson == this.extrasJson &&
          other.addedAt == this.addedAt);
}

class MoviesCompanion extends UpdateCompanion<MovieRow> {
  final Value<String> sourceId;
  final Value<String> remoteKey;
  final Value<int> position;
  final Value<int?> seenRun;
  final Value<int> id;
  final Value<int?> categoryId;
  final Value<String> name;
  final Value<String?> posterUrl;
  final Value<double?> rating;
  final Value<int?> year;
  final Value<String?> ext;
  final Value<String?> streamUrl;
  final Value<String?> extrasJson;
  final Value<DateTime?> addedAt;
  const MoviesCompanion({
    this.sourceId = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.position = const Value.absent(),
    this.seenRun = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.year = const Value.absent(),
    this.ext = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  MoviesCompanion.insert({
    required String sourceId,
    required String remoteKey,
    this.position = const Value.absent(),
    this.seenRun = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    required String name,
    this.posterUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.year = const Value.absent(),
    this.ext = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.addedAt = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteKey = Value(remoteKey),
       name = Value(name);
  static Insertable<MovieRow> custom({
    Expression<String>? sourceId,
    Expression<String>? remoteKey,
    Expression<int>? position,
    Expression<int>? seenRun,
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<String>? name,
    Expression<String>? posterUrl,
    Expression<double>? rating,
    Expression<int>? year,
    Expression<String>? ext,
    Expression<String>? streamUrl,
    Expression<String>? extrasJson,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (position != null) 'position': position,
      if (seenRun != null) 'seen_run': seenRun,
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (rating != null) 'rating': rating,
      if (year != null) 'year': year,
      if (ext != null) 'ext': ext,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (extrasJson != null) 'extras_json': extrasJson,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  MoviesCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? remoteKey,
    Value<int>? position,
    Value<int?>? seenRun,
    Value<int>? id,
    Value<int?>? categoryId,
    Value<String>? name,
    Value<String?>? posterUrl,
    Value<double?>? rating,
    Value<int?>? year,
    Value<String?>? ext,
    Value<String?>? streamUrl,
    Value<String?>? extrasJson,
    Value<DateTime?>? addedAt,
  }) {
    return MoviesCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteKey: remoteKey ?? this.remoteKey,
      position: position ?? this.position,
      seenRun: seenRun ?? this.seenRun,
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      posterUrl: posterUrl ?? this.posterUrl,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      ext: ext ?? this.ext,
      streamUrl: streamUrl ?? this.streamUrl,
      extrasJson: extrasJson ?? this.extrasJson,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (seenRun.present) {
      map['seen_run'] = Variable<int>(seenRun.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (extrasJson.present) {
      map['extras_json'] = Variable<String>(extrasJson.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoviesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('position: $position, ')
          ..write('seenRun: $seenRun, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('rating: $rating, ')
          ..write('year: $year, ')
          ..write('ext: $ext, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class MoviesFts extends Table
    with TableInfo<MoviesFts, MoviesFt>, VirtualTableInfo<MoviesFts, MoviesFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MoviesFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movies_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<MoviesFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  MoviesFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoviesFt(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  MoviesFts createAlias(String alias) {
    return MoviesFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(name, content=\'movies\', content_rowid=\'id\', tokenize=\'unicode61 remove_diacritics 2\', prefix=\'2 3\')';
}

class MoviesFt extends DataClass implements Insertable<MoviesFt> {
  final String name;
  const MoviesFt({required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    return map;
  }

  MoviesFtsCompanion toCompanion(bool nullToAbsent) {
    return MoviesFtsCompanion(name: Value(name));
  }

  factory MoviesFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoviesFt(name: serializer.fromJson<String>(json['name']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'name': serializer.toJson<String>(name)};
  }

  MoviesFt copyWith({String? name}) => MoviesFt(name: name ?? this.name);
  MoviesFt copyWithCompanion(MoviesFtsCompanion data) {
    return MoviesFt(name: data.name.present ? data.name.value : this.name);
  }

  @override
  String toString() {
    return (StringBuffer('MoviesFt(')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => name.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MoviesFt && other.name == this.name);
}

class MoviesFtsCompanion extends UpdateCompanion<MoviesFt> {
  final Value<String> name;
  final Value<int> rowid;
  const MoviesFtsCompanion({
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoviesFtsCompanion.insert({
    required String name,
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<MoviesFt> custom({
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoviesFtsCompanion copyWith({Value<String>? name, Value<int>? rowid}) {
    return MoviesFtsCompanion(
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoviesFtsCompanion(')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesTable extends Series with TableInfo<$SeriesTable, SeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seenRunMeta = const VerificationMeta(
    'seenRun',
  );
  @override
  late final GeneratedColumn<int> seenRun = GeneratedColumn<int>(
    'seen_run',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE SET NULL',
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
  static const VerificationMeta _posterUrlMeta = const VerificationMeta(
    'posterUrl',
  );
  @override
  late final GeneratedColumn<String> posterUrl = GeneratedColumn<String>(
    'poster_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _castNamesMeta = const VerificationMeta(
    'castNames',
  );
  @override
  late final GeneratedColumn<String> castNames = GeneratedColumn<String>(
    'cast_names',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directorMeta = const VerificationMeta(
    'director',
  );
  @override
  late final GeneratedColumn<String> director = GeneratedColumn<String>(
    'director',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropUrlMeta = const VerificationMeta(
    'backdropUrl',
  );
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
    'backdrop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _episodesFetchedAtMeta = const VerificationMeta(
    'episodesFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> episodesFetchedAt =
      GeneratedColumn<DateTime>(
        'episodes_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    remoteKey,
    position,
    seenRun,
    id,
    categoryId,
    name,
    posterUrl,
    rating,
    year,
    plot,
    genre,
    castNames,
    director,
    backdropUrl,
    updatedAt,
    episodesFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('seen_run')) {
      context.handle(
        _seenRunMeta,
        seenRun.isAcceptableOrUnknown(data['seen_run']!, _seenRunMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('poster_url')) {
      context.handle(
        _posterUrlMeta,
        posterUrl.isAcceptableOrUnknown(data['poster_url']!, _posterUrlMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('cast_names')) {
      context.handle(
        _castNamesMeta,
        castNames.isAcceptableOrUnknown(data['cast_names']!, _castNamesMeta),
      );
    }
    if (data.containsKey('director')) {
      context.handle(
        _directorMeta,
        director.isAcceptableOrUnknown(data['director']!, _directorMeta),
      );
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
        _backdropUrlMeta,
        backdropUrl.isAcceptableOrUnknown(
          data['backdrop_url']!,
          _backdropUrlMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('episodes_fetched_at')) {
      context.handle(
        _episodesFetchedAtMeta,
        episodesFetchedAt.isAcceptableOrUnknown(
          data['episodes_fetched_at']!,
          _episodesFetchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, remoteKey},
  ];
  @override
  SeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      seenRun: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_run'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      posterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_url'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      castNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast_names'],
      ),
      director: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}director'],
      ),
      backdropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_url'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      episodesFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}episodes_fetched_at'],
      ),
    );
  }

  @override
  $SeriesTable createAlias(String alias) {
    return $SeriesTable(attachedDatabase, alias);
  }
}

class SeriesRow extends DataClass implements Insertable<SeriesRow> {
  final String sourceId;
  final String remoteKey;

  /// The provider's own order, rewritten by every sync.
  final int position;

  /// The sync run that last saw this row. See [SyncRuns].
  final int? seenRun;
  final int id;
  final int? categoryId;
  final String name;
  final String? posterUrl;
  final double? rating;
  final int? year;
  final String? plot;

  /// v6: sent by the list and by `get_series_info`. Provider-owned, but a
  /// sync whose list lacks one keeps the value the details fetch stored.
  final String? genre;
  final String? castNames;
  final String? director;
  final String? backdropUrl;

  /// The provider's `last_modified`: when it changes, the cached episodes
  /// are stale.
  final DateTime? updatedAt;

  /// When the episodes were last fetched (`get_series_info` is lazy).
  final DateTime? episodesFetchedAt;
  const SeriesRow({
    required this.sourceId,
    required this.remoteKey,
    required this.position,
    this.seenRun,
    required this.id,
    this.categoryId,
    required this.name,
    this.posterUrl,
    this.rating,
    this.year,
    this.plot,
    this.genre,
    this.castNames,
    this.director,
    this.backdropUrl,
    this.updatedAt,
    this.episodesFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['remote_key'] = Variable<String>(remoteKey);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || seenRun != null) {
      map['seen_run'] = Variable<int>(seenRun);
    }
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || posterUrl != null) {
      map['poster_url'] = Variable<String>(posterUrl);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || castNames != null) {
      map['cast_names'] = Variable<String>(castNames);
    }
    if (!nullToAbsent || director != null) {
      map['director'] = Variable<String>(director);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || episodesFetchedAt != null) {
      map['episodes_fetched_at'] = Variable<DateTime>(episodesFetchedAt);
    }
    return map;
  }

  SeriesCompanion toCompanion(bool nullToAbsent) {
    return SeriesCompanion(
      sourceId: Value(sourceId),
      remoteKey: Value(remoteKey),
      position: Value(position),
      seenRun: seenRun == null && nullToAbsent
          ? const Value.absent()
          : Value(seenRun),
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      name: Value(name),
      posterUrl: posterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(posterUrl),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      castNames: castNames == null && nullToAbsent
          ? const Value.absent()
          : Value(castNames),
      director: director == null && nullToAbsent
          ? const Value.absent()
          : Value(director),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      episodesFetchedAt: episodesFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(episodesFetchedAt),
    );
  }

  factory SeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      remoteKey: serializer.fromJson<String>(json['remoteKey']),
      position: serializer.fromJson<int>(json['position']),
      seenRun: serializer.fromJson<int?>(json['seenRun']),
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      posterUrl: serializer.fromJson<String?>(json['posterUrl']),
      rating: serializer.fromJson<double?>(json['rating']),
      year: serializer.fromJson<int?>(json['year']),
      plot: serializer.fromJson<String?>(json['plot']),
      genre: serializer.fromJson<String?>(json['genre']),
      castNames: serializer.fromJson<String?>(json['castNames']),
      director: serializer.fromJson<String?>(json['director']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      episodesFetchedAt: serializer.fromJson<DateTime?>(
        json['episodesFetchedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'remoteKey': serializer.toJson<String>(remoteKey),
      'position': serializer.toJson<int>(position),
      'seenRun': serializer.toJson<int?>(seenRun),
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int?>(categoryId),
      'name': serializer.toJson<String>(name),
      'posterUrl': serializer.toJson<String?>(posterUrl),
      'rating': serializer.toJson<double?>(rating),
      'year': serializer.toJson<int?>(year),
      'plot': serializer.toJson<String?>(plot),
      'genre': serializer.toJson<String?>(genre),
      'castNames': serializer.toJson<String?>(castNames),
      'director': serializer.toJson<String?>(director),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'episodesFetchedAt': serializer.toJson<DateTime?>(episodesFetchedAt),
    };
  }

  SeriesRow copyWith({
    String? sourceId,
    String? remoteKey,
    int? position,
    Value<int?> seenRun = const Value.absent(),
    int? id,
    Value<int?> categoryId = const Value.absent(),
    String? name,
    Value<String?> posterUrl = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> castNames = const Value.absent(),
    Value<String?> director = const Value.absent(),
    Value<String?> backdropUrl = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> episodesFetchedAt = const Value.absent(),
  }) => SeriesRow(
    sourceId: sourceId ?? this.sourceId,
    remoteKey: remoteKey ?? this.remoteKey,
    position: position ?? this.position,
    seenRun: seenRun.present ? seenRun.value : this.seenRun,
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    name: name ?? this.name,
    posterUrl: posterUrl.present ? posterUrl.value : this.posterUrl,
    rating: rating.present ? rating.value : this.rating,
    year: year.present ? year.value : this.year,
    plot: plot.present ? plot.value : this.plot,
    genre: genre.present ? genre.value : this.genre,
    castNames: castNames.present ? castNames.value : this.castNames,
    director: director.present ? director.value : this.director,
    backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    episodesFetchedAt: episodesFetchedAt.present
        ? episodesFetchedAt.value
        : this.episodesFetchedAt,
  );
  SeriesRow copyWithCompanion(SeriesCompanion data) {
    return SeriesRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      position: data.position.present ? data.position.value : this.position,
      seenRun: data.seenRun.present ? data.seenRun.value : this.seenRun,
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      posterUrl: data.posterUrl.present ? data.posterUrl.value : this.posterUrl,
      rating: data.rating.present ? data.rating.value : this.rating,
      year: data.year.present ? data.year.value : this.year,
      plot: data.plot.present ? data.plot.value : this.plot,
      genre: data.genre.present ? data.genre.value : this.genre,
      castNames: data.castNames.present ? data.castNames.value : this.castNames,
      director: data.director.present ? data.director.value : this.director,
      backdropUrl: data.backdropUrl.present
          ? data.backdropUrl.value
          : this.backdropUrl,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      episodesFetchedAt: data.episodesFetchedAt.present
          ? data.episodesFetchedAt.value
          : this.episodesFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesRow(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('position: $position, ')
          ..write('seenRun: $seenRun, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('rating: $rating, ')
          ..write('year: $year, ')
          ..write('plot: $plot, ')
          ..write('genre: $genre, ')
          ..write('castNames: $castNames, ')
          ..write('director: $director, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('episodesFetchedAt: $episodesFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    remoteKey,
    position,
    seenRun,
    id,
    categoryId,
    name,
    posterUrl,
    rating,
    year,
    plot,
    genre,
    castNames,
    director,
    backdropUrl,
    updatedAt,
    episodesFetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesRow &&
          other.sourceId == this.sourceId &&
          other.remoteKey == this.remoteKey &&
          other.position == this.position &&
          other.seenRun == this.seenRun &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.posterUrl == this.posterUrl &&
          other.rating == this.rating &&
          other.year == this.year &&
          other.plot == this.plot &&
          other.genre == this.genre &&
          other.castNames == this.castNames &&
          other.director == this.director &&
          other.backdropUrl == this.backdropUrl &&
          other.updatedAt == this.updatedAt &&
          other.episodesFetchedAt == this.episodesFetchedAt);
}

class SeriesCompanion extends UpdateCompanion<SeriesRow> {
  final Value<String> sourceId;
  final Value<String> remoteKey;
  final Value<int> position;
  final Value<int?> seenRun;
  final Value<int> id;
  final Value<int?> categoryId;
  final Value<String> name;
  final Value<String?> posterUrl;
  final Value<double?> rating;
  final Value<int?> year;
  final Value<String?> plot;
  final Value<String?> genre;
  final Value<String?> castNames;
  final Value<String?> director;
  final Value<String?> backdropUrl;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> episodesFetchedAt;
  const SeriesCompanion({
    this.sourceId = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.position = const Value.absent(),
    this.seenRun = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.posterUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.year = const Value.absent(),
    this.plot = const Value.absent(),
    this.genre = const Value.absent(),
    this.castNames = const Value.absent(),
    this.director = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.episodesFetchedAt = const Value.absent(),
  });
  SeriesCompanion.insert({
    required String sourceId,
    required String remoteKey,
    this.position = const Value.absent(),
    this.seenRun = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    required String name,
    this.posterUrl = const Value.absent(),
    this.rating = const Value.absent(),
    this.year = const Value.absent(),
    this.plot = const Value.absent(),
    this.genre = const Value.absent(),
    this.castNames = const Value.absent(),
    this.director = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.episodesFetchedAt = const Value.absent(),
  }) : sourceId = Value(sourceId),
       remoteKey = Value(remoteKey),
       name = Value(name);
  static Insertable<SeriesRow> custom({
    Expression<String>? sourceId,
    Expression<String>? remoteKey,
    Expression<int>? position,
    Expression<int>? seenRun,
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<String>? name,
    Expression<String>? posterUrl,
    Expression<double>? rating,
    Expression<int>? year,
    Expression<String>? plot,
    Expression<String>? genre,
    Expression<String>? castNames,
    Expression<String>? director,
    Expression<String>? backdropUrl,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? episodesFetchedAt,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (position != null) 'position': position,
      if (seenRun != null) 'seen_run': seenRun,
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (posterUrl != null) 'poster_url': posterUrl,
      if (rating != null) 'rating': rating,
      if (year != null) 'year': year,
      if (plot != null) 'plot': plot,
      if (genre != null) 'genre': genre,
      if (castNames != null) 'cast_names': castNames,
      if (director != null) 'director': director,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (episodesFetchedAt != null) 'episodes_fetched_at': episodesFetchedAt,
    });
  }

  SeriesCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? remoteKey,
    Value<int>? position,
    Value<int?>? seenRun,
    Value<int>? id,
    Value<int?>? categoryId,
    Value<String>? name,
    Value<String?>? posterUrl,
    Value<double?>? rating,
    Value<int?>? year,
    Value<String?>? plot,
    Value<String?>? genre,
    Value<String?>? castNames,
    Value<String?>? director,
    Value<String?>? backdropUrl,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? episodesFetchedAt,
  }) {
    return SeriesCompanion(
      sourceId: sourceId ?? this.sourceId,
      remoteKey: remoteKey ?? this.remoteKey,
      position: position ?? this.position,
      seenRun: seenRun ?? this.seenRun,
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      posterUrl: posterUrl ?? this.posterUrl,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      plot: plot ?? this.plot,
      genre: genre ?? this.genre,
      castNames: castNames ?? this.castNames,
      director: director ?? this.director,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      episodesFetchedAt: episodesFetchedAt ?? this.episodesFetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (seenRun.present) {
      map['seen_run'] = Variable<int>(seenRun.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (posterUrl.present) {
      map['poster_url'] = Variable<String>(posterUrl.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (castNames.present) {
      map['cast_names'] = Variable<String>(castNames.value);
    }
    if (director.present) {
      map['director'] = Variable<String>(director.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (episodesFetchedAt.present) {
      map['episodes_fetched_at'] = Variable<DateTime>(episodesFetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('position: $position, ')
          ..write('seenRun: $seenRun, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('posterUrl: $posterUrl, ')
          ..write('rating: $rating, ')
          ..write('year: $year, ')
          ..write('plot: $plot, ')
          ..write('genre: $genre, ')
          ..write('castNames: $castNames, ')
          ..write('director: $director, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('episodesFetchedAt: $episodesFetchedAt')
          ..write(')'))
        .toString();
  }
}

class SeriesFts extends Table
    with TableInfo<SeriesFts, SeriesFt>, VirtualTableInfo<SeriesFts, SeriesFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SeriesFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SeriesFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesFt(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  SeriesFts createAlias(String alias) {
    return SeriesFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(name, content=\'series\', content_rowid=\'id\', tokenize=\'unicode61 remove_diacritics 2\', prefix=\'2 3\')';
}

class SeriesFt extends DataClass implements Insertable<SeriesFt> {
  final String name;
  const SeriesFt({required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    return map;
  }

  SeriesFtsCompanion toCompanion(bool nullToAbsent) {
    return SeriesFtsCompanion(name: Value(name));
  }

  factory SeriesFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesFt(name: serializer.fromJson<String>(json['name']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'name': serializer.toJson<String>(name)};
  }

  SeriesFt copyWith({String? name}) => SeriesFt(name: name ?? this.name);
  SeriesFt copyWithCompanion(SeriesFtsCompanion data) {
    return SeriesFt(name: data.name.present ? data.name.value : this.name);
  }

  @override
  String toString() {
    return (StringBuffer('SeriesFt(')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => name.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SeriesFt && other.name == this.name);
}

class SeriesFtsCompanion extends UpdateCompanion<SeriesFt> {
  final Value<String> name;
  final Value<int> rowid;
  const SeriesFtsCompanion({
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesFtsCompanion.insert({
    required String name,
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<SeriesFt> custom({
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesFtsCompanion copyWith({Value<String>? name, Value<int>? rowid}) {
    return SeriesFtsCompanion(
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesFtsCompanion(')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgProgramsTable extends EpgPrograms
    with TableInfo<$EpgProgramsTable, EpgProgramRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgProgramsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startUtcMeta = const VerificationMeta(
    'startUtc',
  );
  @override
  late final GeneratedColumn<int> startUtc = GeneratedColumn<int>(
    'start_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUtcMeta = const VerificationMeta('endUtc');
  @override
  late final GeneratedColumn<int> endUtc = GeneratedColumn<int>(
    'end_utc',
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
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    epgChannelId,
    startUtc,
    endUtc,
    title,
    subtitle,
    description,
    category,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_programs';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgProgramRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epgChannelIdMeta);
    }
    if (data.containsKey('start_utc')) {
      context.handle(
        _startUtcMeta,
        startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_startUtcMeta);
    }
    if (data.containsKey('end_utc')) {
      context.handle(
        _endUtcMeta,
        endUtc.isAcceptableOrUnknown(data['end_utc']!, _endUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_endUtcMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
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
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgProgramRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgProgramRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      )!,
      startUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utc'],
      )!,
      endUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_utc'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
    );
  }

  @override
  $EpgProgramsTable createAlias(String alias) {
    return $EpgProgramsTable(attachedDatabase, alias);
  }
}

class EpgProgramRow extends DataClass implements Insertable<EpgProgramRow> {
  final int id;
  final String sourceId;
  final String epgChannelId;
  final int startUtc;
  final int endUtc;
  final String title;
  final String? subtitle;
  final String? description;
  final String? category;
  const EpgProgramRow({
    required this.id,
    required this.sourceId,
    required this.epgChannelId,
    required this.startUtc,
    required this.endUtc,
    required this.title,
    this.subtitle,
    this.description,
    this.category,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['epg_channel_id'] = Variable<String>(epgChannelId);
    map['start_utc'] = Variable<int>(startUtc);
    map['end_utc'] = Variable<int>(endUtc);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || subtitle != null) {
      map['subtitle'] = Variable<String>(subtitle);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    return map;
  }

  EpgProgramsCompanion toCompanion(bool nullToAbsent) {
    return EpgProgramsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      epgChannelId: Value(epgChannelId),
      startUtc: Value(startUtc),
      endUtc: Value(endUtc),
      title: Value(title),
      subtitle: subtitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitle),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
    );
  }

  factory EpgProgramRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgProgramRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      epgChannelId: serializer.fromJson<String>(json['epgChannelId']),
      startUtc: serializer.fromJson<int>(json['startUtc']),
      endUtc: serializer.fromJson<int>(json['endUtc']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String?>(json['subtitle']),
      description: serializer.fromJson<String?>(json['description']),
      category: serializer.fromJson<String?>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'epgChannelId': serializer.toJson<String>(epgChannelId),
      'startUtc': serializer.toJson<int>(startUtc),
      'endUtc': serializer.toJson<int>(endUtc),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String?>(subtitle),
      'description': serializer.toJson<String?>(description),
      'category': serializer.toJson<String?>(category),
    };
  }

  EpgProgramRow copyWith({
    int? id,
    String? sourceId,
    String? epgChannelId,
    int? startUtc,
    int? endUtc,
    String? title,
    Value<String?> subtitle = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> category = const Value.absent(),
  }) => EpgProgramRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    epgChannelId: epgChannelId ?? this.epgChannelId,
    startUtc: startUtc ?? this.startUtc,
    endUtc: endUtc ?? this.endUtc,
    title: title ?? this.title,
    subtitle: subtitle.present ? subtitle.value : this.subtitle,
    description: description.present ? description.value : this.description,
    category: category.present ? category.value : this.category,
  );
  EpgProgramRow copyWithCompanion(EpgProgramsCompanion data) {
    return EpgProgramRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      startUtc: data.startUtc.present ? data.startUtc.value : this.startUtc,
      endUtc: data.endUtc.present ? data.endUtc.value : this.endUtc,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      description: data.description.present
          ? data.description.value
          : this.description,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('description: $description, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    epgChannelId,
    startUtc,
    endUtc,
    title,
    subtitle,
    description,
    category,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgProgramRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.epgChannelId == this.epgChannelId &&
          other.startUtc == this.startUtc &&
          other.endUtc == this.endUtc &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.description == this.description &&
          other.category == this.category);
}

class EpgProgramsCompanion extends UpdateCompanion<EpgProgramRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<String> epgChannelId;
  final Value<int> startUtc;
  final Value<int> endUtc;
  final Value<String> title;
  final Value<String?> subtitle;
  final Value<String?> description;
  final Value<String?> category;
  const EpgProgramsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.startUtc = const Value.absent(),
    this.endUtc = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
  });
  EpgProgramsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required String epgChannelId,
    required int startUtc,
    required int endUtc,
    required String title,
    this.subtitle = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
  }) : sourceId = Value(sourceId),
       epgChannelId = Value(epgChannelId),
       startUtc = Value(startUtc),
       endUtc = Value(endUtc),
       title = Value(title);
  static Insertable<EpgProgramRow> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<String>? epgChannelId,
    Expression<int>? startUtc,
    Expression<int>? endUtc,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? description,
    Expression<String>? category,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (startUtc != null) 'start_utc': startUtc,
      if (endUtc != null) 'end_utc': endUtc,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
    });
  }

  EpgProgramsCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<String>? epgChannelId,
    Value<int>? startUtc,
    Value<int>? endUtc,
    Value<String>? title,
    Value<String?>? subtitle,
    Value<String?>? description,
    Value<String?>? category,
  }) {
    return EpgProgramsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      category: category ?? this.category,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (startUtc.present) {
      map['start_utc'] = Variable<int>(startUtc.value);
    }
    if (endUtc.present) {
      map['end_utc'] = Variable<int>(endUtc.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('description: $description, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }
}

class ProgramsFts extends Table
    with
        TableInfo<ProgramsFts, ProgramsFt>,
        VirtualTableInfo<ProgramsFts, ProgramsFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ProgramsFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [title, subtitle, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'programs_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgramsFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    } else if (isInserting) {
      context.missing(_subtitleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  ProgramsFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramsFt(
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
    );
  }

  @override
  ProgramsFts createAlias(String alias) {
    return ProgramsFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(title, subtitle, description, content=\'epg_programs\', content_rowid=\'id\', tokenize=\'unicode61 remove_diacritics 2\', prefix=\'2 3\')';
}

class ProgramsFt extends DataClass implements Insertable<ProgramsFt> {
  final String title;
  final String subtitle;
  final String description;
  const ProgramsFt({
    required this.title,
    required this.subtitle,
    required this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    map['description'] = Variable<String>(description);
    return map;
  }

  ProgramsFtsCompanion toCompanion(bool nullToAbsent) {
    return ProgramsFtsCompanion(
      title: Value(title),
      subtitle: Value(subtitle),
      description: Value(description),
    );
  }

  factory ProgramsFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramsFt(
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      description: serializer.fromJson<String>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'description': serializer.toJson<String>(description),
    };
  }

  ProgramsFt copyWith({String? title, String? subtitle, String? description}) =>
      ProgramsFt(
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        description: description ?? this.description,
      );
  ProgramsFt copyWithCompanion(ProgramsFtsCompanion data) {
    return ProgramsFt(
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramsFt(')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(title, subtitle, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramsFt &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.description == this.description);
}

class ProgramsFtsCompanion extends UpdateCompanion<ProgramsFt> {
  final Value<String> title;
  final Value<String> subtitle;
  final Value<String> description;
  final Value<int> rowid;
  const ProgramsFtsCompanion({
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramsFtsCompanion.insert({
    required String title,
    required String subtitle,
    required String description,
    this.rowid = const Value.absent(),
  }) : title = Value(title),
       subtitle = Value(subtitle),
       description = Value(description);
  static Insertable<ProgramsFt> custom({
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramsFtsCompanion copyWith({
    Value<String>? title,
    Value<String>? subtitle,
    Value<String>? description,
    Value<int>? rowid,
  }) {
    return ProgramsFtsCompanion(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramsFtsCompanion(')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgImportsTable extends EpgImports
    with TableInfo<$EpgImportsTable, EpgImportRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgImportsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncOutcome, String> outcome =
      GeneratedColumn<String>(
        'outcome',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('running'),
      ).withConverter<SyncOutcome>($EpgImportsTable.$converteroutcome);
  static const VerificationMeta _failureMeta = const VerificationMeta(
    'failure',
  );
  @override
  late final GeneratedColumn<String> failure = GeneratedColumn<String>(
    'failure',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureStatusMeta = const VerificationMeta(
    'failureStatus',
  );
  @override
  late final GeneratedColumn<int> failureStatus = GeneratedColumn<int>(
    'failure_status',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countsJsonMeta = const VerificationMeta(
    'countsJson',
  );
  @override
  late final GeneratedColumn<String> countsJson = GeneratedColumn<String>(
    'counts_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLiveMeta = const VerificationMeta('isLive');
  @override
  late final GeneratedColumn<bool> isLive = GeneratedColumn<bool>(
    'is_live',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_live" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    startedAt,
    finishedAt,
    outcome,
    failure,
    failureStatus,
    countsJson,
    isLive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_imports';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgImportRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('failure')) {
      context.handle(
        _failureMeta,
        failure.isAcceptableOrUnknown(data['failure']!, _failureMeta),
      );
    }
    if (data.containsKey('failure_status')) {
      context.handle(
        _failureStatusMeta,
        failureStatus.isAcceptableOrUnknown(
          data['failure_status']!,
          _failureStatusMeta,
        ),
      );
    }
    if (data.containsKey('counts_json')) {
      context.handle(
        _countsJsonMeta,
        countsJson.isAcceptableOrUnknown(data['counts_json']!, _countsJsonMeta),
      );
    }
    if (data.containsKey('is_live')) {
      context.handle(
        _isLiveMeta,
        isLive.isAcceptableOrUnknown(data['is_live']!, _isLiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgImportRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgImportRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      outcome: $EpgImportsTable.$converteroutcome.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}outcome'],
        )!,
      ),
      failure: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure'],
      ),
      failureStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failure_status'],
      ),
      countsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counts_json'],
      ),
      isLive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_live'],
      )!,
    );
  }

  @override
  $EpgImportsTable createAlias(String alias) {
    return $EpgImportsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncOutcome, String, String> $converteroutcome =
      const EnumNameConverter<SyncOutcome>(SyncOutcome.values);
}

class EpgImportRow extends DataClass implements Insertable<EpgImportRow> {
  final int id;
  final String sourceId;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// [SyncOutcome], the same four states a sync run has. An import still
  /// `running` at launch belongs to a process that is gone.
  final SyncOutcome outcome;

  /// An `AppFailure.code`, never raw exception text (it can carry a
  /// credential-bearing URL).
  final String? failure;
  final int? failureStatus;

  /// `EpgImportCounts` as JSON: what was read, and why rows were skipped.
  final String? countsJson;

  /// True for the one import per source whose rows are in the live
  /// tables. Set by the swap, cleared from the import it replaces.
  final bool isLive;
  const EpgImportRow({
    required this.id,
    required this.sourceId,
    required this.startedAt,
    this.finishedAt,
    required this.outcome,
    this.failure,
    this.failureStatus,
    this.countsJson,
    required this.isLive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    {
      map['outcome'] = Variable<String>(
        $EpgImportsTable.$converteroutcome.toSql(outcome),
      );
    }
    if (!nullToAbsent || failure != null) {
      map['failure'] = Variable<String>(failure);
    }
    if (!nullToAbsent || failureStatus != null) {
      map['failure_status'] = Variable<int>(failureStatus);
    }
    if (!nullToAbsent || countsJson != null) {
      map['counts_json'] = Variable<String>(countsJson);
    }
    map['is_live'] = Variable<bool>(isLive);
    return map;
  }

  EpgImportsCompanion toCompanion(bool nullToAbsent) {
    return EpgImportsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      outcome: Value(outcome),
      failure: failure == null && nullToAbsent
          ? const Value.absent()
          : Value(failure),
      failureStatus: failureStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(failureStatus),
      countsJson: countsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(countsJson),
      isLive: Value(isLive),
    );
  }

  factory EpgImportRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgImportRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      outcome: $EpgImportsTable.$converteroutcome.fromJson(
        serializer.fromJson<String>(json['outcome']),
      ),
      failure: serializer.fromJson<String?>(json['failure']),
      failureStatus: serializer.fromJson<int?>(json['failureStatus']),
      countsJson: serializer.fromJson<String?>(json['countsJson']),
      isLive: serializer.fromJson<bool>(json['isLive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'outcome': serializer.toJson<String>(
        $EpgImportsTable.$converteroutcome.toJson(outcome),
      ),
      'failure': serializer.toJson<String?>(failure),
      'failureStatus': serializer.toJson<int?>(failureStatus),
      'countsJson': serializer.toJson<String?>(countsJson),
      'isLive': serializer.toJson<bool>(isLive),
    };
  }

  EpgImportRow copyWith({
    int? id,
    String? sourceId,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    SyncOutcome? outcome,
    Value<String?> failure = const Value.absent(),
    Value<int?> failureStatus = const Value.absent(),
    Value<String?> countsJson = const Value.absent(),
    bool? isLive,
  }) => EpgImportRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    outcome: outcome ?? this.outcome,
    failure: failure.present ? failure.value : this.failure,
    failureStatus: failureStatus.present
        ? failureStatus.value
        : this.failureStatus,
    countsJson: countsJson.present ? countsJson.value : this.countsJson,
    isLive: isLive ?? this.isLive,
  );
  EpgImportRow copyWithCompanion(EpgImportsCompanion data) {
    return EpgImportRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      failure: data.failure.present ? data.failure.value : this.failure,
      failureStatus: data.failureStatus.present
          ? data.failureStatus.value
          : this.failureStatus,
      countsJson: data.countsJson.present
          ? data.countsJson.value
          : this.countsJson,
      isLive: data.isLive.present ? data.isLive.value : this.isLive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgImportRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('outcome: $outcome, ')
          ..write('failure: $failure, ')
          ..write('failureStatus: $failureStatus, ')
          ..write('countsJson: $countsJson, ')
          ..write('isLive: $isLive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    startedAt,
    finishedAt,
    outcome,
    failure,
    failureStatus,
    countsJson,
    isLive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgImportRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.outcome == this.outcome &&
          other.failure == this.failure &&
          other.failureStatus == this.failureStatus &&
          other.countsJson == this.countsJson &&
          other.isLive == this.isLive);
}

class EpgImportsCompanion extends UpdateCompanion<EpgImportRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<SyncOutcome> outcome;
  final Value<String?> failure;
  final Value<int?> failureStatus;
  final Value<String?> countsJson;
  final Value<bool> isLive;
  const EpgImportsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.failure = const Value.absent(),
    this.failureStatus = const Value.absent(),
    this.countsJson = const Value.absent(),
    this.isLive = const Value.absent(),
  });
  EpgImportsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.failure = const Value.absent(),
    this.failureStatus = const Value.absent(),
    this.countsJson = const Value.absent(),
    this.isLive = const Value.absent(),
  }) : sourceId = Value(sourceId),
       startedAt = Value(startedAt);
  static Insertable<EpgImportRow> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? outcome,
    Expression<String>? failure,
    Expression<int>? failureStatus,
    Expression<String>? countsJson,
    Expression<bool>? isLive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (outcome != null) 'outcome': outcome,
      if (failure != null) 'failure': failure,
      if (failureStatus != null) 'failure_status': failureStatus,
      if (countsJson != null) 'counts_json': countsJson,
      if (isLive != null) 'is_live': isLive,
    });
  }

  EpgImportsCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<SyncOutcome>? outcome,
    Value<String?>? failure,
    Value<int?>? failureStatus,
    Value<String?>? countsJson,
    Value<bool>? isLive,
  }) {
    return EpgImportsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      outcome: outcome ?? this.outcome,
      failure: failure ?? this.failure,
      failureStatus: failureStatus ?? this.failureStatus,
      countsJson: countsJson ?? this.countsJson,
      isLive: isLive ?? this.isLive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(
        $EpgImportsTable.$converteroutcome.toSql(outcome.value),
      );
    }
    if (failure.present) {
      map['failure'] = Variable<String>(failure.value);
    }
    if (failureStatus.present) {
      map['failure_status'] = Variable<int>(failureStatus.value);
    }
    if (countsJson.present) {
      map['counts_json'] = Variable<String>(countsJson.value);
    }
    if (isLive.present) {
      map['is_live'] = Variable<bool>(isLive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgImportsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('outcome: $outcome, ')
          ..write('failure: $failure, ')
          ..write('failureStatus: $failureStatus, ')
          ..write('countsJson: $countsJson, ')
          ..write('isLive: $isLive')
          ..write(')'))
        .toString();
  }
}

class $EpgChannelsTable extends EpgChannels
    with TableInfo<$EpgChannelsTable, EpgChannelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgChannelsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _xmltvIdMeta = const VerificationMeta(
    'xmltvId',
  );
  @override
  late final GeneratedColumn<String> xmltvId = GeneratedColumn<String>(
    'xmltv_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    xmltvId,
    displayName,
    iconUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgChannelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('xmltv_id')) {
      context.handle(
        _xmltvIdMeta,
        xmltvId.isAcceptableOrUnknown(data['xmltv_id']!, _xmltvIdMeta),
      );
    } else if (isInserting) {
      context.missing(_xmltvIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceId, xmltvId},
  ];
  @override
  EpgChannelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgChannelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      xmltvId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}xmltv_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
    );
  }

  @override
  $EpgChannelsTable createAlias(String alias) {
    return $EpgChannelsTable(attachedDatabase, alias);
  }
}

class EpgChannelRow extends DataClass implements Insertable<EpgChannelRow> {
  final int id;
  final String sourceId;

  /// The XMLTV id, as the file writes it.
  final String xmltvId;
  final String? displayName;
  final String? iconUrl;
  const EpgChannelRow({
    required this.id,
    required this.sourceId,
    required this.xmltvId,
    this.displayName,
    this.iconUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['xmltv_id'] = Variable<String>(xmltvId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    return map;
  }

  EpgChannelsCompanion toCompanion(bool nullToAbsent) {
    return EpgChannelsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      xmltvId: Value(xmltvId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
    );
  }

  factory EpgChannelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgChannelRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      xmltvId: serializer.fromJson<String>(json['xmltvId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'xmltvId': serializer.toJson<String>(xmltvId),
      'displayName': serializer.toJson<String?>(displayName),
      'iconUrl': serializer.toJson<String?>(iconUrl),
    };
  }

  EpgChannelRow copyWith({
    int? id,
    String? sourceId,
    String? xmltvId,
    Value<String?> displayName = const Value.absent(),
    Value<String?> iconUrl = const Value.absent(),
  }) => EpgChannelRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    xmltvId: xmltvId ?? this.xmltvId,
    displayName: displayName.present ? displayName.value : this.displayName,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
  );
  EpgChannelRow copyWithCompanion(EpgChannelsCompanion data) {
    return EpgChannelRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      xmltvId: data.xmltvId.present ? data.xmltvId.value : this.xmltvId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('xmltvId: $xmltvId, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, xmltvId, displayName, iconUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgChannelRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.xmltvId == this.xmltvId &&
          other.displayName == this.displayName &&
          other.iconUrl == this.iconUrl);
}

class EpgChannelsCompanion extends UpdateCompanion<EpgChannelRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<String> xmltvId;
  final Value<String?> displayName;
  final Value<String?> iconUrl;
  const EpgChannelsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.xmltvId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.iconUrl = const Value.absent(),
  });
  EpgChannelsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required String xmltvId,
    this.displayName = const Value.absent(),
    this.iconUrl = const Value.absent(),
  }) : sourceId = Value(sourceId),
       xmltvId = Value(xmltvId);
  static Insertable<EpgChannelRow> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<String>? xmltvId,
    Expression<String>? displayName,
    Expression<String>? iconUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (xmltvId != null) 'xmltv_id': xmltvId,
      if (displayName != null) 'display_name': displayName,
      if (iconUrl != null) 'icon_url': iconUrl,
    });
  }

  EpgChannelsCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<String>? xmltvId,
    Value<String?>? displayName,
    Value<String?>? iconUrl,
  }) {
    return EpgChannelsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      xmltvId: xmltvId ?? this.xmltvId,
      displayName: displayName ?? this.displayName,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (xmltvId.present) {
      map['xmltv_id'] = Variable<String>(xmltvId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('xmltvId: $xmltvId, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl')
          ..write(')'))
        .toString();
  }
}

class $EpgChannelsStagingTable extends EpgChannelsStaging
    with TableInfo<$EpgChannelsStagingTable, EpgChannelStagingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgChannelsStagingTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _importRunMeta = const VerificationMeta(
    'importRun',
  );
  @override
  late final GeneratedColumn<int> importRun = GeneratedColumn<int>(
    'import_run',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES epg_imports (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _xmltvIdMeta = const VerificationMeta(
    'xmltvId',
  );
  @override
  late final GeneratedColumn<String> xmltvId = GeneratedColumn<String>(
    'xmltv_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importRun,
    xmltvId,
    displayName,
    iconUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_channels_staging';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgChannelStagingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('import_run')) {
      context.handle(
        _importRunMeta,
        importRun.isAcceptableOrUnknown(data['import_run']!, _importRunMeta),
      );
    } else if (isInserting) {
      context.missing(_importRunMeta);
    }
    if (data.containsKey('xmltv_id')) {
      context.handle(
        _xmltvIdMeta,
        xmltvId.isAcceptableOrUnknown(data['xmltv_id']!, _xmltvIdMeta),
      );
    } else if (isInserting) {
      context.missing(_xmltvIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {importRun, xmltvId},
  ];
  @override
  EpgChannelStagingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgChannelStagingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      importRun: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_run'],
      )!,
      xmltvId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}xmltv_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      ),
    );
  }

  @override
  $EpgChannelsStagingTable createAlias(String alias) {
    return $EpgChannelsStagingTable(attachedDatabase, alias);
  }
}

class EpgChannelStagingRow extends DataClass
    implements Insertable<EpgChannelStagingRow> {
  final int id;
  final int importRun;
  final String xmltvId;
  final String? displayName;
  final String? iconUrl;
  const EpgChannelStagingRow({
    required this.id,
    required this.importRun,
    required this.xmltvId,
    this.displayName,
    this.iconUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['import_run'] = Variable<int>(importRun);
    map['xmltv_id'] = Variable<String>(xmltvId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || iconUrl != null) {
      map['icon_url'] = Variable<String>(iconUrl);
    }
    return map;
  }

  EpgChannelsStagingCompanion toCompanion(bool nullToAbsent) {
    return EpgChannelsStagingCompanion(
      id: Value(id),
      importRun: Value(importRun),
      xmltvId: Value(xmltvId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      iconUrl: iconUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(iconUrl),
    );
  }

  factory EpgChannelStagingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgChannelStagingRow(
      id: serializer.fromJson<int>(json['id']),
      importRun: serializer.fromJson<int>(json['importRun']),
      xmltvId: serializer.fromJson<String>(json['xmltvId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      iconUrl: serializer.fromJson<String?>(json['iconUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'importRun': serializer.toJson<int>(importRun),
      'xmltvId': serializer.toJson<String>(xmltvId),
      'displayName': serializer.toJson<String?>(displayName),
      'iconUrl': serializer.toJson<String?>(iconUrl),
    };
  }

  EpgChannelStagingRow copyWith({
    int? id,
    int? importRun,
    String? xmltvId,
    Value<String?> displayName = const Value.absent(),
    Value<String?> iconUrl = const Value.absent(),
  }) => EpgChannelStagingRow(
    id: id ?? this.id,
    importRun: importRun ?? this.importRun,
    xmltvId: xmltvId ?? this.xmltvId,
    displayName: displayName.present ? displayName.value : this.displayName,
    iconUrl: iconUrl.present ? iconUrl.value : this.iconUrl,
  );
  EpgChannelStagingRow copyWithCompanion(EpgChannelsStagingCompanion data) {
    return EpgChannelStagingRow(
      id: data.id.present ? data.id.value : this.id,
      importRun: data.importRun.present ? data.importRun.value : this.importRun,
      xmltvId: data.xmltvId.present ? data.xmltvId.value : this.xmltvId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelStagingRow(')
          ..write('id: $id, ')
          ..write('importRun: $importRun, ')
          ..write('xmltvId: $xmltvId, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, importRun, xmltvId, displayName, iconUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgChannelStagingRow &&
          other.id == this.id &&
          other.importRun == this.importRun &&
          other.xmltvId == this.xmltvId &&
          other.displayName == this.displayName &&
          other.iconUrl == this.iconUrl);
}

class EpgChannelsStagingCompanion
    extends UpdateCompanion<EpgChannelStagingRow> {
  final Value<int> id;
  final Value<int> importRun;
  final Value<String> xmltvId;
  final Value<String?> displayName;
  final Value<String?> iconUrl;
  const EpgChannelsStagingCompanion({
    this.id = const Value.absent(),
    this.importRun = const Value.absent(),
    this.xmltvId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.iconUrl = const Value.absent(),
  });
  EpgChannelsStagingCompanion.insert({
    this.id = const Value.absent(),
    required int importRun,
    required String xmltvId,
    this.displayName = const Value.absent(),
    this.iconUrl = const Value.absent(),
  }) : importRun = Value(importRun),
       xmltvId = Value(xmltvId);
  static Insertable<EpgChannelStagingRow> custom({
    Expression<int>? id,
    Expression<int>? importRun,
    Expression<String>? xmltvId,
    Expression<String>? displayName,
    Expression<String>? iconUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importRun != null) 'import_run': importRun,
      if (xmltvId != null) 'xmltv_id': xmltvId,
      if (displayName != null) 'display_name': displayName,
      if (iconUrl != null) 'icon_url': iconUrl,
    });
  }

  EpgChannelsStagingCompanion copyWith({
    Value<int>? id,
    Value<int>? importRun,
    Value<String>? xmltvId,
    Value<String?>? displayName,
    Value<String?>? iconUrl,
  }) {
    return EpgChannelsStagingCompanion(
      id: id ?? this.id,
      importRun: importRun ?? this.importRun,
      xmltvId: xmltvId ?? this.xmltvId,
      displayName: displayName ?? this.displayName,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (importRun.present) {
      map['import_run'] = Variable<int>(importRun.value);
    }
    if (xmltvId.present) {
      map['xmltv_id'] = Variable<String>(xmltvId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelsStagingCompanion(')
          ..write('id: $id, ')
          ..write('importRun: $importRun, ')
          ..write('xmltvId: $xmltvId, ')
          ..write('displayName: $displayName, ')
          ..write('iconUrl: $iconUrl')
          ..write(')'))
        .toString();
  }
}

class $EpgProgramsStagingTable extends EpgProgramsStaging
    with TableInfo<$EpgProgramsStagingTable, EpgProgramStagingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgProgramsStagingTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _importRunMeta = const VerificationMeta(
    'importRun',
  );
  @override
  late final GeneratedColumn<int> importRun = GeneratedColumn<int>(
    'import_run',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES epg_imports (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startUtcMeta = const VerificationMeta(
    'startUtc',
  );
  @override
  late final GeneratedColumn<int> startUtc = GeneratedColumn<int>(
    'start_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endUtcMeta = const VerificationMeta('endUtc');
  @override
  late final GeneratedColumn<int> endUtc = GeneratedColumn<int>(
    'end_utc',
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
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importRun,
    epgChannelId,
    startUtc,
    endUtc,
    title,
    subtitle,
    description,
    category,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_programs_staging';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgProgramStagingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('import_run')) {
      context.handle(
        _importRunMeta,
        importRun.isAcceptableOrUnknown(data['import_run']!, _importRunMeta),
      );
    } else if (isInserting) {
      context.missing(_importRunMeta);
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epgChannelIdMeta);
    }
    if (data.containsKey('start_utc')) {
      context.handle(
        _startUtcMeta,
        startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_startUtcMeta);
    }
    if (data.containsKey('end_utc')) {
      context.handle(
        _endUtcMeta,
        endUtc.isAcceptableOrUnknown(data['end_utc']!, _endUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_endUtcMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
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
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpgProgramStagingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgProgramStagingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      importRun: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_run'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      )!,
      startUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utc'],
      )!,
      endUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_utc'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
    );
  }

  @override
  $EpgProgramsStagingTable createAlias(String alias) {
    return $EpgProgramsStagingTable(attachedDatabase, alias);
  }
}

class EpgProgramStagingRow extends DataClass
    implements Insertable<EpgProgramStagingRow> {
  final int id;
  final int importRun;
  final String epgChannelId;
  final int startUtc;
  final int endUtc;
  final String title;
  final String? subtitle;
  final String? description;
  final String? category;
  const EpgProgramStagingRow({
    required this.id,
    required this.importRun,
    required this.epgChannelId,
    required this.startUtc,
    required this.endUtc,
    required this.title,
    this.subtitle,
    this.description,
    this.category,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['import_run'] = Variable<int>(importRun);
    map['epg_channel_id'] = Variable<String>(epgChannelId);
    map['start_utc'] = Variable<int>(startUtc);
    map['end_utc'] = Variable<int>(endUtc);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || subtitle != null) {
      map['subtitle'] = Variable<String>(subtitle);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    return map;
  }

  EpgProgramsStagingCompanion toCompanion(bool nullToAbsent) {
    return EpgProgramsStagingCompanion(
      id: Value(id),
      importRun: Value(importRun),
      epgChannelId: Value(epgChannelId),
      startUtc: Value(startUtc),
      endUtc: Value(endUtc),
      title: Value(title),
      subtitle: subtitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subtitle),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
    );
  }

  factory EpgProgramStagingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgProgramStagingRow(
      id: serializer.fromJson<int>(json['id']),
      importRun: serializer.fromJson<int>(json['importRun']),
      epgChannelId: serializer.fromJson<String>(json['epgChannelId']),
      startUtc: serializer.fromJson<int>(json['startUtc']),
      endUtc: serializer.fromJson<int>(json['endUtc']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String?>(json['subtitle']),
      description: serializer.fromJson<String?>(json['description']),
      category: serializer.fromJson<String?>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'importRun': serializer.toJson<int>(importRun),
      'epgChannelId': serializer.toJson<String>(epgChannelId),
      'startUtc': serializer.toJson<int>(startUtc),
      'endUtc': serializer.toJson<int>(endUtc),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String?>(subtitle),
      'description': serializer.toJson<String?>(description),
      'category': serializer.toJson<String?>(category),
    };
  }

  EpgProgramStagingRow copyWith({
    int? id,
    int? importRun,
    String? epgChannelId,
    int? startUtc,
    int? endUtc,
    String? title,
    Value<String?> subtitle = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> category = const Value.absent(),
  }) => EpgProgramStagingRow(
    id: id ?? this.id,
    importRun: importRun ?? this.importRun,
    epgChannelId: epgChannelId ?? this.epgChannelId,
    startUtc: startUtc ?? this.startUtc,
    endUtc: endUtc ?? this.endUtc,
    title: title ?? this.title,
    subtitle: subtitle.present ? subtitle.value : this.subtitle,
    description: description.present ? description.value : this.description,
    category: category.present ? category.value : this.category,
  );
  EpgProgramStagingRow copyWithCompanion(EpgProgramsStagingCompanion data) {
    return EpgProgramStagingRow(
      id: data.id.present ? data.id.value : this.id,
      importRun: data.importRun.present ? data.importRun.value : this.importRun,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      startUtc: data.startUtc.present ? data.startUtc.value : this.startUtc,
      endUtc: data.endUtc.present ? data.endUtc.value : this.endUtc,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      description: data.description.present
          ? data.description.value
          : this.description,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramStagingRow(')
          ..write('id: $id, ')
          ..write('importRun: $importRun, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('description: $description, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    importRun,
    epgChannelId,
    startUtc,
    endUtc,
    title,
    subtitle,
    description,
    category,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgProgramStagingRow &&
          other.id == this.id &&
          other.importRun == this.importRun &&
          other.epgChannelId == this.epgChannelId &&
          other.startUtc == this.startUtc &&
          other.endUtc == this.endUtc &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.description == this.description &&
          other.category == this.category);
}

class EpgProgramsStagingCompanion
    extends UpdateCompanion<EpgProgramStagingRow> {
  final Value<int> id;
  final Value<int> importRun;
  final Value<String> epgChannelId;
  final Value<int> startUtc;
  final Value<int> endUtc;
  final Value<String> title;
  final Value<String?> subtitle;
  final Value<String?> description;
  final Value<String?> category;
  const EpgProgramsStagingCompanion({
    this.id = const Value.absent(),
    this.importRun = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.startUtc = const Value.absent(),
    this.endUtc = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
  });
  EpgProgramsStagingCompanion.insert({
    this.id = const Value.absent(),
    required int importRun,
    required String epgChannelId,
    required int startUtc,
    required int endUtc,
    required String title,
    this.subtitle = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
  }) : importRun = Value(importRun),
       epgChannelId = Value(epgChannelId),
       startUtc = Value(startUtc),
       endUtc = Value(endUtc),
       title = Value(title);
  static Insertable<EpgProgramStagingRow> custom({
    Expression<int>? id,
    Expression<int>? importRun,
    Expression<String>? epgChannelId,
    Expression<int>? startUtc,
    Expression<int>? endUtc,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? description,
    Expression<String>? category,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importRun != null) 'import_run': importRun,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (startUtc != null) 'start_utc': startUtc,
      if (endUtc != null) 'end_utc': endUtc,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
    });
  }

  EpgProgramsStagingCompanion copyWith({
    Value<int>? id,
    Value<int>? importRun,
    Value<String>? epgChannelId,
    Value<int>? startUtc,
    Value<int>? endUtc,
    Value<String>? title,
    Value<String?>? subtitle,
    Value<String?>? description,
    Value<String?>? category,
  }) {
    return EpgProgramsStagingCompanion(
      id: id ?? this.id,
      importRun: importRun ?? this.importRun,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      category: category ?? this.category,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (importRun.present) {
      map['import_run'] = Variable<int>(importRun.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (startUtc.present) {
      map['start_utc'] = Variable<int>(startUtc.value);
    }
    if (endUtc.present) {
      map['end_utc'] = Variable<int>(endUtc.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgProgramsStagingCompanion(')
          ..write('id: $id, ')
          ..write('importRun: $importRun, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('description: $description, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }
}

class $EpgMappingsTable extends EpgMappings
    with TableInfo<$EpgMappingsTable, EpgMappingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _channelRemoteKeyMeta = const VerificationMeta(
    'channelRemoteKey',
  );
  @override
  late final GeneratedColumn<String> channelRemoteKey = GeneratedColumn<String>(
    'channel_remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xmltvIdMeta = const VerificationMeta(
    'xmltvId',
  );
  @override
  late final GeneratedColumn<String> xmltvId = GeneratedColumn<String>(
    'xmltv_id',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    channelRemoteKey,
    xmltvId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgMappingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('channel_remote_key')) {
      context.handle(
        _channelRemoteKeyMeta,
        channelRemoteKey.isAcceptableOrUnknown(
          data['channel_remote_key']!,
          _channelRemoteKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_channelRemoteKeyMeta);
    }
    if (data.containsKey('xmltv_id')) {
      context.handle(
        _xmltvIdMeta,
        xmltvId.isAcceptableOrUnknown(data['xmltv_id']!, _xmltvIdMeta),
      );
    } else if (isInserting) {
      context.missing(_xmltvIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {sourceId, channelRemoteKey};
  @override
  EpgMappingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgMappingRow(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      channelRemoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_remote_key'],
      )!,
      xmltvId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}xmltv_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EpgMappingsTable createAlias(String alias) {
    return $EpgMappingsTable(attachedDatabase, alias);
  }
}

class EpgMappingRow extends DataClass implements Insertable<EpgMappingRow> {
  final String sourceId;
  final String channelRemoteKey;
  final String xmltvId;
  final DateTime updatedAt;
  const EpgMappingRow({
    required this.sourceId,
    required this.channelRemoteKey,
    required this.xmltvId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['channel_remote_key'] = Variable<String>(channelRemoteKey);
    map['xmltv_id'] = Variable<String>(xmltvId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EpgMappingsCompanion toCompanion(bool nullToAbsent) {
    return EpgMappingsCompanion(
      sourceId: Value(sourceId),
      channelRemoteKey: Value(channelRemoteKey),
      xmltvId: Value(xmltvId),
      updatedAt: Value(updatedAt),
    );
  }

  factory EpgMappingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgMappingRow(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      channelRemoteKey: serializer.fromJson<String>(json['channelRemoteKey']),
      xmltvId: serializer.fromJson<String>(json['xmltvId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'channelRemoteKey': serializer.toJson<String>(channelRemoteKey),
      'xmltvId': serializer.toJson<String>(xmltvId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EpgMappingRow copyWith({
    String? sourceId,
    String? channelRemoteKey,
    String? xmltvId,
    DateTime? updatedAt,
  }) => EpgMappingRow(
    sourceId: sourceId ?? this.sourceId,
    channelRemoteKey: channelRemoteKey ?? this.channelRemoteKey,
    xmltvId: xmltvId ?? this.xmltvId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EpgMappingRow copyWithCompanion(EpgMappingsCompanion data) {
    return EpgMappingRow(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      channelRemoteKey: data.channelRemoteKey.present
          ? data.channelRemoteKey.value
          : this.channelRemoteKey,
      xmltvId: data.xmltvId.present ? data.xmltvId.value : this.xmltvId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgMappingRow(')
          ..write('sourceId: $sourceId, ')
          ..write('channelRemoteKey: $channelRemoteKey, ')
          ..write('xmltvId: $xmltvId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceId, channelRemoteKey, xmltvId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgMappingRow &&
          other.sourceId == this.sourceId &&
          other.channelRemoteKey == this.channelRemoteKey &&
          other.xmltvId == this.xmltvId &&
          other.updatedAt == this.updatedAt);
}

class EpgMappingsCompanion extends UpdateCompanion<EpgMappingRow> {
  final Value<String> sourceId;
  final Value<String> channelRemoteKey;
  final Value<String> xmltvId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EpgMappingsCompanion({
    this.sourceId = const Value.absent(),
    this.channelRemoteKey = const Value.absent(),
    this.xmltvId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpgMappingsCompanion.insert({
    required String sourceId,
    required String channelRemoteKey,
    required String xmltvId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       channelRemoteKey = Value(channelRemoteKey),
       xmltvId = Value(xmltvId),
       updatedAt = Value(updatedAt);
  static Insertable<EpgMappingRow> custom({
    Expression<String>? sourceId,
    Expression<String>? channelRemoteKey,
    Expression<String>? xmltvId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (channelRemoteKey != null) 'channel_remote_key': channelRemoteKey,
      if (xmltvId != null) 'xmltv_id': xmltvId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpgMappingsCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? channelRemoteKey,
    Value<String>? xmltvId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EpgMappingsCompanion(
      sourceId: sourceId ?? this.sourceId,
      channelRemoteKey: channelRemoteKey ?? this.channelRemoteKey,
      xmltvId: xmltvId ?? this.xmltvId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (channelRemoteKey.present) {
      map['channel_remote_key'] = Variable<String>(channelRemoteKey.value);
    }
    if (xmltvId.present) {
      map['xmltv_id'] = Variable<String>(xmltvId.value);
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
    return (StringBuffer('EpgMappingsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('channelRemoteKey: $channelRemoteKey, ')
          ..write('xmltvId: $xmltvId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpgMatchesTable extends EpgMatches
    with TableInfo<$EpgMatchesTable, EpgMatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<int> channelId = GeneratedColumn<int>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES channels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _xmltvIdMeta = const VerificationMeta(
    'xmltvId',
  );
  @override
  late final GeneratedColumn<String> xmltvId = GeneratedColumn<String>(
    'xmltv_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EpgMatchRule, String> rule =
      GeneratedColumn<String>(
        'rule',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<EpgMatchRule>($EpgMatchesTable.$converterrule);
  @override
  List<GeneratedColumn> get $columns => [channelId, sourceId, xmltvId, rule];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgMatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('xmltv_id')) {
      context.handle(
        _xmltvIdMeta,
        xmltvId.isAcceptableOrUnknown(data['xmltv_id']!, _xmltvIdMeta),
      );
    } else if (isInserting) {
      context.missing(_xmltvIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {channelId};
  @override
  EpgMatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgMatchRow(
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channel_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      xmltvId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}xmltv_id'],
      )!,
      rule: $EpgMatchesTable.$converterrule.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rule'],
        )!,
      ),
    );
  }

  @override
  $EpgMatchesTable createAlias(String alias) {
    return $EpgMatchesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EpgMatchRule, String, String> $converterrule =
      const EnumNameConverter<EpgMatchRule>(EpgMatchRule.values);
}

class EpgMatchRow extends DataClass implements Insertable<EpgMatchRow> {
  final int channelId;
  final String sourceId;
  final String xmltvId;
  final EpgMatchRule rule;
  const EpgMatchRow({
    required this.channelId,
    required this.sourceId,
    required this.xmltvId,
    required this.rule,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['channel_id'] = Variable<int>(channelId);
    map['source_id'] = Variable<String>(sourceId);
    map['xmltv_id'] = Variable<String>(xmltvId);
    {
      map['rule'] = Variable<String>(
        $EpgMatchesTable.$converterrule.toSql(rule),
      );
    }
    return map;
  }

  EpgMatchesCompanion toCompanion(bool nullToAbsent) {
    return EpgMatchesCompanion(
      channelId: Value(channelId),
      sourceId: Value(sourceId),
      xmltvId: Value(xmltvId),
      rule: Value(rule),
    );
  }

  factory EpgMatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgMatchRow(
      channelId: serializer.fromJson<int>(json['channelId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      xmltvId: serializer.fromJson<String>(json['xmltvId']),
      rule: $EpgMatchesTable.$converterrule.fromJson(
        serializer.fromJson<String>(json['rule']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'channelId': serializer.toJson<int>(channelId),
      'sourceId': serializer.toJson<String>(sourceId),
      'xmltvId': serializer.toJson<String>(xmltvId),
      'rule': serializer.toJson<String>(
        $EpgMatchesTable.$converterrule.toJson(rule),
      ),
    };
  }

  EpgMatchRow copyWith({
    int? channelId,
    String? sourceId,
    String? xmltvId,
    EpgMatchRule? rule,
  }) => EpgMatchRow(
    channelId: channelId ?? this.channelId,
    sourceId: sourceId ?? this.sourceId,
    xmltvId: xmltvId ?? this.xmltvId,
    rule: rule ?? this.rule,
  );
  EpgMatchRow copyWithCompanion(EpgMatchesCompanion data) {
    return EpgMatchRow(
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      xmltvId: data.xmltvId.present ? data.xmltvId.value : this.xmltvId,
      rule: data.rule.present ? data.rule.value : this.rule,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgMatchRow(')
          ..write('channelId: $channelId, ')
          ..write('sourceId: $sourceId, ')
          ..write('xmltvId: $xmltvId, ')
          ..write('rule: $rule')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(channelId, sourceId, xmltvId, rule);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgMatchRow &&
          other.channelId == this.channelId &&
          other.sourceId == this.sourceId &&
          other.xmltvId == this.xmltvId &&
          other.rule == this.rule);
}

class EpgMatchesCompanion extends UpdateCompanion<EpgMatchRow> {
  final Value<int> channelId;
  final Value<String> sourceId;
  final Value<String> xmltvId;
  final Value<EpgMatchRule> rule;
  const EpgMatchesCompanion({
    this.channelId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.xmltvId = const Value.absent(),
    this.rule = const Value.absent(),
  });
  EpgMatchesCompanion.insert({
    this.channelId = const Value.absent(),
    required String sourceId,
    required String xmltvId,
    required EpgMatchRule rule,
  }) : sourceId = Value(sourceId),
       xmltvId = Value(xmltvId),
       rule = Value(rule);
  static Insertable<EpgMatchRow> custom({
    Expression<int>? channelId,
    Expression<String>? sourceId,
    Expression<String>? xmltvId,
    Expression<String>? rule,
  }) {
    return RawValuesInsertable({
      if (channelId != null) 'channel_id': channelId,
      if (sourceId != null) 'source_id': sourceId,
      if (xmltvId != null) 'xmltv_id': xmltvId,
      if (rule != null) 'rule': rule,
    });
  }

  EpgMatchesCompanion copyWith({
    Value<int>? channelId,
    Value<String>? sourceId,
    Value<String>? xmltvId,
    Value<EpgMatchRule>? rule,
  }) {
    return EpgMatchesCompanion(
      channelId: channelId ?? this.channelId,
      sourceId: sourceId ?? this.sourceId,
      xmltvId: xmltvId ?? this.xmltvId,
      rule: rule ?? this.rule,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (channelId.present) {
      map['channel_id'] = Variable<int>(channelId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (xmltvId.present) {
      map['xmltv_id'] = Variable<String>(xmltvId.value);
    }
    if (rule.present) {
      map['rule'] = Variable<String>(
        $EpgMatchesTable.$converterrule.toSql(rule.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgMatchesCompanion(')
          ..write('channelId: $channelId, ')
          ..write('sourceId: $sourceId, ')
          ..write('xmltvId: $xmltvId, ')
          ..write('rule: $rule')
          ..write(')'))
        .toString();
  }
}

class $SyncRunsTable extends SyncRuns
    with TableInfo<$SyncRunsTable, SyncRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRunsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sources (id) ON DELETE CASCADE',
    ),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SyncOutcome, String> outcome =
      GeneratedColumn<String>(
        'outcome',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('running'),
      ).withConverter<SyncOutcome>($SyncRunsTable.$converteroutcome);
  static const VerificationMeta _failureMeta = const VerificationMeta(
    'failure',
  );
  @override
  late final GeneratedColumn<String> failure = GeneratedColumn<String>(
    'failure',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureStatusMeta = const VerificationMeta(
    'failureStatus',
  );
  @override
  late final GeneratedColumn<int> failureStatus = GeneratedColumn<int>(
    'failure_status',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countsJsonMeta = const VerificationMeta(
    'countsJson',
  );
  @override
  late final GeneratedColumn<String> countsJson = GeneratedColumn<String>(
    'counts_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    startedAt,
    finishedAt,
    outcome,
    failure,
    failureStatus,
    countsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('failure')) {
      context.handle(
        _failureMeta,
        failure.isAcceptableOrUnknown(data['failure']!, _failureMeta),
      );
    }
    if (data.containsKey('failure_status')) {
      context.handle(
        _failureStatusMeta,
        failureStatus.isAcceptableOrUnknown(
          data['failure_status']!,
          _failureStatusMeta,
        ),
      );
    }
    if (data.containsKey('counts_json')) {
      context.handle(
        _countsJsonMeta,
        countsJson.isAcceptableOrUnknown(data['counts_json']!, _countsJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      outcome: $SyncRunsTable.$converteroutcome.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}outcome'],
        )!,
      ),
      failure: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure'],
      ),
      failureStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failure_status'],
      ),
      countsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counts_json'],
      ),
    );
  }

  @override
  $SyncRunsTable createAlias(String alias) {
    return $SyncRunsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncOutcome, String, String> $converteroutcome =
      const EnumNameConverter<SyncOutcome>(SyncOutcome.values);
}

class SyncRunRow extends DataClass implements Insertable<SyncRunRow> {
  final int id;
  final String sourceId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final SyncOutcome outcome;

  /// A failure kind for the UI to phrase (`failureMessage()`), never raw
  /// exception text, which can carry a credential-bearing URL.
  final String? failure;

  /// The HTTP status the server answered a failed run with, if any, so
  /// Settings can say what the server said (schema v3). Only the number:
  /// the failure's detail text can carry a credential.
  final int? failureStatus;

  /// Item counts per stage, for Settings → Sources and the diagnostics
  /// export.
  final String? countsJson;
  const SyncRunRow({
    required this.id,
    required this.sourceId,
    required this.startedAt,
    this.finishedAt,
    required this.outcome,
    this.failure,
    this.failureStatus,
    this.countsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    {
      map['outcome'] = Variable<String>(
        $SyncRunsTable.$converteroutcome.toSql(outcome),
      );
    }
    if (!nullToAbsent || failure != null) {
      map['failure'] = Variable<String>(failure);
    }
    if (!nullToAbsent || failureStatus != null) {
      map['failure_status'] = Variable<int>(failureStatus);
    }
    if (!nullToAbsent || countsJson != null) {
      map['counts_json'] = Variable<String>(countsJson);
    }
    return map;
  }

  SyncRunsCompanion toCompanion(bool nullToAbsent) {
    return SyncRunsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      outcome: Value(outcome),
      failure: failure == null && nullToAbsent
          ? const Value.absent()
          : Value(failure),
      failureStatus: failureStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(failureStatus),
      countsJson: countsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(countsJson),
    );
  }

  factory SyncRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRunRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      outcome: $SyncRunsTable.$converteroutcome.fromJson(
        serializer.fromJson<String>(json['outcome']),
      ),
      failure: serializer.fromJson<String?>(json['failure']),
      failureStatus: serializer.fromJson<int?>(json['failureStatus']),
      countsJson: serializer.fromJson<String?>(json['countsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'outcome': serializer.toJson<String>(
        $SyncRunsTable.$converteroutcome.toJson(outcome),
      ),
      'failure': serializer.toJson<String?>(failure),
      'failureStatus': serializer.toJson<int?>(failureStatus),
      'countsJson': serializer.toJson<String?>(countsJson),
    };
  }

  SyncRunRow copyWith({
    int? id,
    String? sourceId,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    SyncOutcome? outcome,
    Value<String?> failure = const Value.absent(),
    Value<int?> failureStatus = const Value.absent(),
    Value<String?> countsJson = const Value.absent(),
  }) => SyncRunRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    outcome: outcome ?? this.outcome,
    failure: failure.present ? failure.value : this.failure,
    failureStatus: failureStatus.present
        ? failureStatus.value
        : this.failureStatus,
    countsJson: countsJson.present ? countsJson.value : this.countsJson,
  );
  SyncRunRow copyWithCompanion(SyncRunsCompanion data) {
    return SyncRunRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      failure: data.failure.present ? data.failure.value : this.failure,
      failureStatus: data.failureStatus.present
          ? data.failureStatus.value
          : this.failureStatus,
      countsJson: data.countsJson.present
          ? data.countsJson.value
          : this.countsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRunRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('outcome: $outcome, ')
          ..write('failure: $failure, ')
          ..write('failureStatus: $failureStatus, ')
          ..write('countsJson: $countsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    startedAt,
    finishedAt,
    outcome,
    failure,
    failureStatus,
    countsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRunRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.outcome == this.outcome &&
          other.failure == this.failure &&
          other.failureStatus == this.failureStatus &&
          other.countsJson == this.countsJson);
}

class SyncRunsCompanion extends UpdateCompanion<SyncRunRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<SyncOutcome> outcome;
  final Value<String?> failure;
  final Value<int?> failureStatus;
  final Value<String?> countsJson;
  const SyncRunsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.failure = const Value.absent(),
    this.failureStatus = const Value.absent(),
    this.countsJson = const Value.absent(),
  });
  SyncRunsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.failure = const Value.absent(),
    this.failureStatus = const Value.absent(),
    this.countsJson = const Value.absent(),
  }) : sourceId = Value(sourceId),
       startedAt = Value(startedAt);
  static Insertable<SyncRunRow> custom({
    Expression<int>? id,
    Expression<String>? sourceId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? outcome,
    Expression<String>? failure,
    Expression<int>? failureStatus,
    Expression<String>? countsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (outcome != null) 'outcome': outcome,
      if (failure != null) 'failure': failure,
      if (failureStatus != null) 'failure_status': failureStatus,
      if (countsJson != null) 'counts_json': countsJson,
    });
  }

  SyncRunsCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<SyncOutcome>? outcome,
    Value<String?>? failure,
    Value<int?>? failureStatus,
    Value<String?>? countsJson,
  }) {
    return SyncRunsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      outcome: outcome ?? this.outcome,
      failure: failure ?? this.failure,
      failureStatus: failureStatus ?? this.failureStatus,
      countsJson: countsJson ?? this.countsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(
        $SyncRunsTable.$converteroutcome.toSql(outcome.value),
      );
    }
    if (failure.present) {
      map['failure'] = Variable<String>(failure.value);
    }
    if (failureStatus.present) {
      map['failure_status'] = Variable<int>(failureStatus.value);
    }
    if (countsJson.present) {
      map['counts_json'] = Variable<String>(countsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRunsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('outcome: $outcome, ')
          ..write('failure: $failure, ')
          ..write('failureStatus: $failureStatus, ')
          ..write('countsJson: $countsJson')
          ..write(')'))
        .toString();
  }
}

class $MovieDetailsTable extends MovieDetails
    with TableInfo<$MovieDetailsTable, MovieDetailsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MovieDetailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _movieIdMeta = const VerificationMeta(
    'movieId',
  );
  @override
  late final GeneratedColumn<int> movieId = GeneratedColumn<int>(
    'movie_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES movies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _castNamesMeta = const VerificationMeta(
    'castNames',
  );
  @override
  late final GeneratedColumn<String> castNames = GeneratedColumn<String>(
    'cast_names',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directorMeta = const VerificationMeta(
    'director',
  );
  @override
  late final GeneratedColumn<String> director = GeneratedColumn<String>(
    'director',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runtimeMinutesMeta = const VerificationMeta(
    'runtimeMinutes',
  );
  @override
  late final GeneratedColumn<int> runtimeMinutes = GeneratedColumn<int>(
    'runtime_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropUrlMeta = const VerificationMeta(
    'backdropUrl',
  );
  @override
  late final GeneratedColumn<String> backdropUrl = GeneratedColumn<String>(
    'backdrop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoHeightMeta = const VerificationMeta(
    'videoHeight',
  );
  @override
  late final GeneratedColumn<int> videoHeight = GeneratedColumn<int>(
    'video_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioChannelsMeta = const VerificationMeta(
    'audioChannels',
  );
  @override
  late final GeneratedColumn<int> audioChannels = GeneratedColumn<int>(
    'audio_channels',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    movieId,
    plot,
    castNames,
    director,
    genre,
    runtimeMinutes,
    backdropUrl,
    videoHeight,
    audioChannels,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movie_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<MovieDetailsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('movie_id')) {
      context.handle(
        _movieIdMeta,
        movieId.isAcceptableOrUnknown(data['movie_id']!, _movieIdMeta),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('cast_names')) {
      context.handle(
        _castNamesMeta,
        castNames.isAcceptableOrUnknown(data['cast_names']!, _castNamesMeta),
      );
    }
    if (data.containsKey('director')) {
      context.handle(
        _directorMeta,
        director.isAcceptableOrUnknown(data['director']!, _directorMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('runtime_minutes')) {
      context.handle(
        _runtimeMinutesMeta,
        runtimeMinutes.isAcceptableOrUnknown(
          data['runtime_minutes']!,
          _runtimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('backdrop_url')) {
      context.handle(
        _backdropUrlMeta,
        backdropUrl.isAcceptableOrUnknown(
          data['backdrop_url']!,
          _backdropUrlMeta,
        ),
      );
    }
    if (data.containsKey('video_height')) {
      context.handle(
        _videoHeightMeta,
        videoHeight.isAcceptableOrUnknown(
          data['video_height']!,
          _videoHeightMeta,
        ),
      );
    }
    if (data.containsKey('audio_channels')) {
      context.handle(
        _audioChannelsMeta,
        audioChannels.isAcceptableOrUnknown(
          data['audio_channels']!,
          _audioChannelsMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {movieId};
  @override
  MovieDetailsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MovieDetailsRow(
      movieId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}movie_id'],
      )!,
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      castNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast_names'],
      ),
      director: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}director'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      runtimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}runtime_minutes'],
      ),
      backdropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_url'],
      ),
      videoHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}video_height'],
      ),
      audioChannels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_channels'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $MovieDetailsTable createAlias(String alias) {
    return $MovieDetailsTable(attachedDatabase, alias);
  }
}

class MovieDetailsRow extends DataClass implements Insertable<MovieDetailsRow> {
  final int movieId;
  final String? plot;

  /// `cast` in the Xtream payload; not a column name, because CAST is SQL.
  final String? castNames;
  final String? director;
  final String? genre;
  final int? runtimeMinutes;
  final String? backdropUrl;

  /// The picture's height from the panel's probe of the file (v6), for the
  /// FHD / 4K badge; null when the panel didn't probe it.
  final int? videoHeight;

  /// Audio channels from the same probe (v6): 6 is the 5.1 badge.
  final int? audioChannels;
  final DateTime fetchedAt;
  const MovieDetailsRow({
    required this.movieId,
    this.plot,
    this.castNames,
    this.director,
    this.genre,
    this.runtimeMinutes,
    this.backdropUrl,
    this.videoHeight,
    this.audioChannels,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['movie_id'] = Variable<int>(movieId);
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || castNames != null) {
      map['cast_names'] = Variable<String>(castNames);
    }
    if (!nullToAbsent || director != null) {
      map['director'] = Variable<String>(director);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || runtimeMinutes != null) {
      map['runtime_minutes'] = Variable<int>(runtimeMinutes);
    }
    if (!nullToAbsent || backdropUrl != null) {
      map['backdrop_url'] = Variable<String>(backdropUrl);
    }
    if (!nullToAbsent || videoHeight != null) {
      map['video_height'] = Variable<int>(videoHeight);
    }
    if (!nullToAbsent || audioChannels != null) {
      map['audio_channels'] = Variable<int>(audioChannels);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  MovieDetailsCompanion toCompanion(bool nullToAbsent) {
    return MovieDetailsCompanion(
      movieId: Value(movieId),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      castNames: castNames == null && nullToAbsent
          ? const Value.absent()
          : Value(castNames),
      director: director == null && nullToAbsent
          ? const Value.absent()
          : Value(director),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      runtimeMinutes: runtimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(runtimeMinutes),
      backdropUrl: backdropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropUrl),
      videoHeight: videoHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(videoHeight),
      audioChannels: audioChannels == null && nullToAbsent
          ? const Value.absent()
          : Value(audioChannels),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory MovieDetailsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MovieDetailsRow(
      movieId: serializer.fromJson<int>(json['movieId']),
      plot: serializer.fromJson<String?>(json['plot']),
      castNames: serializer.fromJson<String?>(json['castNames']),
      director: serializer.fromJson<String?>(json['director']),
      genre: serializer.fromJson<String?>(json['genre']),
      runtimeMinutes: serializer.fromJson<int?>(json['runtimeMinutes']),
      backdropUrl: serializer.fromJson<String?>(json['backdropUrl']),
      videoHeight: serializer.fromJson<int?>(json['videoHeight']),
      audioChannels: serializer.fromJson<int?>(json['audioChannels']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'movieId': serializer.toJson<int>(movieId),
      'plot': serializer.toJson<String?>(plot),
      'castNames': serializer.toJson<String?>(castNames),
      'director': serializer.toJson<String?>(director),
      'genre': serializer.toJson<String?>(genre),
      'runtimeMinutes': serializer.toJson<int?>(runtimeMinutes),
      'backdropUrl': serializer.toJson<String?>(backdropUrl),
      'videoHeight': serializer.toJson<int?>(videoHeight),
      'audioChannels': serializer.toJson<int?>(audioChannels),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  MovieDetailsRow copyWith({
    int? movieId,
    Value<String?> plot = const Value.absent(),
    Value<String?> castNames = const Value.absent(),
    Value<String?> director = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> runtimeMinutes = const Value.absent(),
    Value<String?> backdropUrl = const Value.absent(),
    Value<int?> videoHeight = const Value.absent(),
    Value<int?> audioChannels = const Value.absent(),
    DateTime? fetchedAt,
  }) => MovieDetailsRow(
    movieId: movieId ?? this.movieId,
    plot: plot.present ? plot.value : this.plot,
    castNames: castNames.present ? castNames.value : this.castNames,
    director: director.present ? director.value : this.director,
    genre: genre.present ? genre.value : this.genre,
    runtimeMinutes: runtimeMinutes.present
        ? runtimeMinutes.value
        : this.runtimeMinutes,
    backdropUrl: backdropUrl.present ? backdropUrl.value : this.backdropUrl,
    videoHeight: videoHeight.present ? videoHeight.value : this.videoHeight,
    audioChannels: audioChannels.present
        ? audioChannels.value
        : this.audioChannels,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  MovieDetailsRow copyWithCompanion(MovieDetailsCompanion data) {
    return MovieDetailsRow(
      movieId: data.movieId.present ? data.movieId.value : this.movieId,
      plot: data.plot.present ? data.plot.value : this.plot,
      castNames: data.castNames.present ? data.castNames.value : this.castNames,
      director: data.director.present ? data.director.value : this.director,
      genre: data.genre.present ? data.genre.value : this.genre,
      runtimeMinutes: data.runtimeMinutes.present
          ? data.runtimeMinutes.value
          : this.runtimeMinutes,
      backdropUrl: data.backdropUrl.present
          ? data.backdropUrl.value
          : this.backdropUrl,
      videoHeight: data.videoHeight.present
          ? data.videoHeight.value
          : this.videoHeight,
      audioChannels: data.audioChannels.present
          ? data.audioChannels.value
          : this.audioChannels,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MovieDetailsRow(')
          ..write('movieId: $movieId, ')
          ..write('plot: $plot, ')
          ..write('castNames: $castNames, ')
          ..write('director: $director, ')
          ..write('genre: $genre, ')
          ..write('runtimeMinutes: $runtimeMinutes, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('videoHeight: $videoHeight, ')
          ..write('audioChannels: $audioChannels, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    movieId,
    plot,
    castNames,
    director,
    genre,
    runtimeMinutes,
    backdropUrl,
    videoHeight,
    audioChannels,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovieDetailsRow &&
          other.movieId == this.movieId &&
          other.plot == this.plot &&
          other.castNames == this.castNames &&
          other.director == this.director &&
          other.genre == this.genre &&
          other.runtimeMinutes == this.runtimeMinutes &&
          other.backdropUrl == this.backdropUrl &&
          other.videoHeight == this.videoHeight &&
          other.audioChannels == this.audioChannels &&
          other.fetchedAt == this.fetchedAt);
}

class MovieDetailsCompanion extends UpdateCompanion<MovieDetailsRow> {
  final Value<int> movieId;
  final Value<String?> plot;
  final Value<String?> castNames;
  final Value<String?> director;
  final Value<String?> genre;
  final Value<int?> runtimeMinutes;
  final Value<String?> backdropUrl;
  final Value<int?> videoHeight;
  final Value<int?> audioChannels;
  final Value<DateTime> fetchedAt;
  const MovieDetailsCompanion({
    this.movieId = const Value.absent(),
    this.plot = const Value.absent(),
    this.castNames = const Value.absent(),
    this.director = const Value.absent(),
    this.genre = const Value.absent(),
    this.runtimeMinutes = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.videoHeight = const Value.absent(),
    this.audioChannels = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  MovieDetailsCompanion.insert({
    this.movieId = const Value.absent(),
    this.plot = const Value.absent(),
    this.castNames = const Value.absent(),
    this.director = const Value.absent(),
    this.genre = const Value.absent(),
    this.runtimeMinutes = const Value.absent(),
    this.backdropUrl = const Value.absent(),
    this.videoHeight = const Value.absent(),
    this.audioChannels = const Value.absent(),
    required DateTime fetchedAt,
  }) : fetchedAt = Value(fetchedAt);
  static Insertable<MovieDetailsRow> custom({
    Expression<int>? movieId,
    Expression<String>? plot,
    Expression<String>? castNames,
    Expression<String>? director,
    Expression<String>? genre,
    Expression<int>? runtimeMinutes,
    Expression<String>? backdropUrl,
    Expression<int>? videoHeight,
    Expression<int>? audioChannels,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (movieId != null) 'movie_id': movieId,
      if (plot != null) 'plot': plot,
      if (castNames != null) 'cast_names': castNames,
      if (director != null) 'director': director,
      if (genre != null) 'genre': genre,
      if (runtimeMinutes != null) 'runtime_minutes': runtimeMinutes,
      if (backdropUrl != null) 'backdrop_url': backdropUrl,
      if (videoHeight != null) 'video_height': videoHeight,
      if (audioChannels != null) 'audio_channels': audioChannels,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  MovieDetailsCompanion copyWith({
    Value<int>? movieId,
    Value<String?>? plot,
    Value<String?>? castNames,
    Value<String?>? director,
    Value<String?>? genre,
    Value<int?>? runtimeMinutes,
    Value<String?>? backdropUrl,
    Value<int?>? videoHeight,
    Value<int?>? audioChannels,
    Value<DateTime>? fetchedAt,
  }) {
    return MovieDetailsCompanion(
      movieId: movieId ?? this.movieId,
      plot: plot ?? this.plot,
      castNames: castNames ?? this.castNames,
      director: director ?? this.director,
      genre: genre ?? this.genre,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      videoHeight: videoHeight ?? this.videoHeight,
      audioChannels: audioChannels ?? this.audioChannels,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (movieId.present) {
      map['movie_id'] = Variable<int>(movieId.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (castNames.present) {
      map['cast_names'] = Variable<String>(castNames.value);
    }
    if (director.present) {
      map['director'] = Variable<String>(director.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (runtimeMinutes.present) {
      map['runtime_minutes'] = Variable<int>(runtimeMinutes.value);
    }
    if (backdropUrl.present) {
      map['backdrop_url'] = Variable<String>(backdropUrl.value);
    }
    if (videoHeight.present) {
      map['video_height'] = Variable<int>(videoHeight.value);
    }
    if (audioChannels.present) {
      map['audio_channels'] = Variable<int>(audioChannels.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MovieDetailsCompanion(')
          ..write('movieId: $movieId, ')
          ..write('plot: $plot, ')
          ..write('castNames: $castNames, ')
          ..write('director: $director, ')
          ..write('genre: $genre, ')
          ..write('runtimeMinutes: $runtimeMinutes, ')
          ..write('backdropUrl: $backdropUrl, ')
          ..write('videoHeight: $videoHeight, ')
          ..write('audioChannels: $audioChannels, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes
    with TableInfo<$EpisodesTable, EpisodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<int> seriesId = GeneratedColumn<int>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES series (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
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
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  @override
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stillUrlMeta = const VerificationMeta(
    'stillUrl',
  );
  @override
  late final GeneratedColumn<String> stillUrl = GeneratedColumn<String>(
    'still_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extrasJsonMeta = const VerificationMeta(
    'extrasJson',
  );
  @override
  late final GeneratedColumn<String> extrasJson = GeneratedColumn<String>(
    'extras_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seenRunMeta = const VerificationMeta(
    'seenRun',
  );
  @override
  late final GeneratedColumn<int> seenRun = GeneratedColumn<int>(
    'seen_run',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    seriesId,
    remoteKey,
    season,
    episode,
    title,
    ext,
    durationSeconds,
    plot,
    stillUrl,
    streamUrl,
    extrasJson,
    seenRun,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteKeyMeta);
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    } else if (isInserting) {
      context.missing(_seasonMeta);
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('still_url')) {
      context.handle(
        _stillUrlMeta,
        stillUrl.isAcceptableOrUnknown(data['still_url']!, _stillUrlMeta),
      );
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    }
    if (data.containsKey('extras_json')) {
      context.handle(
        _extrasJsonMeta,
        extrasJson.isAcceptableOrUnknown(data['extras_json']!, _extrasJsonMeta),
      );
    }
    if (data.containsKey('seen_run')) {
      context.handle(
        _seenRunMeta,
        seenRun.isAcceptableOrUnknown(data['seen_run']!, _seenRunMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {seriesId, remoteKey},
  ];
  @override
  EpisodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_id'],
      )!,
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
      )!,
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      )!,
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      stillUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}still_url'],
      ),
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      ),
      extrasJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extras_json'],
      ),
      seenRun: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_run'],
      ),
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class EpisodeRow extends DataClass implements Insertable<EpisodeRow> {
  final int id;
  final int seriesId;
  final String remoteKey;
  final int season;
  final int episode;
  final String title;
  final String? ext;
  final int? durationSeconds;
  final String? plot;
  final String? stillUrl;

  /// See [Channels.streamUrl].
  final String? streamUrl;
  final String? extrasJson;

  /// Set when an M3U sync created the episode; Xtream episodes are
  /// replaced as a set when `get_series_info` is fetched again.
  final int? seenRun;
  const EpisodeRow({
    required this.id,
    required this.seriesId,
    required this.remoteKey,
    required this.season,
    required this.episode,
    required this.title,
    this.ext,
    this.durationSeconds,
    this.plot,
    this.stillUrl,
    this.streamUrl,
    this.extrasJson,
    this.seenRun,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['series_id'] = Variable<int>(seriesId);
    map['remote_key'] = Variable<String>(remoteKey);
    map['season'] = Variable<int>(season);
    map['episode'] = Variable<int>(episode);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || ext != null) {
      map['ext'] = Variable<String>(ext);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || stillUrl != null) {
      map['still_url'] = Variable<String>(stillUrl);
    }
    if (!nullToAbsent || streamUrl != null) {
      map['stream_url'] = Variable<String>(streamUrl);
    }
    if (!nullToAbsent || extrasJson != null) {
      map['extras_json'] = Variable<String>(extrasJson);
    }
    if (!nullToAbsent || seenRun != null) {
      map['seen_run'] = Variable<int>(seenRun);
    }
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      seriesId: Value(seriesId),
      remoteKey: Value(remoteKey),
      season: Value(season),
      episode: Value(episode),
      title: Value(title),
      ext: ext == null && nullToAbsent ? const Value.absent() : Value(ext),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      stillUrl: stillUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(stillUrl),
      streamUrl: streamUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(streamUrl),
      extrasJson: extrasJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extrasJson),
      seenRun: seenRun == null && nullToAbsent
          ? const Value.absent()
          : Value(seenRun),
    );
  }

  factory EpisodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeRow(
      id: serializer.fromJson<int>(json['id']),
      seriesId: serializer.fromJson<int>(json['seriesId']),
      remoteKey: serializer.fromJson<String>(json['remoteKey']),
      season: serializer.fromJson<int>(json['season']),
      episode: serializer.fromJson<int>(json['episode']),
      title: serializer.fromJson<String>(json['title']),
      ext: serializer.fromJson<String?>(json['ext']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      plot: serializer.fromJson<String?>(json['plot']),
      stillUrl: serializer.fromJson<String?>(json['stillUrl']),
      streamUrl: serializer.fromJson<String?>(json['streamUrl']),
      extrasJson: serializer.fromJson<String?>(json['extrasJson']),
      seenRun: serializer.fromJson<int?>(json['seenRun']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'seriesId': serializer.toJson<int>(seriesId),
      'remoteKey': serializer.toJson<String>(remoteKey),
      'season': serializer.toJson<int>(season),
      'episode': serializer.toJson<int>(episode),
      'title': serializer.toJson<String>(title),
      'ext': serializer.toJson<String?>(ext),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'plot': serializer.toJson<String?>(plot),
      'stillUrl': serializer.toJson<String?>(stillUrl),
      'streamUrl': serializer.toJson<String?>(streamUrl),
      'extrasJson': serializer.toJson<String?>(extrasJson),
      'seenRun': serializer.toJson<int?>(seenRun),
    };
  }

  EpisodeRow copyWith({
    int? id,
    int? seriesId,
    String? remoteKey,
    int? season,
    int? episode,
    String? title,
    Value<String?> ext = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<String?> stillUrl = const Value.absent(),
    Value<String?> streamUrl = const Value.absent(),
    Value<String?> extrasJson = const Value.absent(),
    Value<int?> seenRun = const Value.absent(),
  }) => EpisodeRow(
    id: id ?? this.id,
    seriesId: seriesId ?? this.seriesId,
    remoteKey: remoteKey ?? this.remoteKey,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    title: title ?? this.title,
    ext: ext.present ? ext.value : this.ext,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    plot: plot.present ? plot.value : this.plot,
    stillUrl: stillUrl.present ? stillUrl.value : this.stillUrl,
    streamUrl: streamUrl.present ? streamUrl.value : this.streamUrl,
    extrasJson: extrasJson.present ? extrasJson.value : this.extrasJson,
    seenRun: seenRun.present ? seenRun.value : this.seenRun,
  );
  EpisodeRow copyWithCompanion(EpisodesCompanion data) {
    return EpisodeRow(
      id: data.id.present ? data.id.value : this.id,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      title: data.title.present ? data.title.value : this.title,
      ext: data.ext.present ? data.ext.value : this.ext,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      plot: data.plot.present ? data.plot.value : this.plot,
      stillUrl: data.stillUrl.present ? data.stillUrl.value : this.stillUrl,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      extrasJson: data.extrasJson.present
          ? data.extrasJson.value
          : this.extrasJson,
      seenRun: data.seenRun.present ? data.seenRun.value : this.seenRun,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeRow(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('title: $title, ')
          ..write('ext: $ext, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('plot: $plot, ')
          ..write('stillUrl: $stillUrl, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('seenRun: $seenRun')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    remoteKey,
    season,
    episode,
    title,
    ext,
    durationSeconds,
    plot,
    stillUrl,
    streamUrl,
    extrasJson,
    seenRun,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeRow &&
          other.id == this.id &&
          other.seriesId == this.seriesId &&
          other.remoteKey == this.remoteKey &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.title == this.title &&
          other.ext == this.ext &&
          other.durationSeconds == this.durationSeconds &&
          other.plot == this.plot &&
          other.stillUrl == this.stillUrl &&
          other.streamUrl == this.streamUrl &&
          other.extrasJson == this.extrasJson &&
          other.seenRun == this.seenRun);
}

class EpisodesCompanion extends UpdateCompanion<EpisodeRow> {
  final Value<int> id;
  final Value<int> seriesId;
  final Value<String> remoteKey;
  final Value<int> season;
  final Value<int> episode;
  final Value<String> title;
  final Value<String?> ext;
  final Value<int?> durationSeconds;
  final Value<String?> plot;
  final Value<String?> stillUrl;
  final Value<String?> streamUrl;
  final Value<String?> extrasJson;
  final Value<int?> seenRun;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.title = const Value.absent(),
    this.ext = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.plot = const Value.absent(),
    this.stillUrl = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.seenRun = const Value.absent(),
  });
  EpisodesCompanion.insert({
    this.id = const Value.absent(),
    required int seriesId,
    required String remoteKey,
    required int season,
    required int episode,
    required String title,
    this.ext = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.plot = const Value.absent(),
    this.stillUrl = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.seenRun = const Value.absent(),
  }) : seriesId = Value(seriesId),
       remoteKey = Value(remoteKey),
       season = Value(season),
       episode = Value(episode),
       title = Value(title);
  static Insertable<EpisodeRow> custom({
    Expression<int>? id,
    Expression<int>? seriesId,
    Expression<String>? remoteKey,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<String>? title,
    Expression<String>? ext,
    Expression<int>? durationSeconds,
    Expression<String>? plot,
    Expression<String>? stillUrl,
    Expression<String>? streamUrl,
    Expression<String>? extrasJson,
    Expression<int>? seenRun,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seriesId != null) 'series_id': seriesId,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (title != null) 'title': title,
      if (ext != null) 'ext': ext,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (plot != null) 'plot': plot,
      if (stillUrl != null) 'still_url': stillUrl,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (extrasJson != null) 'extras_json': extrasJson,
      if (seenRun != null) 'seen_run': seenRun,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? id,
    Value<int>? seriesId,
    Value<String>? remoteKey,
    Value<int>? season,
    Value<int>? episode,
    Value<String>? title,
    Value<String?>? ext,
    Value<int?>? durationSeconds,
    Value<String?>? plot,
    Value<String?>? stillUrl,
    Value<String?>? streamUrl,
    Value<String?>? extrasJson,
    Value<int?>? seenRun,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      remoteKey: remoteKey ?? this.remoteKey,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      title: title ?? this.title,
      ext: ext ?? this.ext,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      plot: plot ?? this.plot,
      stillUrl: stillUrl ?? this.stillUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      extrasJson: extrasJson ?? this.extrasJson,
      seenRun: seenRun ?? this.seenRun,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<int>(seriesId.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (stillUrl.present) {
      map['still_url'] = Variable<String>(stillUrl.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (extrasJson.present) {
      map['extras_json'] = Variable<String>(extrasJson.value);
    }
    if (seenRun.present) {
      map['seen_run'] = Variable<int>(seenRun.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('seriesId: $seriesId, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('title: $title, ')
          ..write('ext: $ext, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('plot: $plot, ')
          ..write('stillUrl: $stillUrl, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('seenRun: $seenRun')
          ..write(')'))
        .toString();
  }
}

class $CastDevicesTable extends CastDevices
    with TableInfo<$CastDevicesTable, CastDeviceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CastDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
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
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastHostMeta = const VerificationMeta(
    'lastHost',
  );
  @override
  late final GeneratedColumn<String> lastHost = GeneratedColumn<String>(
    'last_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPortMeta = const VerificationMeta(
    'lastPort',
  );
  @override
  late final GeneratedColumn<int> lastPort = GeneratedColumn<int>(
    'last_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8009),
  );
  static const VerificationMeta _isManualMeta = const VerificationMeta(
    'isManual',
  );
  @override
  late final GeneratedColumn<bool> isManual = GeneratedColumn<bool>(
    'is_manual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_manual" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<HevcSupport, String> hevcSupport =
      GeneratedColumn<String>(
        'hevc_support',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(HevcSupport.auto.name),
      ).withConverter<HevcSupport>($CastDevicesTable.$converterhevcSupport);
  static const VerificationMeta _learnedJsonMeta = const VerificationMeta(
    'learnedJson',
  );
  @override
  late final GeneratedColumn<String> learnedJson = GeneratedColumn<String>(
    'learned_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    name,
    model,
    lastHost,
    lastPort,
    isManual,
    hevcSupport,
    learnedJson,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cast_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<CastDeviceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('last_host')) {
      context.handle(
        _lastHostMeta,
        lastHost.isAcceptableOrUnknown(data['last_host']!, _lastHostMeta),
      );
    } else if (isInserting) {
      context.missing(_lastHostMeta);
    }
    if (data.containsKey('last_port')) {
      context.handle(
        _lastPortMeta,
        lastPort.isAcceptableOrUnknown(data['last_port']!, _lastPortMeta),
      );
    }
    if (data.containsKey('is_manual')) {
      context.handle(
        _isManualMeta,
        isManual.isAcceptableOrUnknown(data['is_manual']!, _isManualMeta),
      );
    }
    if (data.containsKey('learned_json')) {
      context.handle(
        _learnedJsonMeta,
        learnedJson.isAcceptableOrUnknown(
          data['learned_json']!,
          _learnedJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  CastDeviceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CastDeviceRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      lastHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_host'],
      )!,
      lastPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_port'],
      )!,
      isManual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_manual'],
      )!,
      hevcSupport: $CastDevicesTable.$converterhevcSupport.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}hevc_support'],
        )!,
      ),
      learnedJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learned_json'],
      ),
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
    );
  }

  @override
  $CastDevicesTable createAlias(String alias) {
    return $CastDevicesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<HevcSupport, String, String> $converterhevcSupport =
      const EnumNameConverter<HevcSupport>(HevcSupport.values);
}

class CastDeviceRow extends DataClass implements Insertable<CastDeviceRow> {
  /// The device's own id (TXT `id`).
  final String deviceId;
  final String name;
  final String? model;

  /// Where it was last seen or used.
  final String lastHost;

  /// 8009 (`castPort`, written out: the generated code copies the
  /// literal) for every real device; another only for a test receiver
  /// added by address (`127.0.0.1:<port>`).
  final int lastPort;
  final bool isManual;
  final HevcSupport hevcSupport;

  /// What was learned from refusals (`CastLearned`), as JSON; null is
  /// nothing yet.
  final String? learnedJson;
  final DateTime? lastUsedAt;
  const CastDeviceRow({
    required this.deviceId,
    required this.name,
    this.model,
    required this.lastHost,
    required this.lastPort,
    required this.isManual,
    required this.hevcSupport,
    this.learnedJson,
    this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    map['last_host'] = Variable<String>(lastHost);
    map['last_port'] = Variable<int>(lastPort);
    map['is_manual'] = Variable<bool>(isManual);
    {
      map['hevc_support'] = Variable<String>(
        $CastDevicesTable.$converterhevcSupport.toSql(hevcSupport),
      );
    }
    if (!nullToAbsent || learnedJson != null) {
      map['learned_json'] = Variable<String>(learnedJson);
    }
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    return map;
  }

  CastDevicesCompanion toCompanion(bool nullToAbsent) {
    return CastDevicesCompanion(
      deviceId: Value(deviceId),
      name: Value(name),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      lastHost: Value(lastHost),
      lastPort: Value(lastPort),
      isManual: Value(isManual),
      hevcSupport: Value(hevcSupport),
      learnedJson: learnedJson == null && nullToAbsent
          ? const Value.absent()
          : Value(learnedJson),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
    );
  }

  factory CastDeviceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CastDeviceRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      name: serializer.fromJson<String>(json['name']),
      model: serializer.fromJson<String?>(json['model']),
      lastHost: serializer.fromJson<String>(json['lastHost']),
      lastPort: serializer.fromJson<int>(json['lastPort']),
      isManual: serializer.fromJson<bool>(json['isManual']),
      hevcSupport: $CastDevicesTable.$converterhevcSupport.fromJson(
        serializer.fromJson<String>(json['hevcSupport']),
      ),
      learnedJson: serializer.fromJson<String?>(json['learnedJson']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'name': serializer.toJson<String>(name),
      'model': serializer.toJson<String?>(model),
      'lastHost': serializer.toJson<String>(lastHost),
      'lastPort': serializer.toJson<int>(lastPort),
      'isManual': serializer.toJson<bool>(isManual),
      'hevcSupport': serializer.toJson<String>(
        $CastDevicesTable.$converterhevcSupport.toJson(hevcSupport),
      ),
      'learnedJson': serializer.toJson<String?>(learnedJson),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
    };
  }

  CastDeviceRow copyWith({
    String? deviceId,
    String? name,
    Value<String?> model = const Value.absent(),
    String? lastHost,
    int? lastPort,
    bool? isManual,
    HevcSupport? hevcSupport,
    Value<String?> learnedJson = const Value.absent(),
    Value<DateTime?> lastUsedAt = const Value.absent(),
  }) => CastDeviceRow(
    deviceId: deviceId ?? this.deviceId,
    name: name ?? this.name,
    model: model.present ? model.value : this.model,
    lastHost: lastHost ?? this.lastHost,
    lastPort: lastPort ?? this.lastPort,
    isManual: isManual ?? this.isManual,
    hevcSupport: hevcSupport ?? this.hevcSupport,
    learnedJson: learnedJson.present ? learnedJson.value : this.learnedJson,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
  );
  CastDeviceRow copyWithCompanion(CastDevicesCompanion data) {
    return CastDeviceRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      name: data.name.present ? data.name.value : this.name,
      model: data.model.present ? data.model.value : this.model,
      lastHost: data.lastHost.present ? data.lastHost.value : this.lastHost,
      lastPort: data.lastPort.present ? data.lastPort.value : this.lastPort,
      isManual: data.isManual.present ? data.isManual.value : this.isManual,
      hevcSupport: data.hevcSupport.present
          ? data.hevcSupport.value
          : this.hevcSupport,
      learnedJson: data.learnedJson.present
          ? data.learnedJson.value
          : this.learnedJson,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CastDeviceRow(')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('model: $model, ')
          ..write('lastHost: $lastHost, ')
          ..write('lastPort: $lastPort, ')
          ..write('isManual: $isManual, ')
          ..write('hevcSupport: $hevcSupport, ')
          ..write('learnedJson: $learnedJson, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    name,
    model,
    lastHost,
    lastPort,
    isManual,
    hevcSupport,
    learnedJson,
    lastUsedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CastDeviceRow &&
          other.deviceId == this.deviceId &&
          other.name == this.name &&
          other.model == this.model &&
          other.lastHost == this.lastHost &&
          other.lastPort == this.lastPort &&
          other.isManual == this.isManual &&
          other.hevcSupport == this.hevcSupport &&
          other.learnedJson == this.learnedJson &&
          other.lastUsedAt == this.lastUsedAt);
}

class CastDevicesCompanion extends UpdateCompanion<CastDeviceRow> {
  final Value<String> deviceId;
  final Value<String> name;
  final Value<String?> model;
  final Value<String> lastHost;
  final Value<int> lastPort;
  final Value<bool> isManual;
  final Value<HevcSupport> hevcSupport;
  final Value<String?> learnedJson;
  final Value<DateTime?> lastUsedAt;
  final Value<int> rowid;
  const CastDevicesCompanion({
    this.deviceId = const Value.absent(),
    this.name = const Value.absent(),
    this.model = const Value.absent(),
    this.lastHost = const Value.absent(),
    this.lastPort = const Value.absent(),
    this.isManual = const Value.absent(),
    this.hevcSupport = const Value.absent(),
    this.learnedJson = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CastDevicesCompanion.insert({
    required String deviceId,
    required String name,
    this.model = const Value.absent(),
    required String lastHost,
    this.lastPort = const Value.absent(),
    this.isManual = const Value.absent(),
    this.hevcSupport = const Value.absent(),
    this.learnedJson = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       name = Value(name),
       lastHost = Value(lastHost);
  static Insertable<CastDeviceRow> custom({
    Expression<String>? deviceId,
    Expression<String>? name,
    Expression<String>? model,
    Expression<String>? lastHost,
    Expression<int>? lastPort,
    Expression<bool>? isManual,
    Expression<String>? hevcSupport,
    Expression<String>? learnedJson,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (name != null) 'name': name,
      if (model != null) 'model': model,
      if (lastHost != null) 'last_host': lastHost,
      if (lastPort != null) 'last_port': lastPort,
      if (isManual != null) 'is_manual': isManual,
      if (hevcSupport != null) 'hevc_support': hevcSupport,
      if (learnedJson != null) 'learned_json': learnedJson,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CastDevicesCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? name,
    Value<String?>? model,
    Value<String>? lastHost,
    Value<int>? lastPort,
    Value<bool>? isManual,
    Value<HevcSupport>? hevcSupport,
    Value<String?>? learnedJson,
    Value<DateTime?>? lastUsedAt,
    Value<int>? rowid,
  }) {
    return CastDevicesCompanion(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      model: model ?? this.model,
      lastHost: lastHost ?? this.lastHost,
      lastPort: lastPort ?? this.lastPort,
      isManual: isManual ?? this.isManual,
      hevcSupport: hevcSupport ?? this.hevcSupport,
      learnedJson: learnedJson ?? this.learnedJson,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (lastHost.present) {
      map['last_host'] = Variable<String>(lastHost.value);
    }
    if (lastPort.present) {
      map['last_port'] = Variable<int>(lastPort.value);
    }
    if (isManual.present) {
      map['is_manual'] = Variable<bool>(isManual.value);
    }
    if (hevcSupport.present) {
      map['hevc_support'] = Variable<String>(
        $CastDevicesTable.$converterhevcSupport.toSql(hevcSupport.value),
      );
    }
    if (learnedJson.present) {
      map['learned_json'] = Variable<String>(learnedJson.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CastDevicesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('model: $model, ')
          ..write('lastHost: $lastHost, ')
          ..write('lastPort: $lastPort, ')
          ..write('isManual: $isManual, ')
          ..write('hevcSupport: $hevcSupport, ')
          ..write('learnedJson: $learnedJson, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LibraryFoldersTable libraryFolders = $LibraryFoldersTable(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $LibraryItemsTable libraryItems = $LibraryItemsTable(this);
  late final LibraryFts libraryFts = LibraryFts(this);
  late final Trigger libraryFtsInsert = Trigger(
    'CREATE TRIGGER library_fts_insert AFTER INSERT ON library_items BEGIN INSERT INTO library_fts ("rowid", title, show_title) VALUES (new.id, new.title, new.show_title);END',
    'library_fts_insert',
  );
  late final Trigger libraryFtsDelete = Trigger(
    'CREATE TRIGGER library_fts_delete AFTER DELETE ON library_items BEGIN INSERT INTO library_fts (library_fts, "rowid", title, show_title) VALUES (\'delete\', old.id, old.title, old.show_title);END',
    'library_fts_delete',
  );
  late final Trigger libraryFtsUpdate = Trigger(
    'CREATE TRIGGER library_fts_update AFTER UPDATE OF title, show_title ON library_items WHEN old.title IS NOT new.title OR old.show_title IS NOT new.show_title BEGIN INSERT INTO library_fts (library_fts, "rowid", title, show_title) VALUES (\'delete\', old.id, old.title, old.show_title);INSERT INTO library_fts ("rowid", title, show_title) VALUES (new.id, new.title, new.show_title);END',
    'library_fts_update',
  );
  late final $FavoriteGroupsTable favoriteGroups = $FavoriteGroupsTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final Index favoritesLocal = Index(
    'favorites_local',
    'CREATE UNIQUE INDEX favorites_local ON favorites (item_type, remote_key) WHERE source_id IS NULL',
  );
  late final $WatchHistoryTable watchHistory = $WatchHistoryTable(this);
  late final Index watchHistoryLocal = Index(
    'watch_history_local',
    'CREATE UNIQUE INDEX watch_history_local ON watch_history (item_type, remote_key) WHERE source_id IS NULL',
  );
  late final Index watchHistoryRecent = Index(
    'watch_history_recent',
    'CREATE INDEX watch_history_recent ON watch_history (item_type, updated_at)',
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final Index libraryItemsHash = Index(
    'library_items_hash',
    'CREATE INDEX library_items_hash ON library_items (quick_hash)',
  );
  late final Index libraryItemsKindTitle = Index(
    'library_items_kind_title',
    'CREATE INDEX library_items_kind_title ON library_items (kind, title)',
  );
  late final Index libraryItemsProvider = Index(
    'library_items_provider',
    'CREATE INDEX library_items_provider ON library_items (provider_source_id, provider_item_type, provider_remote_key)',
  );
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final ChannelsFts channelsFts = ChannelsFts(this);
  late final Trigger channelsFtsInsert = Trigger(
    'CREATE TRIGGER channels_fts_insert AFTER INSERT ON channels BEGIN INSERT INTO channels_fts ("rowid", clean_name, display_name) VALUES (new.id, new.clean_name, new.display_name);END',
    'channels_fts_insert',
  );
  late final Trigger channelsFtsDelete = Trigger(
    'CREATE TRIGGER channels_fts_delete AFTER DELETE ON channels BEGIN INSERT INTO channels_fts (channels_fts, "rowid", clean_name, display_name) VALUES (\'delete\', old.id, old.clean_name, old.display_name);END',
    'channels_fts_delete',
  );
  late final Trigger channelsFtsUpdate = Trigger(
    'CREATE TRIGGER channels_fts_update AFTER UPDATE OF clean_name, display_name ON channels WHEN old.clean_name IS NOT new.clean_name OR old.display_name IS NOT new.display_name BEGIN INSERT INTO channels_fts (channels_fts, "rowid", clean_name, display_name) VALUES (\'delete\', old.id, old.clean_name, old.display_name);INSERT INTO channels_fts ("rowid", clean_name, display_name) VALUES (new.id, new.clean_name, new.display_name);END',
    'channels_fts_update',
  );
  late final $MoviesTable movies = $MoviesTable(this);
  late final MoviesFts moviesFts = MoviesFts(this);
  late final Trigger moviesFtsInsert = Trigger(
    'CREATE TRIGGER movies_fts_insert AFTER INSERT ON movies BEGIN INSERT INTO movies_fts ("rowid", name) VALUES (new.id, new.name);END',
    'movies_fts_insert',
  );
  late final Trigger moviesFtsDelete = Trigger(
    'CREATE TRIGGER movies_fts_delete AFTER DELETE ON movies BEGIN INSERT INTO movies_fts (movies_fts, "rowid", name) VALUES (\'delete\', old.id, old.name);END',
    'movies_fts_delete',
  );
  late final Trigger moviesFtsUpdate = Trigger(
    'CREATE TRIGGER movies_fts_update AFTER UPDATE OF name ON movies WHEN old.name IS NOT new.name BEGIN INSERT INTO movies_fts (movies_fts, "rowid", name) VALUES (\'delete\', old.id, old.name);INSERT INTO movies_fts ("rowid", name) VALUES (new.id, new.name);END',
    'movies_fts_update',
  );
  late final $SeriesTable series = $SeriesTable(this);
  late final SeriesFts seriesFts = SeriesFts(this);
  late final Trigger seriesFtsInsert = Trigger(
    'CREATE TRIGGER series_fts_insert AFTER INSERT ON series BEGIN INSERT INTO series_fts ("rowid", name) VALUES (new.id, new.name);END',
    'series_fts_insert',
  );
  late final Trigger seriesFtsDelete = Trigger(
    'CREATE TRIGGER series_fts_delete AFTER DELETE ON series BEGIN INSERT INTO series_fts (series_fts, "rowid", name) VALUES (\'delete\', old.id, old.name);END',
    'series_fts_delete',
  );
  late final Trigger seriesFtsUpdate = Trigger(
    'CREATE TRIGGER series_fts_update AFTER UPDATE OF name ON series WHEN old.name IS NOT new.name BEGIN INSERT INTO series_fts (series_fts, "rowid", name) VALUES (\'delete\', old.id, old.name);INSERT INTO series_fts ("rowid", name) VALUES (new.id, new.name);END',
    'series_fts_update',
  );
  late final $EpgProgramsTable epgPrograms = $EpgProgramsTable(this);
  late final ProgramsFts programsFts = ProgramsFts(this);
  late final Trigger programsFtsInsert = Trigger(
    'CREATE TRIGGER programs_fts_insert AFTER INSERT ON epg_programs BEGIN INSERT INTO programs_fts ("rowid", title, subtitle, description) VALUES (new.id, new.title, new.subtitle, new.description);END',
    'programs_fts_insert',
  );
  late final Trigger programsFtsDelete = Trigger(
    'CREATE TRIGGER programs_fts_delete AFTER DELETE ON epg_programs BEGIN INSERT INTO programs_fts (programs_fts, "rowid", title, subtitle, description) VALUES (\'delete\', old.id, old.title, old.subtitle, old.description);END',
    'programs_fts_delete',
  );
  late final Trigger programsFtsUpdate = Trigger(
    'CREATE TRIGGER programs_fts_update AFTER UPDATE OF title, subtitle, description ON epg_programs WHEN old.title IS NOT new.title OR old.subtitle IS NOT new.subtitle OR old.description IS NOT new.description BEGIN INSERT INTO programs_fts (programs_fts, "rowid", title, subtitle, description) VALUES (\'delete\', old.id, old.title, old.subtitle, old.description);INSERT INTO programs_fts ("rowid", title, subtitle, description) VALUES (new.id, new.title, new.subtitle, new.description);END',
    'programs_fts_update',
  );
  late final $EpgImportsTable epgImports = $EpgImportsTable(this);
  late final $EpgChannelsTable epgChannels = $EpgChannelsTable(this);
  late final $EpgChannelsStagingTable epgChannelsStaging =
      $EpgChannelsStagingTable(this);
  late final $EpgProgramsStagingTable epgProgramsStaging =
      $EpgProgramsStagingTable(this);
  late final $EpgMappingsTable epgMappings = $EpgMappingsTable(this);
  late final $EpgMatchesTable epgMatches = $EpgMatchesTable(this);
  late final Index epgProgramsChannelStart = Index(
    'epg_programs_channel_start',
    'CREATE INDEX epg_programs_channel_start ON epg_programs (source_id, epg_channel_id, start_utc)',
  );
  late final Index epgProgramsStagingRun = Index(
    'epg_programs_staging_run',
    'CREATE INDEX epg_programs_staging_run ON epg_programs_staging (import_run)',
  );
  late final Index epgMatchesSource = Index(
    'epg_matches_source',
    'CREATE INDEX epg_matches_source ON epg_matches (source_id, xmltv_id)',
  );
  late final $SyncRunsTable syncRuns = $SyncRunsTable(this);
  late final $MovieDetailsTable movieDetails = $MovieDetailsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final Index categoriesSourceKind = Index(
    'categories_source_kind',
    'CREATE INDEX categories_source_kind ON categories (source_id, kind)',
  );
  late final Index channelsCategory = Index(
    'channels_category',
    'CREATE INDEX channels_category ON channels (category_id)',
  );
  late final Index moviesCategory = Index(
    'movies_category',
    'CREATE INDEX movies_category ON movies (category_id)',
  );
  late final Index moviesAdded = Index(
    'movies_added',
    'CREATE INDEX movies_added ON movies (source_id, added_at, id)',
  );
  late final Index moviesName = Index(
    'movies_name',
    'CREATE INDEX movies_name ON movies (source_id, name COLLATE NOCASE, id)',
  );
  late final Index moviesRating = Index(
    'movies_rating',
    'CREATE INDEX movies_rating ON movies (source_id, rating DESC, name COLLATE NOCASE, id)',
  );
  late final Index seriesCategory = Index(
    'series_category',
    'CREATE INDEX series_category ON series (category_id)',
  );
  late final $CastDevicesTable castDevices = $CastDevicesTable(this);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final SourcesDao sourcesDao = SourcesDao(this as AppDatabase);
  late final SyncRunsDao syncRunsDao = SyncRunsDao(this as AppDatabase);
  late final CategoriesDao categoriesDao = CategoriesDao(this as AppDatabase);
  late final ChannelsDao channelsDao = ChannelsDao(this as AppDatabase);
  late final FavoritesDao favoritesDao = FavoritesDao(this as AppDatabase);
  late final WatchHistoryDao watchHistoryDao = WatchHistoryDao(
    this as AppDatabase,
  );
  late final MoviesDao moviesDao = MoviesDao(this as AppDatabase);
  late final SeriesDao seriesDao = SeriesDao(this as AppDatabase);
  late final EpgDao epgDao = EpgDao(this as AppDatabase);
  late final CastDevicesDao castDevicesDao = CastDevicesDao(
    this as AppDatabase,
  );
  late final LibraryDao libraryDao = LibraryDao(this as AppDatabase);
  late final DownloadsDao downloadsDao = DownloadsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraryFolders,
    sources,
    libraryItems,
    libraryFts,
    libraryFtsInsert,
    libraryFtsDelete,
    libraryFtsUpdate,
    favoriteGroups,
    favorites,
    favoritesLocal,
    watchHistory,
    watchHistoryLocal,
    watchHistoryRecent,
    settings,
    downloads,
    libraryItemsHash,
    libraryItemsKindTitle,
    libraryItemsProvider,
    categories,
    channels,
    channelsFts,
    channelsFtsInsert,
    channelsFtsDelete,
    channelsFtsUpdate,
    movies,
    moviesFts,
    moviesFtsInsert,
    moviesFtsDelete,
    moviesFtsUpdate,
    series,
    seriesFts,
    seriesFtsInsert,
    seriesFtsDelete,
    seriesFtsUpdate,
    epgPrograms,
    programsFts,
    programsFtsInsert,
    programsFtsDelete,
    programsFtsUpdate,
    epgImports,
    epgChannels,
    epgChannelsStaging,
    epgProgramsStaging,
    epgMappings,
    epgMatches,
    epgProgramsChannelStart,
    epgProgramsStagingRun,
    epgMatchesSource,
    syncRuns,
    movieDetails,
    episodes,
    categoriesSourceKind,
    channelsCategory,
    moviesCategory,
    moviesAdded,
    moviesName,
    moviesRating,
    seriesCategory,
    castDevices,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_items',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('library_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('library_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_items',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('library_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorite_groups', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorites', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'favorite_groups',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorites', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('watch_history', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('downloads', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'library_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('downloads', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('categories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('channels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('channels', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'channels',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('channels_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'channels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('channels_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'channels',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('channels_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('movies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('movies', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'movies',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('movies_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'movies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('movies_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'movies',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('movies_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'series',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('series_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'series',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'series',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('series_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_programs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'epg_programs',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [TableUpdate('programs_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'epg_programs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('programs_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'epg_programs',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('programs_fts', kind: UpdateKind.insert)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_imports', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_channels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'epg_imports',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_channels_staging', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'epg_imports',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_programs_staging', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_mappings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'channels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_matches', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_matches', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sync_runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'movies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('movie_details', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'series',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('episodes', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$LibraryFoldersTableCreateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<int> id,
      required String path,
      required String label,
      Value<bool> isDownloadFolder,
      Value<bool> isAvailable,
      Value<DateTime?> lastScanAt,
      required DateTime addedAt,
    });
typedef $$LibraryFoldersTableUpdateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<String> label,
      Value<bool> isDownloadFolder,
      Value<bool> isAvailable,
      Value<DateTime?> lastScanAt,
      Value<DateTime> addedAt,
    });

final class $$LibraryFoldersTableReferences
    extends
        BaseReferences<_$AppDatabase, $LibraryFoldersTable, LibraryFolderRow> {
  $$LibraryFoldersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LibraryItemsTable, List<LibraryItemRow>>
  _libraryItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.libraryItems,
    aliasName: 'library_folders__id__library_items__folder_id',
  );

  $$LibraryItemsTableProcessedTableManager get libraryItemsRefs {
    final manager = $$LibraryItemsTableTableManager(
      $_db,
      $_db.libraryItems,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_libraryItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDownloadFolder => $composableBuilder(
    column: $table.isDownloadFolder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> libraryItemsRefs(
    Expression<bool> Function($$LibraryItemsTableFilterComposer f) f,
  ) {
    final $$LibraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableFilterComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDownloadFolder => $composableBuilder(
    column: $table.isDownloadFolder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get isDownloadFolder => $composableBuilder(
    column: $table.isDownloadFolder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  Expression<T> libraryItemsRefs<T extends Object>(
    Expression<T> Function($$LibraryItemsTableAnnotationComposer a) f,
  ) {
    final $$LibraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryFoldersTable,
          LibraryFolderRow,
          $$LibraryFoldersTableFilterComposer,
          $$LibraryFoldersTableOrderingComposer,
          $$LibraryFoldersTableAnnotationComposer,
          $$LibraryFoldersTableCreateCompanionBuilder,
          $$LibraryFoldersTableUpdateCompanionBuilder,
          (LibraryFolderRow, $$LibraryFoldersTableReferences),
          LibraryFolderRow,
          PrefetchHooks Function({bool libraryItemsRefs})
        > {
  $$LibraryFoldersTableTableManager(
    _$AppDatabase db,
    $LibraryFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> isDownloadFolder = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
                Value<DateTime?> lastScanAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => LibraryFoldersCompanion(
                id: id,
                path: path,
                label: label,
                isDownloadFolder: isDownloadFolder,
                isAvailable: isAvailable,
                lastScanAt: lastScanAt,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String label,
                Value<bool> isDownloadFolder = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
                Value<DateTime?> lastScanAt = const Value.absent(),
                required DateTime addedAt,
              }) => LibraryFoldersCompanion.insert(
                id: id,
                path: path,
                label: label,
                isDownloadFolder: isDownloadFolder,
                isAvailable: isAvailable,
                lastScanAt: lastScanAt,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryFoldersTable, LibraryFolderRow>(table),
                  $$LibraryFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (libraryItemsRefs) db.libraryItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (libraryItemsRefs)
                    await $_getPrefetchedData<
                      LibraryFolderRow,
                      $LibraryFoldersTable,
                      LibraryItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$LibraryFoldersTableReferences
                          ._libraryItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LibraryFoldersTableReferences(
                            db,
                            table,
                            p0,
                          ).libraryItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LibraryFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryFoldersTable,
      LibraryFolderRow,
      $$LibraryFoldersTableFilterComposer,
      $$LibraryFoldersTableOrderingComposer,
      $$LibraryFoldersTableAnnotationComposer,
      $$LibraryFoldersTableCreateCompanionBuilder,
      $$LibraryFoldersTableUpdateCompanionBuilder,
      (LibraryFolderRow, $$LibraryFoldersTableReferences),
      LibraryFolderRow,
      PrefetchHooks Function({bool libraryItemsRefs})
    >;
typedef $$SourcesTableCreateCompanionBuilder = SourcesCompanion Function({
  required String id,
  required SourceType type,
  required String name,
  required String url,
  Value<String?> username,
  Value<String?> credentialRef,
  Value<String?> epgUrl,
  Value<String?> userAgent,
  Value<LiveFormat> liveFormat,
  Value<int> epgOffsetMinutes,
  Value<int> refreshHours,
  Value<int?> maxConnectionsOverride,
  Value<String?> accountJson,
  Value<DateTime?> expiresAt,
  Value<DateTime?> lastSyncedAt,
  Value<int> sortOrder,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SourcesTableUpdateCompanionBuilder = SourcesCompanion Function({
  Value<String> id,
  Value<SourceType> type,
  Value<String> name,
  Value<String> url,
  Value<String?> username,
  Value<String?> credentialRef,
  Value<String?> epgUrl,
  Value<String?> userAgent,
  Value<LiveFormat> liveFormat,
  Value<int> epgOffsetMinutes,
  Value<int> refreshHours,
  Value<int?> maxConnectionsOverride,
  Value<String?> accountJson,
  Value<DateTime?> expiresAt,
  Value<DateTime?> lastSyncedAt,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$SourcesTableReferences
    extends BaseReferences<_$AppDatabase, $SourcesTable, SourceRow> {
  $$SourcesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LibraryItemsTable, List<LibraryItemRow>>
  _libraryItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.libraryItems,
    aliasName: 'sources__id__library_items__provider_source_id',
  );

  $$LibraryItemsTableProcessedTableManager get libraryItemsRefs {
    final manager = $$LibraryItemsTableTableManager($_db, $_db.libraryItems)
        .filter(
          (f) => f.providerSourceId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_libraryItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FavoriteGroupsTable, List<FavoriteGroupRow>>
  _favoriteGroupsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favoriteGroups,
    aliasName: 'sources__id__favorite_groups__source_id',
  );

  $$FavoriteGroupsTableProcessedTableManager get favoriteGroupsRefs {
    final manager = $$FavoriteGroupsTableTableManager(
      $_db,
      $_db.favoriteGroups,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoriteGroupsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FavoritesTable, List<FavoriteRow>>
  _favoritesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favorites,
    aliasName: 'sources__id__favorites__source_id',
  );

  $$FavoritesTableProcessedTableManager get favoritesRefs {
    final manager = $$FavoritesTableTableManager(
      $_db,
      $_db.favorites,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoritesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WatchHistoryTable, List<WatchHistoryRow>>
  _watchHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.watchHistory,
    aliasName: 'sources__id__watch_history__source_id',
  );

  $$WatchHistoryTableProcessedTableManager get watchHistoryRefs {
    final manager = $$WatchHistoryTableTableManager(
      $_db,
      $_db.watchHistory,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_watchHistoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DownloadsTable, List<DownloadRow>>
  _downloadsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloads,
    aliasName: 'sources__id__downloads__source_id',
  );

  $$DownloadsTableProcessedTableManager get downloadsRefs {
    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CategoriesTable, List<CategoryRow>>
  _categoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categories,
    aliasName: 'sources__id__categories__source_id',
  );

  $$CategoriesTableProcessedTableManager get categoriesRefs {
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_categoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChannelsTable, List<ChannelRow>>
  _channelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.channels,
    aliasName: 'sources__id__channels__source_id',
  );

  $$ChannelsTableProcessedTableManager get channelsRefs {
    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_channelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MoviesTable, List<MovieRow>> _moviesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.movies,
    aliasName: 'sources__id__movies__source_id',
  );

  $$MoviesTableProcessedTableManager get moviesRefs {
    final manager = $$MoviesTableTableManager(
      $_db,
      $_db.movies,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_moviesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SeriesTable, List<SeriesRow>> _seriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.series,
    aliasName: 'sources__id__series__source_id',
  );

  $$SeriesTableProcessedTableManager get seriesRefs {
    final manager = $$SeriesTableTableManager(
      $_db,
      $_db.series,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpgProgramsTable, List<EpgProgramRow>>
  _epgProgramsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgPrograms,
    aliasName: 'sources__id__epg_programs__source_id',
  );

  $$EpgProgramsTableProcessedTableManager get epgProgramsRefs {
    final manager = $$EpgProgramsTableTableManager(
      $_db,
      $_db.epgPrograms,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgProgramsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpgImportsTable, List<EpgImportRow>>
  _epgImportsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgImports,
    aliasName: 'sources__id__epg_imports__source_id',
  );

  $$EpgImportsTableProcessedTableManager get epgImportsRefs {
    final manager = $$EpgImportsTableTableManager(
      $_db,
      $_db.epgImports,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgImportsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpgChannelsTable, List<EpgChannelRow>>
  _epgChannelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgChannels,
    aliasName: 'sources__id__epg_channels__source_id',
  );

  $$EpgChannelsTableProcessedTableManager get epgChannelsRefs {
    final manager = $$EpgChannelsTableTableManager(
      $_db,
      $_db.epgChannels,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgChannelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpgMappingsTable, List<EpgMappingRow>>
  _epgMappingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgMappings,
    aliasName: 'sources__id__epg_mappings__source_id',
  );

  $$EpgMappingsTableProcessedTableManager get epgMappingsRefs {
    final manager = $$EpgMappingsTableTableManager(
      $_db,
      $_db.epgMappings,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgMappingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpgMatchesTable, List<EpgMatchRow>>
  _epgMatchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgMatches,
    aliasName: 'sources__id__epg_matches__source_id',
  );

  $$EpgMatchesTableProcessedTableManager get epgMatchesRefs {
    final manager = $$EpgMatchesTableTableManager(
      $_db,
      $_db.epgMatches,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgMatchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SyncRunsTable, List<SyncRunRow>>
  _syncRunsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.syncRuns,
    aliasName: 'sources__id__sync_runs__source_id',
  );

  $$SyncRunsTableProcessedTableManager get syncRunsRefs {
    final manager = $$SyncRunsTableTableManager(
      $_db,
      $_db.syncRuns,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SourcesTableFilterComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<SourceType, SourceType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgUrl => $composableBuilder(
    column: $table.epgUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userAgent => $composableBuilder(
    column: $table.userAgent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LiveFormat, LiveFormat, String>
  get liveFormat => $composableBuilder(
    column: $table.liveFormat,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get epgOffsetMinutes => $composableBuilder(
    column: $table.epgOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get refreshHours => $composableBuilder(
    column: $table.refreshHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxConnectionsOverride => $composableBuilder(
    column: $table.maxConnectionsOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountJson => $composableBuilder(
    column: $table.accountJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  Expression<bool> libraryItemsRefs(
    Expression<bool> Function($$LibraryItemsTableFilterComposer f) f,
  ) {
    final $$LibraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.providerSourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableFilterComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoriteGroupsRefs(
    Expression<bool> Function($$FavoriteGroupsTableFilterComposer f) f,
  ) {
    final $$FavoriteGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteGroups,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteGroupsTableFilterComposer(
            $db: $db,
            $table: $db.favoriteGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoritesRefs(
    Expression<bool> Function($$FavoritesTableFilterComposer f) f,
  ) {
    final $$FavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableFilterComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> watchHistoryRefs(
    Expression<bool> Function($$WatchHistoryTableFilterComposer f) f,
  ) {
    final $$WatchHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchHistory,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchHistoryTableFilterComposer(
            $db: $db,
            $table: $db.watchHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadsRefs(
    Expression<bool> Function($$DownloadsTableFilterComposer f) f,
  ) {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> categoriesRefs(
    Expression<bool> Function($$CategoriesTableFilterComposer f) f,
  ) {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> channelsRefs(
    Expression<bool> Function($$ChannelsTableFilterComposer f) f,
  ) {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> moviesRefs(
    Expression<bool> Function($$MoviesTableFilterComposer f) f,
  ) {
    final $$MoviesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableFilterComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> seriesRefs(
    Expression<bool> Function($$SeriesTableFilterComposer f) f,
  ) {
    final $$SeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableFilterComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgProgramsRefs(
    Expression<bool> Function($$EpgProgramsTableFilterComposer f) f,
  ) {
    final $$EpgProgramsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgPrograms,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgProgramsTableFilterComposer(
            $db: $db,
            $table: $db.epgPrograms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgImportsRefs(
    Expression<bool> Function($$EpgImportsTableFilterComposer f) f,
  ) {
    final $$EpgImportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgImports,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgImportsTableFilterComposer(
            $db: $db,
            $table: $db.epgImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgChannelsRefs(
    Expression<bool> Function($$EpgChannelsTableFilterComposer f) f,
  ) {
    final $$EpgChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgChannels,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgChannelsTableFilterComposer(
            $db: $db,
            $table: $db.epgChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgMappingsRefs(
    Expression<bool> Function($$EpgMappingsTableFilterComposer f) f,
  ) {
    final $$EpgMappingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMappings,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMappingsTableFilterComposer(
            $db: $db,
            $table: $db.epgMappings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgMatchesRefs(
    Expression<bool> Function($$EpgMatchesTableFilterComposer f) f,
  ) {
    final $$EpgMatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMatches,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMatchesTableFilterComposer(
            $db: $db,
            $table: $db.epgMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncRunsRefs(
    Expression<bool> Function($$SyncRunsTableFilterComposer f) f,
  ) {
    final $$SyncRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncRuns,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncRunsTableFilterComposer(
            $db: $db,
            $table: $db.syncRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgUrl => $composableBuilder(
    column: $table.epgUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userAgent => $composableBuilder(
    column: $table.userAgent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get liveFormat => $composableBuilder(
    column: $table.liveFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epgOffsetMinutes => $composableBuilder(
    column: $table.epgOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refreshHours => $composableBuilder(
    column: $table.refreshHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxConnectionsOverride => $composableBuilder(
    column: $table.maxConnectionsOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountJson => $composableBuilder(
    column: $table.accountJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

class $$SourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SourceType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get epgUrl =>
      $composableBuilder(column: $table.epgUrl, builder: (column) => column);

  GeneratedColumn<String> get userAgent =>
      $composableBuilder(column: $table.userAgent, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LiveFormat, String> get liveFormat =>
      $composableBuilder(
        column: $table.liveFormat,
        builder: (column) => column,
      );

  GeneratedColumn<int> get epgOffsetMinutes => $composableBuilder(
    column: $table.epgOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get refreshHours => $composableBuilder(
    column: $table.refreshHours,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxConnectionsOverride => $composableBuilder(
    column: $table.maxConnectionsOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountJson => $composableBuilder(
    column: $table.accountJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> libraryItemsRefs<T extends Object>(
    Expression<T> Function($$LibraryItemsTableAnnotationComposer a) f,
  ) {
    final $$LibraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.providerSourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> favoriteGroupsRefs<T extends Object>(
    Expression<T> Function($$FavoriteGroupsTableAnnotationComposer a) f,
  ) {
    final $$FavoriteGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteGroups,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> favoritesRefs<T extends Object>(
    Expression<T> Function($$FavoritesTableAnnotationComposer a) f,
  ) {
    final $$FavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> watchHistoryRefs<T extends Object>(
    Expression<T> Function($$WatchHistoryTableAnnotationComposer a) f,
  ) {
    final $$WatchHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchHistory,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.watchHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> downloadsRefs<T extends Object>(
    Expression<T> Function($$DownloadsTableAnnotationComposer a) f,
  ) {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> categoriesRefs<T extends Object>(
    Expression<T> Function($$CategoriesTableAnnotationComposer a) f,
  ) {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> channelsRefs<T extends Object>(
    Expression<T> Function($$ChannelsTableAnnotationComposer a) f,
  ) {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> moviesRefs<T extends Object>(
    Expression<T> Function($$MoviesTableAnnotationComposer a) f,
  ) {
    final $$MoviesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableAnnotationComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> seriesRefs<T extends Object>(
    Expression<T> Function($$SeriesTableAnnotationComposer a) f,
  ) {
    final $$SeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> epgProgramsRefs<T extends Object>(
    Expression<T> Function($$EpgProgramsTableAnnotationComposer a) f,
  ) {
    final $$EpgProgramsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgPrograms,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgProgramsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgPrograms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> epgImportsRefs<T extends Object>(
    Expression<T> Function($$EpgImportsTableAnnotationComposer a) f,
  ) {
    final $$EpgImportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgImports,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgImportsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> epgChannelsRefs<T extends Object>(
    Expression<T> Function($$EpgChannelsTableAnnotationComposer a) f,
  ) {
    final $$EpgChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgChannels,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> epgMappingsRefs<T extends Object>(
    Expression<T> Function($$EpgMappingsTableAnnotationComposer a) f,
  ) {
    final $$EpgMappingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMappings,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMappingsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgMappings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> epgMatchesRefs<T extends Object>(
    Expression<T> Function($$EpgMatchesTableAnnotationComposer a) f,
  ) {
    final $$EpgMatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMatches,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.epgMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncRunsRefs<T extends Object>(
    Expression<T> Function($$SyncRunsTableAnnotationComposer a) f,
  ) {
    final $$SyncRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncRuns,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.syncRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourcesTable,
          SourceRow,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (SourceRow, $$SourcesTableReferences),
          SourceRow,
          PrefetchHooks Function({
            bool libraryItemsRefs,
            bool favoriteGroupsRefs,
            bool favoritesRefs,
            bool watchHistoryRefs,
            bool downloadsRefs,
            bool categoriesRefs,
            bool channelsRefs,
            bool moviesRefs,
            bool seriesRefs,
            bool epgProgramsRefs,
            bool epgImportsRefs,
            bool epgChannelsRefs,
            bool epgMappingsRefs,
            bool epgMatchesRefs,
            bool syncRunsRefs,
          })
        > {
  $$SourcesTableTableManager(_$AppDatabase db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<SourceType> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String?> epgUrl = const Value.absent(),
                Value<String?> userAgent = const Value.absent(),
                Value<LiveFormat> liveFormat = const Value.absent(),
                Value<int> epgOffsetMinutes = const Value.absent(),
                Value<int> refreshHours = const Value.absent(),
                Value<int?> maxConnectionsOverride = const Value.absent(),
                Value<String?> accountJson = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                type: type,
                name: name,
                url: url,
                username: username,
                credentialRef: credentialRef,
                epgUrl: epgUrl,
                userAgent: userAgent,
                liveFormat: liveFormat,
                epgOffsetMinutes: epgOffsetMinutes,
                refreshHours: refreshHours,
                maxConnectionsOverride: maxConnectionsOverride,
                accountJson: accountJson,
                expiresAt: expiresAt,
                lastSyncedAt: lastSyncedAt,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required SourceType type,
                required String name,
                required String url,
                Value<String?> username = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String?> epgUrl = const Value.absent(),
                Value<String?> userAgent = const Value.absent(),
                Value<LiveFormat> liveFormat = const Value.absent(),
                Value<int> epgOffsetMinutes = const Value.absent(),
                Value<int> refreshHours = const Value.absent(),
                Value<int?> maxConnectionsOverride = const Value.absent(),
                Value<String?> accountJson = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                type: type,
                name: name,
                url: url,
                username: username,
                credentialRef: credentialRef,
                epgUrl: epgUrl,
                userAgent: userAgent,
                liveFormat: liveFormat,
                epgOffsetMinutes: epgOffsetMinutes,
                refreshHours: refreshHours,
                maxConnectionsOverride: maxConnectionsOverride,
                accountJson: accountJson,
                expiresAt: expiresAt,
                lastSyncedAt: lastSyncedAt,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourcesTable, SourceRow>(table),
                  $$SourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                libraryItemsRefs = false,
                favoriteGroupsRefs = false,
                favoritesRefs = false,
                watchHistoryRefs = false,
                downloadsRefs = false,
                categoriesRefs = false,
                channelsRefs = false,
                moviesRefs = false,
                seriesRefs = false,
                epgProgramsRefs = false,
                epgImportsRefs = false,
                epgChannelsRefs = false,
                epgMappingsRefs = false,
                epgMatchesRefs = false,
                syncRunsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (libraryItemsRefs) db.libraryItems,
                    if (favoriteGroupsRefs) db.favoriteGroups,
                    if (favoritesRefs) db.favorites,
                    if (watchHistoryRefs) db.watchHistory,
                    if (downloadsRefs) db.downloads,
                    if (categoriesRefs) db.categories,
                    if (channelsRefs) db.channels,
                    if (moviesRefs) db.movies,
                    if (seriesRefs) db.series,
                    if (epgProgramsRefs) db.epgPrograms,
                    if (epgImportsRefs) db.epgImports,
                    if (epgChannelsRefs) db.epgChannels,
                    if (epgMappingsRefs) db.epgMappings,
                    if (epgMatchesRefs) db.epgMatches,
                    if (syncRunsRefs) db.syncRuns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (libraryItemsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          LibraryItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._libraryItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).libraryItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.providerSourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (favoriteGroupsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          FavoriteGroupRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._favoriteGroupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).favoriteGroupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (favoritesRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          FavoriteRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._favoritesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).favoritesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (watchHistoryRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          WatchHistoryRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._watchHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).watchHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (downloadsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          DownloadRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._downloadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (categoriesRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          CategoryRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._categoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).categoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (channelsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          ChannelRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._channelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).channelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (moviesRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          MovieRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._moviesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).moviesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (seriesRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          SeriesRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._seriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgProgramsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          EpgProgramRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._epgProgramsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).epgProgramsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgImportsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          EpgImportRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._epgImportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).epgImportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgChannelsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          EpgChannelRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._epgChannelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).epgChannelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgMappingsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          EpgMappingRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._epgMappingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).epgMappingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgMatchesRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          EpgMatchRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._epgMatchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).epgMatchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (syncRunsRefs)
                        await $_getPrefetchedData<
                          SourceRow,
                          $SourcesTable,
                          SyncRunRow
                        >(
                          currentTable: table,
                          referencedTable: $$SourcesTableReferences
                              ._syncRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).syncRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourcesTable,
      SourceRow,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (SourceRow, $$SourcesTableReferences),
      SourceRow,
      PrefetchHooks Function({
        bool libraryItemsRefs,
        bool favoriteGroupsRefs,
        bool favoritesRefs,
        bool watchHistoryRefs,
        bool downloadsRefs,
        bool categoriesRefs,
        bool channelsRefs,
        bool moviesRefs,
        bool seriesRefs,
        bool epgProgramsRefs,
        bool epgImportsRefs,
        bool epgChannelsRefs,
        bool epgMappingsRefs,
        bool epgMatchesRefs,
        bool syncRunsRefs,
      })
    >;
typedef $$LibraryItemsTableCreateCompanionBuilder =
    LibraryItemsCompanion Function({
      Value<int> id,
      required int folderId,
      required String relPath,
      required int sizeBytes,
      required int mtime,
      required String quickHash,
      required LibraryKind kind,
      required String title,
      Value<int?> year,
      Value<String?> showTitle,
      Value<int?> season,
      Value<int?> episode,
      Value<int?> episodeEnd,
      Value<int?> durationMs,
      Value<String?> probeJson,
      Value<String?> thumbnailPath,
      Value<String?> artworkPath,
      Value<String?> subtitlesJson,
      Value<String?> userEditsJson,
      Value<String?> detailsJson,
      Value<String?> providerSourceId,
      Value<VodType?> providerItemType,
      Value<String?> providerRemoteKey,
      Value<String?> providerSeriesKey,
      Value<bool> isHidden,
      Value<DateTime?> unavailableSince,
      required DateTime addedAt,
    });
typedef $$LibraryItemsTableUpdateCompanionBuilder =
    LibraryItemsCompanion Function({
      Value<int> id,
      Value<int> folderId,
      Value<String> relPath,
      Value<int> sizeBytes,
      Value<int> mtime,
      Value<String> quickHash,
      Value<LibraryKind> kind,
      Value<String> title,
      Value<int?> year,
      Value<String?> showTitle,
      Value<int?> season,
      Value<int?> episode,
      Value<int?> episodeEnd,
      Value<int?> durationMs,
      Value<String?> probeJson,
      Value<String?> thumbnailPath,
      Value<String?> artworkPath,
      Value<String?> subtitlesJson,
      Value<String?> userEditsJson,
      Value<String?> detailsJson,
      Value<String?> providerSourceId,
      Value<VodType?> providerItemType,
      Value<String?> providerRemoteKey,
      Value<String?> providerSeriesKey,
      Value<bool> isHidden,
      Value<DateTime?> unavailableSince,
      Value<DateTime> addedAt,
    });

final class $$LibraryItemsTableReferences
    extends BaseReferences<_$AppDatabase, $LibraryItemsTable, LibraryItemRow> {
  $$LibraryItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibraryFoldersTable _folderIdTable(_$AppDatabase db) => db
      .libraryFolders
      .createAlias('library_items__folder_id__library_folders__id');

  $$LibraryFoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<int>('folder_id')!;

    final manager = $$LibraryFoldersTableTableManager(
      $_db,
      $_db.libraryFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourcesTable _providerSourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('library_items__provider_source_id__sources__id');

  $$SourcesTableProcessedTableManager? get providerSourceId {
    final $_column = $_itemColumn<String>('provider_source_id');
    if ($_column == null) return null;
    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_providerSourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DownloadsTable, List<DownloadRow>>
  _downloadsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloads,
    aliasName: 'library_items__id__downloads__library_item_id',
  );

  $$DownloadsTableProcessedTableManager get downloadsRefs {
    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.libraryItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibraryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableFilterComposer({
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

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quickHash => $composableBuilder(
    column: $table.quickHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LibraryKind, LibraryKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get showTitle => $composableBuilder(
    column: $table.showTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeEnd => $composableBuilder(
    column: $table.episodeEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get probeJson => $composableBuilder(
    column: $table.probeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitlesJson => $composableBuilder(
    column: $table.subtitlesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userEditsJson => $composableBuilder(
    column: $table.userEditsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<VodType?, VodType, String>
  get providerItemType => $composableBuilder(
    column: $table.providerItemType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get providerRemoteKey => $composableBuilder(
    column: $table.providerRemoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerSeriesKey => $composableBuilder(
    column: $table.providerSeriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get unavailableSince => $composableBuilder(
    column: $table.unavailableSince,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibraryFoldersTableFilterComposer get folderId {
    final $$LibraryFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableFilterComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableFilterComposer get providerSourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> downloadsRefs(
    Expression<bool> Function($$DownloadsTableFilterComposer f) f,
  ) {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.libraryItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableOrderingComposer({
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

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quickHash => $composableBuilder(
    column: $table.quickHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get showTitle => $composableBuilder(
    column: $table.showTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeEnd => $composableBuilder(
    column: $table.episodeEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get probeJson => $composableBuilder(
    column: $table.probeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitlesJson => $composableBuilder(
    column: $table.subtitlesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userEditsJson => $composableBuilder(
    column: $table.userEditsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerItemType => $composableBuilder(
    column: $table.providerItemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerRemoteKey => $composableBuilder(
    column: $table.providerRemoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerSeriesKey => $composableBuilder(
    column: $table.providerSeriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get unavailableSince => $composableBuilder(
    column: $table.unavailableSince,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibraryFoldersTableOrderingComposer get folderId {
    final $$LibraryFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableOrderingComposer get providerSourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LibraryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryItemsTable> {
  $$LibraryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<String> get quickHash =>
      $composableBuilder(column: $table.quickHash, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LibraryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get showTitle =>
      $composableBuilder(column: $table.showTitle, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<int> get episodeEnd => $composableBuilder(
    column: $table.episodeEnd,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get probeJson =>
      $composableBuilder(column: $table.probeJson, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subtitlesJson => $composableBuilder(
    column: $table.subtitlesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userEditsJson => $composableBuilder(
    column: $table.userEditsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<VodType?, String> get providerItemType =>
      $composableBuilder(
        column: $table.providerItemType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get providerRemoteKey => $composableBuilder(
    column: $table.providerRemoteKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerSeriesKey => $composableBuilder(
    column: $table.providerSeriesKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<DateTime> get unavailableSince => $composableBuilder(
    column: $table.unavailableSince,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$LibraryFoldersTableAnnotationComposer get folderId {
    final $$LibraryFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.libraryFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableAnnotationComposer get providerSourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.providerSourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> downloadsRefs<T extends Object>(
    Expression<T> Function($$DownloadsTableAnnotationComposer a) f,
  ) {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.libraryItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibraryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryItemsTable,
          LibraryItemRow,
          $$LibraryItemsTableFilterComposer,
          $$LibraryItemsTableOrderingComposer,
          $$LibraryItemsTableAnnotationComposer,
          $$LibraryItemsTableCreateCompanionBuilder,
          $$LibraryItemsTableUpdateCompanionBuilder,
          (LibraryItemRow, $$LibraryItemsTableReferences),
          LibraryItemRow,
          PrefetchHooks Function({
            bool folderId,
            bool providerSourceId,
            bool downloadsRefs,
          })
        > {
  $$LibraryItemsTableTableManager(_$AppDatabase db, $LibraryItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> folderId = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<String> quickHash = const Value.absent(),
                Value<LibraryKind> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> showTitle = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<int?> episodeEnd = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> probeJson = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> artworkPath = const Value.absent(),
                Value<String?> subtitlesJson = const Value.absent(),
                Value<String?> userEditsJson = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<String?> providerSourceId = const Value.absent(),
                Value<VodType?> providerItemType = const Value.absent(),
                Value<String?> providerRemoteKey = const Value.absent(),
                Value<String?> providerSeriesKey = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime?> unavailableSince = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => LibraryItemsCompanion(
                id: id,
                folderId: folderId,
                relPath: relPath,
                sizeBytes: sizeBytes,
                mtime: mtime,
                quickHash: quickHash,
                kind: kind,
                title: title,
                year: year,
                showTitle: showTitle,
                season: season,
                episode: episode,
                episodeEnd: episodeEnd,
                durationMs: durationMs,
                probeJson: probeJson,
                thumbnailPath: thumbnailPath,
                artworkPath: artworkPath,
                subtitlesJson: subtitlesJson,
                userEditsJson: userEditsJson,
                detailsJson: detailsJson,
                providerSourceId: providerSourceId,
                providerItemType: providerItemType,
                providerRemoteKey: providerRemoteKey,
                providerSeriesKey: providerSeriesKey,
                isHidden: isHidden,
                unavailableSince: unavailableSince,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int folderId,
                required String relPath,
                required int sizeBytes,
                required int mtime,
                required String quickHash,
                required LibraryKind kind,
                required String title,
                Value<int?> year = const Value.absent(),
                Value<String?> showTitle = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<int?> episodeEnd = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> probeJson = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> artworkPath = const Value.absent(),
                Value<String?> subtitlesJson = const Value.absent(),
                Value<String?> userEditsJson = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<String?> providerSourceId = const Value.absent(),
                Value<VodType?> providerItemType = const Value.absent(),
                Value<String?> providerRemoteKey = const Value.absent(),
                Value<String?> providerSeriesKey = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime?> unavailableSince = const Value.absent(),
                required DateTime addedAt,
              }) => LibraryItemsCompanion.insert(
                id: id,
                folderId: folderId,
                relPath: relPath,
                sizeBytes: sizeBytes,
                mtime: mtime,
                quickHash: quickHash,
                kind: kind,
                title: title,
                year: year,
                showTitle: showTitle,
                season: season,
                episode: episode,
                episodeEnd: episodeEnd,
                durationMs: durationMs,
                probeJson: probeJson,
                thumbnailPath: thumbnailPath,
                artworkPath: artworkPath,
                subtitlesJson: subtitlesJson,
                userEditsJson: userEditsJson,
                detailsJson: detailsJson,
                providerSourceId: providerSourceId,
                providerItemType: providerItemType,
                providerRemoteKey: providerRemoteKey,
                providerSeriesKey: providerSeriesKey,
                isHidden: isHidden,
                unavailableSince: unavailableSince,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryItemsTable, LibraryItemRow>(table),
                  $$LibraryItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                folderId = false,
                providerSourceId = false,
                downloadsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (downloadsRefs) db.downloads],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (folderId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.folderId,
                            referencedTable: $$LibraryItemsTableReferences
                                ._folderIdTable(db),
                            referencedColumn: $$LibraryItemsTableReferences
                                ._folderIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (providerSourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.providerSourceId,
                            referencedTable: $$LibraryItemsTableReferences
                                ._providerSourceIdTable(db),
                            referencedColumn: $$LibraryItemsTableReferences
                                ._providerSourceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (downloadsRefs)
                        await $_getPrefetchedData<
                          LibraryItemRow,
                          $LibraryItemsTable,
                          DownloadRow
                        >(
                          currentTable: table,
                          referencedTable: $$LibraryItemsTableReferences
                              ._downloadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibraryItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.libraryItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LibraryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryItemsTable,
      LibraryItemRow,
      $$LibraryItemsTableFilterComposer,
      $$LibraryItemsTableOrderingComposer,
      $$LibraryItemsTableAnnotationComposer,
      $$LibraryItemsTableCreateCompanionBuilder,
      $$LibraryItemsTableUpdateCompanionBuilder,
      (LibraryItemRow, $$LibraryItemsTableReferences),
      LibraryItemRow,
      PrefetchHooks Function({
        bool folderId,
        bool providerSourceId,
        bool downloadsRefs,
      })
    >;
typedef $LibraryFtsCreateCompanionBuilder = LibraryFtsCompanion Function({
  required String title,
  required String showTitle,
  Value<int> rowid,
});
typedef $LibraryFtsUpdateCompanionBuilder = LibraryFtsCompanion Function({
  Value<String> title,
  Value<String> showTitle,
  Value<int> rowid,
});

class $LibraryFtsFilterComposer extends Composer<_$AppDatabase, LibraryFts> {
  $LibraryFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get showTitle => $composableBuilder(
    column: $table.showTitle,
    builder: (column) => ColumnFilters(column),
  );
}

class $LibraryFtsOrderingComposer extends Composer<_$AppDatabase, LibraryFts> {
  $LibraryFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get showTitle => $composableBuilder(
    column: $table.showTitle,
    builder: (column) => ColumnOrderings(column),
  );
}

class $LibraryFtsAnnotationComposer
    extends Composer<_$AppDatabase, LibraryFts> {
  $LibraryFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get showTitle =>
      $composableBuilder(column: $table.showTitle, builder: (column) => column);
}

class $LibraryFtsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          LibraryFts,
          LibraryFt,
          $LibraryFtsFilterComposer,
          $LibraryFtsOrderingComposer,
          $LibraryFtsAnnotationComposer,
          $LibraryFtsCreateCompanionBuilder,
          $LibraryFtsUpdateCompanionBuilder,
          (LibraryFt, BaseReferences<_$AppDatabase, LibraryFts, LibraryFt>),
          LibraryFt,
          PrefetchHooks Function()
        > {
  $LibraryFtsTableManager(_$AppDatabase db, LibraryFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LibraryFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LibraryFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LibraryFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> title = const Value.absent(),
                Value<String> showTitle = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryFtsCompanion(
                title: title,
                showTitle: showTitle,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String title,
                required String showTitle,
                Value<int> rowid = const Value.absent(),
              }) => LibraryFtsCompanion.insert(
                title: title,
                showTitle: showTitle,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<LibraryFts, LibraryFt>(table),
                  BaseReferences<_$AppDatabase, LibraryFts, LibraryFt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $LibraryFtsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      LibraryFts,
      LibraryFt,
      $LibraryFtsFilterComposer,
      $LibraryFtsOrderingComposer,
      $LibraryFtsAnnotationComposer,
      $LibraryFtsCreateCompanionBuilder,
      $LibraryFtsUpdateCompanionBuilder,
      (LibraryFt, BaseReferences<_$AppDatabase, LibraryFts, LibraryFt>),
      LibraryFt,
      PrefetchHooks Function()
    >;
typedef $$FavoriteGroupsTableCreateCompanionBuilder =
    FavoriteGroupsCompanion Function({
      Value<int> id,
      required String sourceId,
      required String name,
      Value<int> sortOrder,
      Value<bool> collapsed,
    });
typedef $$FavoriteGroupsTableUpdateCompanionBuilder =
    FavoriteGroupsCompanion Function({
      Value<int> id,
      Value<String> sourceId,
      Value<String> name,
      Value<int> sortOrder,
      Value<bool> collapsed,
    });

final class $$FavoriteGroupsTableReferences
    extends
        BaseReferences<_$AppDatabase, $FavoriteGroupsTable, FavoriteGroupRow> {
  $$FavoriteGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('favorite_groups__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FavoritesTable, List<FavoriteRow>>
  _favoritesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favorites,
    aliasName: 'favorite_groups__id__favorites__group_id',
  );

  $$FavoritesTableProcessedTableManager get favoritesRefs {
    final manager = $$FavoritesTableTableManager(
      $_db,
      $_db.favorites,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoritesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FavoriteGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteGroupsTable> {
  $$FavoriteGroupsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> favoritesRefs(
    Expression<bool> Function($$FavoritesTableFilterComposer f) f,
  ) {
    final $$FavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableFilterComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoriteGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteGroupsTable> {
  $$FavoriteGroupsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collapsed => $composableBuilder(
    column: $table.collapsed,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteGroupsTable> {
  $$FavoriteGroupsTableAnnotationComposer({
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get collapsed =>
      $composableBuilder(column: $table.collapsed, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> favoritesRefs<T extends Object>(
    Expression<T> Function($$FavoritesTableAnnotationComposer a) f,
  ) {
    final $$FavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoriteGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteGroupsTable,
          FavoriteGroupRow,
          $$FavoriteGroupsTableFilterComposer,
          $$FavoriteGroupsTableOrderingComposer,
          $$FavoriteGroupsTableAnnotationComposer,
          $$FavoriteGroupsTableCreateCompanionBuilder,
          $$FavoriteGroupsTableUpdateCompanionBuilder,
          (FavoriteGroupRow, $$FavoriteGroupsTableReferences),
          FavoriteGroupRow,
          PrefetchHooks Function({bool sourceId, bool favoritesRefs})
        > {
  $$FavoriteGroupsTableTableManager(
    _$AppDatabase db,
    $FavoriteGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
              }) => FavoriteGroupsCompanion(
                id: id,
                sourceId: sourceId,
                name: name,
                sortOrder: sortOrder,
                collapsed: collapsed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> collapsed = const Value.absent(),
              }) => FavoriteGroupsCompanion.insert(
                id: id,
                sourceId: sourceId,
                name: name,
                sortOrder: sortOrder,
                collapsed: collapsed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoriteGroupsTable, FavoriteGroupRow>(table),
                  $$FavoriteGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false, favoritesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (favoritesRefs) db.favorites],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$FavoriteGroupsTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$FavoriteGroupsTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (favoritesRefs)
                    await $_getPrefetchedData<
                      FavoriteGroupRow,
                      $FavoriteGroupsTable,
                      FavoriteRow
                    >(
                      currentTable: table,
                      referencedTable: $$FavoriteGroupsTableReferences
                          ._favoritesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FavoriteGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).favoritesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.groupId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FavoriteGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteGroupsTable,
      FavoriteGroupRow,
      $$FavoriteGroupsTableFilterComposer,
      $$FavoriteGroupsTableOrderingComposer,
      $$FavoriteGroupsTableAnnotationComposer,
      $$FavoriteGroupsTableCreateCompanionBuilder,
      $$FavoriteGroupsTableUpdateCompanionBuilder,
      (FavoriteGroupRow, $$FavoriteGroupsTableReferences),
      FavoriteGroupRow,
      PrefetchHooks Function({bool sourceId, bool favoritesRefs})
    >;
typedef $$FavoritesTableCreateCompanionBuilder = FavoritesCompanion Function({
  Value<int> id,
  required UserItemType itemType,
  Value<String?> sourceId,
  required String remoteKey,
  Value<int?> groupId,
  Value<int?> sortOrder,
  required DateTime addedAt,
});
typedef $$FavoritesTableUpdateCompanionBuilder = FavoritesCompanion Function({
  Value<int> id,
  Value<UserItemType> itemType,
  Value<String?> sourceId,
  Value<String> remoteKey,
  Value<int?> groupId,
  Value<int?> sortOrder,
  Value<DateTime> addedAt,
});

final class $$FavoritesTableReferences
    extends BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow> {
  $$FavoritesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('favorites__source_id__sources__id');

  $$SourcesTableProcessedTableManager? get sourceId {
    final $_column = $_itemColumn<String>('source_id');
    if ($_column == null) return null;
    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FavoriteGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.favoriteGroups.createAlias('favorites__group_id__favorite_groups__id');

  $$FavoriteGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<int>('group_id');
    if ($_column == null) return null;
    final manager = $$FavoriteGroupsTableTableManager(
      $_db,
      $_db.favoriteGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<UserItemType, UserItemType, String>
  get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FavoriteGroupsTableFilterComposer get groupId {
    final $$FavoriteGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.favoriteGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteGroupsTableFilterComposer(
            $db: $db,
            $table: $db.favoriteGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
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

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FavoriteGroupsTableOrderingComposer get groupId {
    final $$FavoriteGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.favoriteGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.favoriteGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<UserItemType, String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FavoriteGroupsTableAnnotationComposer get groupId {
    final $$FavoriteGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.favoriteGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          FavoriteRow,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (FavoriteRow, $$FavoritesTableReferences),
          FavoriteRow,
          PrefetchHooks Function({bool sourceId, bool groupId})
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<UserItemType> itemType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => FavoritesCompanion(
                id: id,
                itemType: itemType,
                sourceId: sourceId,
                remoteKey: remoteKey,
                groupId: groupId,
                sortOrder: sortOrder,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required UserItemType itemType,
                Value<String?> sourceId = const Value.absent(),
                required String remoteKey,
                Value<int?> groupId = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
                required DateTime addedAt,
              }) => FavoritesCompanion.insert(
                id: id,
                itemType: itemType,
                sourceId: sourceId,
                remoteKey: remoteKey,
                groupId: groupId,
                sortOrder: sortOrder,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoritesTable, FavoriteRow>(table),
                  $$FavoritesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false, groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$FavoritesTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$FavoritesTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$FavoritesTableReferences
                            ._groupIdTable(db),
                        referencedColumn: $$FavoritesTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      FavoriteRow,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (FavoriteRow, $$FavoritesTableReferences),
      FavoriteRow,
      PrefetchHooks Function({bool sourceId, bool groupId})
    >;
typedef $$WatchHistoryTableCreateCompanionBuilder =
    WatchHistoryCompanion Function({
      Value<int> id,
      required UserItemType itemType,
      Value<String?> sourceId,
      required String remoteKey,
      Value<int> positionMs,
      Value<int?> durationMs,
      Value<bool> completed,
      Value<String?> seriesKey,
      Value<bool> dismissed,
      required DateTime updatedAt,
    });
typedef $$WatchHistoryTableUpdateCompanionBuilder =
    WatchHistoryCompanion Function({
      Value<int> id,
      Value<UserItemType> itemType,
      Value<String?> sourceId,
      Value<String> remoteKey,
      Value<int> positionMs,
      Value<int?> durationMs,
      Value<bool> completed,
      Value<String?> seriesKey,
      Value<bool> dismissed,
      Value<DateTime> updatedAt,
    });

final class $$WatchHistoryTableReferences
    extends BaseReferences<_$AppDatabase, $WatchHistoryTable, WatchHistoryRow> {
  $$WatchHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('watch_history__source_id__sources__id');

  $$SourcesTableProcessedTableManager? get sourceId {
    final $_column = $_itemColumn<String>('source_id');
    if ($_column == null) return null;
    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WatchHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableFilterComposer({
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

  ColumnWithTypeConverterFilters<UserItemType, UserItemType, String>
  get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchHistoryTable> {
  $$WatchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<UserItemType, String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchHistoryTable,
          WatchHistoryRow,
          $$WatchHistoryTableFilterComposer,
          $$WatchHistoryTableOrderingComposer,
          $$WatchHistoryTableAnnotationComposer,
          $$WatchHistoryTableCreateCompanionBuilder,
          $$WatchHistoryTableUpdateCompanionBuilder,
          (WatchHistoryRow, $$WatchHistoryTableReferences),
          WatchHistoryRow,
          PrefetchHooks Function({bool sourceId})
        > {
  $$WatchHistoryTableTableManager(_$AppDatabase db, $WatchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<UserItemType> itemType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String?> seriesKey = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => WatchHistoryCompanion(
                id: id,
                itemType: itemType,
                sourceId: sourceId,
                remoteKey: remoteKey,
                positionMs: positionMs,
                durationMs: durationMs,
                completed: completed,
                seriesKey: seriesKey,
                dismissed: dismissed,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required UserItemType itemType,
                Value<String?> sourceId = const Value.absent(),
                required String remoteKey,
                Value<int> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String?> seriesKey = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                required DateTime updatedAt,
              }) => WatchHistoryCompanion.insert(
                id: id,
                itemType: itemType,
                sourceId: sourceId,
                remoteKey: remoteKey,
                positionMs: positionMs,
                durationMs: durationMs,
                completed: completed,
                seriesKey: seriesKey,
                dismissed: dismissed,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WatchHistoryTable, WatchHistoryRow>(table),
                  $$WatchHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$WatchHistoryTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$WatchHistoryTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WatchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchHistoryTable,
      WatchHistoryRow,
      $$WatchHistoryTableFilterComposer,
      $$WatchHistoryTableOrderingComposer,
      $$WatchHistoryTableAnnotationComposer,
      $$WatchHistoryTableCreateCompanionBuilder,
      $$WatchHistoryTableUpdateCompanionBuilder,
      (WatchHistoryRow, $$WatchHistoryTableReferences),
      WatchHistoryRow,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String valueJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> valueJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$DownloadsTableCreateCompanionBuilder = DownloadsCompanion Function({
  Value<int> id,
  required String sourceId,
  required VodType itemType,
  required String remoteKey,
  Value<String?> seriesRemoteKey,
  Value<int?> season,
  Value<int?> episode,
  required String title,
  Value<String?> showTitle,
  Value<int?> year,
  Value<String?> artworkUrl,
  required String targetPath,
  Value<int?> totalBytes,
  Value<int> downloadedBytes,
  Value<String?> etag,
  Value<String?> lastModified,
  required DownloadTaskState state,
  Value<DownloadProblem?> errorClass,
  Value<String?> errorDetail,
  Value<int> attempts,
  Value<int?> libraryItemId,
  required int sortOrder,
  required DateTime createdAt,
  Value<DateTime?> completedAt,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<int> id,
  Value<String> sourceId,
  Value<VodType> itemType,
  Value<String> remoteKey,
  Value<String?> seriesRemoteKey,
  Value<int?> season,
  Value<int?> episode,
  Value<String> title,
  Value<String?> showTitle,
  Value<int?> year,
  Value<String?> artworkUrl,
  Value<String> targetPath,
  Value<int?> totalBytes,
  Value<int> downloadedBytes,
  Value<String?> etag,
  Value<String?> lastModified,
  Value<DownloadTaskState> state,
  Value<DownloadProblem?> errorClass,
  Value<String?> errorDetail,
  Value<int> attempts,
  Value<int?> libraryItemId,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime?> completedAt,
});

final class $$DownloadsTableReferences
    extends BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow> {
  $$DownloadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('downloads__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LibraryItemsTable _libraryItemIdTable(_$AppDatabase db) => db
      .libraryItems
      .createAlias('downloads__library_item_id__library_items__id');

  $$LibraryItemsTableProcessedTableManager? get libraryItemId {
    final $_column = $_itemColumn<int>('library_item_id');
    if ($_column == null) return null;
    final manager = $$LibraryItemsTableTableManager(
      $_db,
      $_db.libraryItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<VodType, VodType, String> get itemType =>
      $composableBuilder(
        column: $table.itemType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesRemoteKey => $composableBuilder(
    column: $table.seriesRemoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get showTitle => $composableBuilder(
    column: $table.showTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadTaskState, DownloadTaskState, String>
  get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadProblem?, DownloadProblem, String>
  get errorClass => $composableBuilder(
    column: $table.errorClass,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryItemsTableFilterComposer get libraryItemId {
    final $$LibraryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryItemId,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableFilterComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
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

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesRemoteKey => $composableBuilder(
    column: $table.seriesRemoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get showTitle => $composableBuilder(
    column: $table.showTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorClass => $composableBuilder(
    column: $table.errorClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryItemsTableOrderingComposer get libraryItemId {
    final $$LibraryItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryItemId,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableOrderingComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<VodType, String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<String> get seriesRemoteKey => $composableBuilder(
    column: $table.seriesRemoteKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get showTitle =>
      $composableBuilder(column: $table.showTitle, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DownloadTaskState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadProblem?, String> get errorClass =>
      $composableBuilder(
        column: $table.errorClass,
        builder: (column) => column,
      );

  GeneratedColumn<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LibraryItemsTableAnnotationComposer get libraryItemId {
    final $$LibraryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryItemId,
      referencedTable: $db.libraryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibraryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.libraryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          DownloadRow,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (DownloadRow, $$DownloadsTableReferences),
          DownloadRow,
          PrefetchHooks Function({bool sourceId, bool libraryItemId})
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<VodType> itemType = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<String?> seriesRemoteKey = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> showTitle = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String> targetPath = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                Value<DownloadTaskState> state = const Value.absent(),
                Value<DownloadProblem?> errorClass = const Value.absent(),
                Value<String?> errorDetail = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> libraryItemId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                sourceId: sourceId,
                itemType: itemType,
                remoteKey: remoteKey,
                seriesRemoteKey: seriesRemoteKey,
                season: season,
                episode: episode,
                title: title,
                showTitle: showTitle,
                year: year,
                artworkUrl: artworkUrl,
                targetPath: targetPath,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                etag: etag,
                lastModified: lastModified,
                state: state,
                errorClass: errorClass,
                errorDetail: errorDetail,
                attempts: attempts,
                libraryItemId: libraryItemId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required VodType itemType,
                required String remoteKey,
                Value<String?> seriesRemoteKey = const Value.absent(),
                Value<int?> season = const Value.absent(),
                Value<int?> episode = const Value.absent(),
                required String title,
                Value<String?> showTitle = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                required String targetPath,
                Value<int?> totalBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> lastModified = const Value.absent(),
                required DownloadTaskState state,
                Value<DownloadProblem?> errorClass = const Value.absent(),
                Value<String?> errorDetail = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> libraryItemId = const Value.absent(),
                required int sortOrder,
                required DateTime createdAt,
                Value<DateTime?> completedAt = const Value.absent(),
              }) => DownloadsCompanion.insert(
                id: id,
                sourceId: sourceId,
                itemType: itemType,
                remoteKey: remoteKey,
                seriesRemoteKey: seriesRemoteKey,
                season: season,
                episode: episode,
                title: title,
                showTitle: showTitle,
                year: year,
                artworkUrl: artworkUrl,
                targetPath: targetPath,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                etag: etag,
                lastModified: lastModified,
                state: state,
                errorClass: errorClass,
                errorDetail: errorDetail,
                attempts: attempts,
                libraryItemId: libraryItemId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadsTable, DownloadRow>(table),
                  $$DownloadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false, libraryItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$DownloadsTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$DownloadsTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (libraryItemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.libraryItemId,
                        referencedTable: $$DownloadsTableReferences
                            ._libraryItemIdTable(db),
                        referencedColumn: $$DownloadsTableReferences
                            ._libraryItemIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      DownloadRow,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (DownloadRow, $$DownloadsTableReferences),
      DownloadRow,
      PrefetchHooks Function({bool sourceId, bool libraryItemId})
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String sourceId,
  required String remoteKey,
  Value<int> position,
  Value<int?> seenRun,
  Value<int> id,
  required CatalogueKind kind,
  required String name,
  Value<String?> displayName,
  Value<bool> isHidden,
  Value<int?> sortOrder,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> sourceId,
  Value<String> remoteKey,
  Value<int> position,
  Value<int?> seenRun,
  Value<int> id,
  Value<CatalogueKind> kind,
  Value<String> name,
  Value<String?> displayName,
  Value<bool> isHidden,
  Value<int?> sortOrder,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('categories__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ChannelsTable, List<ChannelRow>>
  _channelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.channels,
    aliasName: 'categories__id__channels__category_id',
  );

  $$ChannelsTableProcessedTableManager get channelsRefs {
    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_channelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MoviesTable, List<MovieRow>> _moviesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.movies,
    aliasName: 'categories__id__movies__category_id',
  );

  $$MoviesTableProcessedTableManager get moviesRefs {
    final manager = $$MoviesTableTableManager(
      $_db,
      $_db.movies,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_moviesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SeriesTable, List<SeriesRow>> _seriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.series,
    aliasName: 'categories__id__series__category_id',
  );

  $$SeriesTableProcessedTableManager get seriesRefs {
    final manager = $$SeriesTableTableManager(
      $_db,
      $_db.series,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CatalogueKind, CatalogueKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> channelsRefs(
    Expression<bool> Function($$ChannelsTableFilterComposer f) f,
  ) {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> moviesRefs(
    Expression<bool> Function($$MoviesTableFilterComposer f) f,
  ) {
    final $$MoviesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableFilterComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> seriesRefs(
    Expression<bool> Function($$SeriesTableFilterComposer f) f,
  ) {
    final $$SeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableFilterComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get seenRun =>
      $composableBuilder(column: $table.seenRun, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CatalogueKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> channelsRefs<T extends Object>(
    Expression<T> Function($$ChannelsTableAnnotationComposer a) f,
  ) {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> moviesRefs<T extends Object>(
    Expression<T> Function($$MoviesTableAnnotationComposer a) f,
  ) {
    final $$MoviesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableAnnotationComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> seriesRefs<T extends Object>(
    Expression<T> Function($$SeriesTableAnnotationComposer a) f,
  ) {
    final $$SeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (CategoryRow, $$CategoriesTableReferences),
          CategoryRow,
          PrefetchHooks Function({
            bool sourceId,
            bool channelsRefs,
            bool moviesRefs,
            bool seriesRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<CatalogueKind> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
              }) => CategoriesCompanion(
                sourceId: sourceId,
                remoteKey: remoteKey,
                position: position,
                seenRun: seenRun,
                id: id,
                kind: kind,
                name: name,
                displayName: displayName,
                isHidden: isHidden,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String remoteKey,
                Value<int> position = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
                Value<int> id = const Value.absent(),
                required CatalogueKind kind,
                required String name,
                Value<String?> displayName = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int?> sortOrder = const Value.absent(),
              }) => CategoriesCompanion.insert(
                sourceId: sourceId,
                remoteKey: remoteKey,
                position: position,
                seenRun: seenRun,
                id: id,
                kind: kind,
                name: name,
                displayName: displayName,
                isHidden: isHidden,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRow>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                channelsRefs = false,
                moviesRefs = false,
                seriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (channelsRefs) db.channels,
                    if (moviesRefs) db.movies,
                    if (seriesRefs) db.series,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$CategoriesTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$CategoriesTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (channelsRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          ChannelRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._channelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).channelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (moviesRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          MovieRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._moviesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).moviesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (seriesRefs)
                        await $_getPrefetchedData<
                          CategoryRow,
                          $CategoriesTable,
                          SeriesRow
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._seriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (CategoryRow, $$CategoriesTableReferences),
      CategoryRow,
      PrefetchHooks Function({
        bool sourceId,
        bool channelsRefs,
        bool moviesRefs,
        bool seriesRefs,
      })
    >;
typedef $$ChannelsTableCreateCompanionBuilder = ChannelsCompanion Function({
  required String sourceId,
  required String remoteKey,
  Value<int> position,
  Value<int?> seenRun,
  Value<int> id,
  Value<int?> categoryId,
  Value<int?> number,
  required String name,
  Value<String?> displayName,
  Value<String?> cleanName,
  Value<String?> quality,
  Value<String?> logoUrl,
  Value<String?> epgKey,
  Value<int> archiveDays,
  Value<String?> streamUrl,
  Value<String?> extrasJson,
  Value<bool> isHidden,
  Value<DateTime?> addedAt,
});
typedef $$ChannelsTableUpdateCompanionBuilder = ChannelsCompanion Function({
  Value<String> sourceId,
  Value<String> remoteKey,
  Value<int> position,
  Value<int?> seenRun,
  Value<int> id,
  Value<int?> categoryId,
  Value<int?> number,
  Value<String> name,
  Value<String?> displayName,
  Value<String?> cleanName,
  Value<String?> quality,
  Value<String?> logoUrl,
  Value<String?> epgKey,
  Value<int> archiveDays,
  Value<String?> streamUrl,
  Value<String?> extrasJson,
  Value<bool> isHidden,
  Value<DateTime?> addedAt,
});

final class $$ChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $ChannelsTable, ChannelRow> {
  $$ChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('channels__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('channels__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EpgMatchesTable, List<EpgMatchRow>>
  _epgMatchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgMatches,
    aliasName: 'channels__id__epg_matches__channel_id',
  );

  $$EpgMatchesTableProcessedTableManager get epgMatchesRefs {
    final manager = $$EpgMatchesTableTableManager(
      $_db,
      $_db.epgMatches,
    ).filter((f) => f.channelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgMatchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleanName => $composableBuilder(
    column: $table.cleanName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgKey => $composableBuilder(
    column: $table.epgKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> epgMatchesRefs(
    Expression<bool> Function($$EpgMatchesTableFilterComposer f) f,
  ) {
    final $$EpgMatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMatches,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMatchesTableFilterComposer(
            $db: $db,
            $table: $db.epgMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleanName => $composableBuilder(
    column: $table.cleanName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgKey => $composableBuilder(
    column: $table.epgKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get seenRun =>
      $composableBuilder(column: $table.seenRun, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cleanName =>
      $composableBuilder(column: $table.cleanName, builder: (column) => column);

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get epgKey =>
      $composableBuilder(column: $table.epgKey, builder: (column) => column);

  GeneratedColumn<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> epgMatchesRefs<T extends Object>(
    Expression<T> Function($$EpgMatchesTableAnnotationComposer a) f,
  ) {
    final $$EpgMatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgMatches,
      getReferencedColumn: (t) => t.channelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgMatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.epgMatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChannelsTable,
          ChannelRow,
          $$ChannelsTableFilterComposer,
          $$ChannelsTableOrderingComposer,
          $$ChannelsTableAnnotationComposer,
          $$ChannelsTableCreateCompanionBuilder,
          $$ChannelsTableUpdateCompanionBuilder,
          (ChannelRow, $$ChannelsTableReferences),
          ChannelRow,
          PrefetchHooks Function({
            bool sourceId,
            bool categoryId,
            bool epgMatchesRefs,
          })
        > {
  $$ChannelsTableTableManager(_$AppDatabase db, $ChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> number = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> cleanName = const Value.absent(),
                Value<String?> quality = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> epgKey = const Value.absent(),
                Value<int> archiveDays = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> extrasJson = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
              }) => ChannelsCompanion(
                sourceId: sourceId,
                remoteKey: remoteKey,
                position: position,
                seenRun: seenRun,
                id: id,
                categoryId: categoryId,
                number: number,
                name: name,
                displayName: displayName,
                cleanName: cleanName,
                quality: quality,
                logoUrl: logoUrl,
                epgKey: epgKey,
                archiveDays: archiveDays,
                streamUrl: streamUrl,
                extrasJson: extrasJson,
                isHidden: isHidden,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String remoteKey,
                Value<int> position = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> number = const Value.absent(),
                required String name,
                Value<String?> displayName = const Value.absent(),
                Value<String?> cleanName = const Value.absent(),
                Value<String?> quality = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> epgKey = const Value.absent(),
                Value<int> archiveDays = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> extrasJson = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
              }) => ChannelsCompanion.insert(
                sourceId: sourceId,
                remoteKey: remoteKey,
                position: position,
                seenRun: seenRun,
                id: id,
                categoryId: categoryId,
                number: number,
                name: name,
                displayName: displayName,
                cleanName: cleanName,
                quality: quality,
                logoUrl: logoUrl,
                epgKey: epgKey,
                archiveDays: archiveDays,
                streamUrl: streamUrl,
                extrasJson: extrasJson,
                isHidden: isHidden,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChannelsTable, ChannelRow>(table),
                  $$ChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sourceId = false, categoryId = false, epgMatchesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (epgMatchesRefs) db.epgMatches],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$ChannelsTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$ChannelsTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$ChannelsTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$ChannelsTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (epgMatchesRefs)
                        await $_getPrefetchedData<
                          ChannelRow,
                          $ChannelsTable,
                          EpgMatchRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChannelsTableReferences
                              ._epgMatchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChannelsTableReferences(
                                db,
                                table,
                                p0,
                              ).epgMatchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.channelId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChannelsTable,
      ChannelRow,
      $$ChannelsTableFilterComposer,
      $$ChannelsTableOrderingComposer,
      $$ChannelsTableAnnotationComposer,
      $$ChannelsTableCreateCompanionBuilder,
      $$ChannelsTableUpdateCompanionBuilder,
      (ChannelRow, $$ChannelsTableReferences),
      ChannelRow,
      PrefetchHooks Function({
        bool sourceId,
        bool categoryId,
        bool epgMatchesRefs,
      })
    >;
typedef $ChannelsFtsCreateCompanionBuilder = ChannelsFtsCompanion Function({
  required String cleanName,
  required String displayName,
  Value<int> rowid,
});
typedef $ChannelsFtsUpdateCompanionBuilder = ChannelsFtsCompanion Function({
  Value<String> cleanName,
  Value<String> displayName,
  Value<int> rowid,
});

class $ChannelsFtsFilterComposer extends Composer<_$AppDatabase, ChannelsFts> {
  $ChannelsFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cleanName => $composableBuilder(
    column: $table.cleanName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );
}

class $ChannelsFtsOrderingComposer
    extends Composer<_$AppDatabase, ChannelsFts> {
  $ChannelsFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cleanName => $composableBuilder(
    column: $table.cleanName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ChannelsFtsAnnotationComposer
    extends Composer<_$AppDatabase, ChannelsFts> {
  $ChannelsFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cleanName =>
      $composableBuilder(column: $table.cleanName, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );
}

class $ChannelsFtsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          ChannelsFts,
          ChannelsFt,
          $ChannelsFtsFilterComposer,
          $ChannelsFtsOrderingComposer,
          $ChannelsFtsAnnotationComposer,
          $ChannelsFtsCreateCompanionBuilder,
          $ChannelsFtsUpdateCompanionBuilder,
          (ChannelsFt, BaseReferences<_$AppDatabase, ChannelsFts, ChannelsFt>),
          ChannelsFt,
          PrefetchHooks Function()
        > {
  $ChannelsFtsTableManager(_$AppDatabase db, ChannelsFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ChannelsFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ChannelsFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ChannelsFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cleanName = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsFtsCompanion(
                cleanName: cleanName,
                displayName: displayName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cleanName,
                required String displayName,
                Value<int> rowid = const Value.absent(),
              }) => ChannelsFtsCompanion.insert(
                cleanName: cleanName,
                displayName: displayName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ChannelsFts, ChannelsFt>(table),
                  BaseReferences<_$AppDatabase, ChannelsFts, ChannelsFt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ChannelsFtsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      ChannelsFts,
      ChannelsFt,
      $ChannelsFtsFilterComposer,
      $ChannelsFtsOrderingComposer,
      $ChannelsFtsAnnotationComposer,
      $ChannelsFtsCreateCompanionBuilder,
      $ChannelsFtsUpdateCompanionBuilder,
      (ChannelsFt, BaseReferences<_$AppDatabase, ChannelsFts, ChannelsFt>),
      ChannelsFt,
      PrefetchHooks Function()
    >;
typedef $$MoviesTableCreateCompanionBuilder = MoviesCompanion Function({
  required String sourceId,
  required String remoteKey,
  Value<int> position,
  Value<int?> seenRun,
  Value<int> id,
  Value<int?> categoryId,
  required String name,
  Value<String?> posterUrl,
  Value<double?> rating,
  Value<int?> year,
  Value<String?> ext,
  Value<String?> streamUrl,
  Value<String?> extrasJson,
  Value<DateTime?> addedAt,
});
typedef $$MoviesTableUpdateCompanionBuilder = MoviesCompanion Function({
  Value<String> sourceId,
  Value<String> remoteKey,
  Value<int> position,
  Value<int?> seenRun,
  Value<int> id,
  Value<int?> categoryId,
  Value<String> name,
  Value<String?> posterUrl,
  Value<double?> rating,
  Value<int?> year,
  Value<String?> ext,
  Value<String?> streamUrl,
  Value<String?> extrasJson,
  Value<DateTime?> addedAt,
});

final class $$MoviesTableReferences
    extends BaseReferences<_$AppDatabase, $MoviesTable, MovieRow> {
  $$MoviesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('movies__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('movies__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MovieDetailsTable, List<MovieDetailsRow>>
  _movieDetailsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.movieDetails,
    aliasName: 'movies__id__movie_details__movie_id',
  );

  $$MovieDetailsTableProcessedTableManager get movieDetailsRefs {
    final manager = $$MovieDetailsTableTableManager(
      $_db,
      $_db.movieDetails,
    ).filter((f) => f.movieId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_movieDetailsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MoviesTableFilterComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> movieDetailsRefs(
    Expression<bool> Function($$MovieDetailsTableFilterComposer f) f,
  ) {
    final $$MovieDetailsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.movieDetails,
      getReferencedColumn: (t) => t.movieId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MovieDetailsTableFilterComposer(
            $db: $db,
            $table: $db.movieDetails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MoviesTableOrderingComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MoviesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get seenRun =>
      $composableBuilder(column: $table.seenRun, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> movieDetailsRefs<T extends Object>(
    Expression<T> Function($$MovieDetailsTableAnnotationComposer a) f,
  ) {
    final $$MovieDetailsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.movieDetails,
      getReferencedColumn: (t) => t.movieId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MovieDetailsTableAnnotationComposer(
            $db: $db,
            $table: $db.movieDetails,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MoviesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MoviesTable,
          MovieRow,
          $$MoviesTableFilterComposer,
          $$MoviesTableOrderingComposer,
          $$MoviesTableAnnotationComposer,
          $$MoviesTableCreateCompanionBuilder,
          $$MoviesTableUpdateCompanionBuilder,
          (MovieRow, $$MoviesTableReferences),
          MovieRow,
          PrefetchHooks Function({
            bool sourceId,
            bool categoryId,
            bool movieDetailsRefs,
          })
        > {
  $$MoviesTableTableManager(_$AppDatabase db, $MoviesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoviesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoviesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoviesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> extrasJson = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
              }) => MoviesCompanion(
                sourceId: sourceId,
                remoteKey: remoteKey,
                position: position,
                seenRun: seenRun,
                id: id,
                categoryId: categoryId,
                name: name,
                posterUrl: posterUrl,
                rating: rating,
                year: year,
                ext: ext,
                streamUrl: streamUrl,
                extrasJson: extrasJson,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String remoteKey,
                Value<int> position = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                required String name,
                Value<String?> posterUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> extrasJson = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
              }) => MoviesCompanion.insert(
                sourceId: sourceId,
                remoteKey: remoteKey,
                position: position,
                seenRun: seenRun,
                id: id,
                categoryId: categoryId,
                name: name,
                posterUrl: posterUrl,
                rating: rating,
                year: year,
                ext: ext,
                streamUrl: streamUrl,
                extrasJson: extrasJson,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MoviesTable, MovieRow>(table),
                  $$MoviesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                categoryId = false,
                movieDetailsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (movieDetailsRefs) db.movieDetails,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$MoviesTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$MoviesTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$MoviesTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$MoviesTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (movieDetailsRefs)
                        await $_getPrefetchedData<
                          MovieRow,
                          $MoviesTable,
                          MovieDetailsRow
                        >(
                          currentTable: table,
                          referencedTable: $$MoviesTableReferences
                              ._movieDetailsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MoviesTableReferences(
                                db,
                                table,
                                p0,
                              ).movieDetailsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.movieId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MoviesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MoviesTable,
      MovieRow,
      $$MoviesTableFilterComposer,
      $$MoviesTableOrderingComposer,
      $$MoviesTableAnnotationComposer,
      $$MoviesTableCreateCompanionBuilder,
      $$MoviesTableUpdateCompanionBuilder,
      (MovieRow, $$MoviesTableReferences),
      MovieRow,
      PrefetchHooks Function({
        bool sourceId,
        bool categoryId,
        bool movieDetailsRefs,
      })
    >;
typedef $MoviesFtsCreateCompanionBuilder = MoviesFtsCompanion Function({
  required String name,
  Value<int> rowid,
});
typedef $MoviesFtsUpdateCompanionBuilder = MoviesFtsCompanion Function({
  Value<String> name,
  Value<int> rowid,
});

class $MoviesFtsFilterComposer extends Composer<_$AppDatabase, MoviesFts> {
  $MoviesFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $MoviesFtsOrderingComposer extends Composer<_$AppDatabase, MoviesFts> {
  $MoviesFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MoviesFtsAnnotationComposer extends Composer<_$AppDatabase, MoviesFts> {
  $MoviesFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $MoviesFtsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          MoviesFts,
          MoviesFt,
          $MoviesFtsFilterComposer,
          $MoviesFtsOrderingComposer,
          $MoviesFtsAnnotationComposer,
          $MoviesFtsCreateCompanionBuilder,
          $MoviesFtsUpdateCompanionBuilder,
          (MoviesFt, BaseReferences<_$AppDatabase, MoviesFts, MoviesFt>),
          MoviesFt,
          PrefetchHooks Function()
        > {
  $MoviesFtsTableManager(_$AppDatabase db, MoviesFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MoviesFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MoviesFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MoviesFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MoviesFtsCompanion(name: name, rowid: rowid),
          createCompanionCallback: ({
            required String name,
            Value<int> rowid = const Value.absent(),
          }) => MoviesFtsCompanion.insert(name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<MoviesFts, MoviesFt>(table),
                  BaseReferences<_$AppDatabase, MoviesFts, MoviesFt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MoviesFtsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      MoviesFts,
      MoviesFt,
      $MoviesFtsFilterComposer,
      $MoviesFtsOrderingComposer,
      $MoviesFtsAnnotationComposer,
      $MoviesFtsCreateCompanionBuilder,
      $MoviesFtsUpdateCompanionBuilder,
      (MoviesFt, BaseReferences<_$AppDatabase, MoviesFts, MoviesFt>),
      MoviesFt,
      PrefetchHooks Function()
    >;
typedef $$SeriesTableCreateCompanionBuilder = SeriesCompanion Function({
  required String sourceId,
  required String remoteKey,
  Value<int> position,
  Value<int?> seenRun,
  Value<int> id,
  Value<int?> categoryId,
  required String name,
  Value<String?> posterUrl,
  Value<double?> rating,
  Value<int?> year,
  Value<String?> plot,
  Value<String?> genre,
  Value<String?> castNames,
  Value<String?> director,
  Value<String?> backdropUrl,
  Value<DateTime?> updatedAt,
  Value<DateTime?> episodesFetchedAt,
});
typedef $$SeriesTableUpdateCompanionBuilder = SeriesCompanion Function({
  Value<String> sourceId,
  Value<String> remoteKey,
  Value<int> position,
  Value<int?> seenRun,
  Value<int> id,
  Value<int?> categoryId,
  Value<String> name,
  Value<String?> posterUrl,
  Value<double?> rating,
  Value<int?> year,
  Value<String?> plot,
  Value<String?> genre,
  Value<String?> castNames,
  Value<String?> director,
  Value<String?> backdropUrl,
  Value<DateTime?> updatedAt,
  Value<DateTime?> episodesFetchedAt,
});

final class $$SeriesTableReferences
    extends BaseReferences<_$AppDatabase, $SeriesTable, SeriesRow> {
  $$SeriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('series__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('series__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EpisodesTable, List<EpisodeRow>>
  _episodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.episodes,
    aliasName: 'series__id__episodes__series_id',
  );

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SeriesTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get castNames => $composableBuilder(
    column: $table.castNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get episodesFetchedAt => $composableBuilder(
    column: $table.episodesFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> episodesRefs(
    Expression<bool> Function($$EpisodesTableFilterComposer f) f,
  ) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterUrl => $composableBuilder(
    column: $table.posterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get castNames => $composableBuilder(
    column: $table.castNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get episodesFetchedAt => $composableBuilder(
    column: $table.episodesFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get seenRun =>
      $composableBuilder(column: $table.seenRun, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get posterUrl =>
      $composableBuilder(column: $table.posterUrl, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get castNames =>
      $composableBuilder(column: $table.castNames, builder: (column) => column);

  GeneratedColumn<String> get director =>
      $composableBuilder(column: $table.director, builder: (column) => column);

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get episodesFetchedAt => $composableBuilder(
    column: $table.episodesFetchedAt,
    builder: (column) => column,
  );

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesTable,
          SeriesRow,
          $$SeriesTableFilterComposer,
          $$SeriesTableOrderingComposer,
          $$SeriesTableAnnotationComposer,
          $$SeriesTableCreateCompanionBuilder,
          $$SeriesTableUpdateCompanionBuilder,
          (SeriesRow, $$SeriesTableReferences),
          SeriesRow,
          PrefetchHooks Function({
            bool sourceId,
            bool categoryId,
            bool episodesRefs,
          })
        > {
  $$SeriesTableTableManager(_$AppDatabase db, $SeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> posterUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> castNames = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> episodesFetchedAt = const Value.absent(),
              }) => SeriesCompanion(
                sourceId: sourceId,
                remoteKey: remoteKey,
                position: position,
                seenRun: seenRun,
                id: id,
                categoryId: categoryId,
                name: name,
                posterUrl: posterUrl,
                rating: rating,
                year: year,
                plot: plot,
                genre: genre,
                castNames: castNames,
                director: director,
                backdropUrl: backdropUrl,
                updatedAt: updatedAt,
                episodesFetchedAt: episodesFetchedAt,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String remoteKey,
                Value<int> position = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                required String name,
                Value<String?> posterUrl = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> castNames = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> episodesFetchedAt = const Value.absent(),
              }) => SeriesCompanion.insert(
                sourceId: sourceId,
                remoteKey: remoteKey,
                position: position,
                seenRun: seenRun,
                id: id,
                categoryId: categoryId,
                name: name,
                posterUrl: posterUrl,
                rating: rating,
                year: year,
                plot: plot,
                genre: genre,
                castNames: castNames,
                director: director,
                backdropUrl: backdropUrl,
                updatedAt: updatedAt,
                episodesFetchedAt: episodesFetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeriesTable, SeriesRow>(table),
                  $$SeriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sourceId = false, categoryId = false, episodesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (episodesRefs) db.episodes],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$SeriesTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$SeriesTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$SeriesTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$SeriesTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (episodesRefs)
                        await $_getPrefetchedData<
                          SeriesRow,
                          $SeriesTable,
                          EpisodeRow
                        >(
                          currentTable: table,
                          referencedTable: $$SeriesTableReferences
                              ._episodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SeriesTableReferences(
                                db,
                                table,
                                p0,
                              ).episodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.seriesId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesTable,
      SeriesRow,
      $$SeriesTableFilterComposer,
      $$SeriesTableOrderingComposer,
      $$SeriesTableAnnotationComposer,
      $$SeriesTableCreateCompanionBuilder,
      $$SeriesTableUpdateCompanionBuilder,
      (SeriesRow, $$SeriesTableReferences),
      SeriesRow,
      PrefetchHooks Function({
        bool sourceId,
        bool categoryId,
        bool episodesRefs,
      })
    >;
typedef $SeriesFtsCreateCompanionBuilder = SeriesFtsCompanion Function({
  required String name,
  Value<int> rowid,
});
typedef $SeriesFtsUpdateCompanionBuilder = SeriesFtsCompanion Function({
  Value<String> name,
  Value<int> rowid,
});

class $SeriesFtsFilterComposer extends Composer<_$AppDatabase, SeriesFts> {
  $SeriesFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $SeriesFtsOrderingComposer extends Composer<_$AppDatabase, SeriesFts> {
  $SeriesFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SeriesFtsAnnotationComposer extends Composer<_$AppDatabase, SeriesFts> {
  $SeriesFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $SeriesFtsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SeriesFts,
          SeriesFt,
          $SeriesFtsFilterComposer,
          $SeriesFtsOrderingComposer,
          $SeriesFtsAnnotationComposer,
          $SeriesFtsCreateCompanionBuilder,
          $SeriesFtsUpdateCompanionBuilder,
          (SeriesFt, BaseReferences<_$AppDatabase, SeriesFts, SeriesFt>),
          SeriesFt,
          PrefetchHooks Function()
        > {
  $SeriesFtsTableManager(_$AppDatabase db, SeriesFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SeriesFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SeriesFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SeriesFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SeriesFtsCompanion(name: name, rowid: rowid),
          createCompanionCallback: ({
            required String name,
            Value<int> rowid = const Value.absent(),
          }) => SeriesFtsCompanion.insert(name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SeriesFts, SeriesFt>(table),
                  BaseReferences<_$AppDatabase, SeriesFts, SeriesFt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SeriesFtsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SeriesFts,
      SeriesFt,
      $SeriesFtsFilterComposer,
      $SeriesFtsOrderingComposer,
      $SeriesFtsAnnotationComposer,
      $SeriesFtsCreateCompanionBuilder,
      $SeriesFtsUpdateCompanionBuilder,
      (SeriesFt, BaseReferences<_$AppDatabase, SeriesFts, SeriesFt>),
      SeriesFt,
      PrefetchHooks Function()
    >;
typedef $$EpgProgramsTableCreateCompanionBuilder =
    EpgProgramsCompanion Function({
      Value<int> id,
      required String sourceId,
      required String epgChannelId,
      required int startUtc,
      required int endUtc,
      required String title,
      Value<String?> subtitle,
      Value<String?> description,
      Value<String?> category,
    });
typedef $$EpgProgramsTableUpdateCompanionBuilder =
    EpgProgramsCompanion Function({
      Value<int> id,
      Value<String> sourceId,
      Value<String> epgChannelId,
      Value<int> startUtc,
      Value<int> endUtc,
      Value<String> title,
      Value<String?> subtitle,
      Value<String?> description,
      Value<String?> category,
    });

final class $$EpgProgramsTableReferences
    extends BaseReferences<_$AppDatabase, $EpgProgramsTable, EpgProgramRow> {
  $$EpgProgramsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('epg_programs__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgProgramsTableFilterComposer
    extends Composer<_$AppDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableFilterComposer({
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

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgramsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableOrderingComposer({
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

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgramsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgProgramsTable> {
  $$EpgProgramsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<int> get endUtc =>
      $composableBuilder(column: $table.endUtc, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgramsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgProgramsTable,
          EpgProgramRow,
          $$EpgProgramsTableFilterComposer,
          $$EpgProgramsTableOrderingComposer,
          $$EpgProgramsTableAnnotationComposer,
          $$EpgProgramsTableCreateCompanionBuilder,
          $$EpgProgramsTableUpdateCompanionBuilder,
          (EpgProgramRow, $$EpgProgramsTableReferences),
          EpgProgramRow,
          PrefetchHooks Function({bool sourceId})
        > {
  $$EpgProgramsTableTableManager(_$AppDatabase db, $EpgProgramsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgProgramsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgProgramsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgProgramsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> epgChannelId = const Value.absent(),
                Value<int> startUtc = const Value.absent(),
                Value<int> endUtc = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> subtitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> category = const Value.absent(),
              }) => EpgProgramsCompanion(
                id: id,
                sourceId: sourceId,
                epgChannelId: epgChannelId,
                startUtc: startUtc,
                endUtc: endUtc,
                title: title,
                subtitle: subtitle,
                description: description,
                category: category,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required String epgChannelId,
                required int startUtc,
                required int endUtc,
                required String title,
                Value<String?> subtitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> category = const Value.absent(),
              }) => EpgProgramsCompanion.insert(
                id: id,
                sourceId: sourceId,
                epgChannelId: epgChannelId,
                startUtc: startUtc,
                endUtc: endUtc,
                title: title,
                subtitle: subtitle,
                description: description,
                category: category,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgProgramsTable, EpgProgramRow>(table),
                  $$EpgProgramsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$EpgProgramsTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$EpgProgramsTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgProgramsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgProgramsTable,
      EpgProgramRow,
      $$EpgProgramsTableFilterComposer,
      $$EpgProgramsTableOrderingComposer,
      $$EpgProgramsTableAnnotationComposer,
      $$EpgProgramsTableCreateCompanionBuilder,
      $$EpgProgramsTableUpdateCompanionBuilder,
      (EpgProgramRow, $$EpgProgramsTableReferences),
      EpgProgramRow,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $ProgramsFtsCreateCompanionBuilder = ProgramsFtsCompanion Function({
  required String title,
  required String subtitle,
  required String description,
  Value<int> rowid,
});
typedef $ProgramsFtsUpdateCompanionBuilder = ProgramsFtsCompanion Function({
  Value<String> title,
  Value<String> subtitle,
  Value<String> description,
  Value<int> rowid,
});

class $ProgramsFtsFilterComposer extends Composer<_$AppDatabase, ProgramsFts> {
  $ProgramsFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );
}

class $ProgramsFtsOrderingComposer
    extends Composer<_$AppDatabase, ProgramsFts> {
  $ProgramsFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ProgramsFtsAnnotationComposer
    extends Composer<_$AppDatabase, ProgramsFts> {
  $ProgramsFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );
}

class $ProgramsFtsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          ProgramsFts,
          ProgramsFt,
          $ProgramsFtsFilterComposer,
          $ProgramsFtsOrderingComposer,
          $ProgramsFtsAnnotationComposer,
          $ProgramsFtsCreateCompanionBuilder,
          $ProgramsFtsUpdateCompanionBuilder,
          (ProgramsFt, BaseReferences<_$AppDatabase, ProgramsFts, ProgramsFt>),
          ProgramsFt,
          PrefetchHooks Function()
        > {
  $ProgramsFtsTableManager(_$AppDatabase db, ProgramsFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ProgramsFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ProgramsFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ProgramsFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgramsFtsCompanion(
                title: title,
                subtitle: subtitle,
                description: description,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String title,
                required String subtitle,
                required String description,
                Value<int> rowid = const Value.absent(),
              }) => ProgramsFtsCompanion.insert(
                title: title,
                subtitle: subtitle,
                description: description,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ProgramsFts, ProgramsFt>(table),
                  BaseReferences<_$AppDatabase, ProgramsFts, ProgramsFt>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ProgramsFtsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      ProgramsFts,
      ProgramsFt,
      $ProgramsFtsFilterComposer,
      $ProgramsFtsOrderingComposer,
      $ProgramsFtsAnnotationComposer,
      $ProgramsFtsCreateCompanionBuilder,
      $ProgramsFtsUpdateCompanionBuilder,
      (ProgramsFt, BaseReferences<_$AppDatabase, ProgramsFts, ProgramsFt>),
      ProgramsFt,
      PrefetchHooks Function()
    >;
typedef $$EpgImportsTableCreateCompanionBuilder = EpgImportsCompanion Function({
  Value<int> id,
  required String sourceId,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  Value<SyncOutcome> outcome,
  Value<String?> failure,
  Value<int?> failureStatus,
  Value<String?> countsJson,
  Value<bool> isLive,
});
typedef $$EpgImportsTableUpdateCompanionBuilder = EpgImportsCompanion Function({
  Value<int> id,
  Value<String> sourceId,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<SyncOutcome> outcome,
  Value<String?> failure,
  Value<int?> failureStatus,
  Value<String?> countsJson,
  Value<bool> isLive,
});

final class $$EpgImportsTableReferences
    extends BaseReferences<_$AppDatabase, $EpgImportsTable, EpgImportRow> {
  $$EpgImportsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('epg_imports__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $EpgChannelsStagingTable,
    List<EpgChannelStagingRow>
  >
  _epgChannelsStagingRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.epgChannelsStaging,
        aliasName: 'epg_imports__id__epg_channels_staging__import_run',
      );

  $$EpgChannelsStagingTableProcessedTableManager get epgChannelsStagingRefs {
    final manager = $$EpgChannelsStagingTableTableManager(
      $_db,
      $_db.epgChannelsStaging,
    ).filter((f) => f.importRun.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _epgChannelsStagingRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $EpgProgramsStagingTable,
    List<EpgProgramStagingRow>
  >
  _epgProgramsStagingRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.epgProgramsStaging,
        aliasName: 'epg_imports__id__epg_programs_staging__import_run',
      );

  $$EpgProgramsStagingTableProcessedTableManager get epgProgramsStagingRefs {
    final manager = $$EpgProgramsStagingTableTableManager(
      $_db,
      $_db.epgProgramsStaging,
    ).filter((f) => f.importRun.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _epgProgramsStagingRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EpgImportsTableFilterComposer
    extends Composer<_$AppDatabase, $EpgImportsTable> {
  $$EpgImportsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncOutcome, SyncOutcome, String>
  get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get failure => $composableBuilder(
    column: $table.failure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failureStatus => $composableBuilder(
    column: $table.failureStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLive => $composableBuilder(
    column: $table.isLive,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> epgChannelsStagingRefs(
    Expression<bool> Function($$EpgChannelsStagingTableFilterComposer f) f,
  ) {
    final $$EpgChannelsStagingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgChannelsStaging,
      getReferencedColumn: (t) => t.importRun,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgChannelsStagingTableFilterComposer(
            $db: $db,
            $table: $db.epgChannelsStaging,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgProgramsStagingRefs(
    Expression<bool> Function($$EpgProgramsStagingTableFilterComposer f) f,
  ) {
    final $$EpgProgramsStagingTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgProgramsStaging,
      getReferencedColumn: (t) => t.importRun,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgProgramsStagingTableFilterComposer(
            $db: $db,
            $table: $db.epgProgramsStaging,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EpgImportsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgImportsTable> {
  $$EpgImportsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failure => $composableBuilder(
    column: $table.failure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failureStatus => $composableBuilder(
    column: $table.failureStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLive => $composableBuilder(
    column: $table.isLive,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgImportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgImportsTable> {
  $$EpgImportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SyncOutcome, String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get failure =>
      $composableBuilder(column: $table.failure, builder: (column) => column);

  GeneratedColumn<int> get failureStatus => $composableBuilder(
    column: $table.failureStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isLive =>
      $composableBuilder(column: $table.isLive, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> epgChannelsStagingRefs<T extends Object>(
    Expression<T> Function($$EpgChannelsStagingTableAnnotationComposer a) f,
  ) {
    final $$EpgChannelsStagingTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.epgChannelsStaging,
          getReferencedColumn: (t) => t.importRun,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EpgChannelsStagingTableAnnotationComposer(
                $db: $db,
                $table: $db.epgChannelsStaging,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> epgProgramsStagingRefs<T extends Object>(
    Expression<T> Function($$EpgProgramsStagingTableAnnotationComposer a) f,
  ) {
    final $$EpgProgramsStagingTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.epgProgramsStaging,
          getReferencedColumn: (t) => t.importRun,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EpgProgramsStagingTableAnnotationComposer(
                $db: $db,
                $table: $db.epgProgramsStaging,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EpgImportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgImportsTable,
          EpgImportRow,
          $$EpgImportsTableFilterComposer,
          $$EpgImportsTableOrderingComposer,
          $$EpgImportsTableAnnotationComposer,
          $$EpgImportsTableCreateCompanionBuilder,
          $$EpgImportsTableUpdateCompanionBuilder,
          (EpgImportRow, $$EpgImportsTableReferences),
          EpgImportRow,
          PrefetchHooks Function({
            bool sourceId,
            bool epgChannelsStagingRefs,
            bool epgProgramsStagingRefs,
          })
        > {
  $$EpgImportsTableTableManager(_$AppDatabase db, $EpgImportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgImportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgImportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgImportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<SyncOutcome> outcome = const Value.absent(),
                Value<String?> failure = const Value.absent(),
                Value<int?> failureStatus = const Value.absent(),
                Value<String?> countsJson = const Value.absent(),
                Value<bool> isLive = const Value.absent(),
              }) => EpgImportsCompanion(
                id: id,
                sourceId: sourceId,
                startedAt: startedAt,
                finishedAt: finishedAt,
                outcome: outcome,
                failure: failure,
                failureStatus: failureStatus,
                countsJson: countsJson,
                isLive: isLive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<SyncOutcome> outcome = const Value.absent(),
                Value<String?> failure = const Value.absent(),
                Value<int?> failureStatus = const Value.absent(),
                Value<String?> countsJson = const Value.absent(),
                Value<bool> isLive = const Value.absent(),
              }) => EpgImportsCompanion.insert(
                id: id,
                sourceId: sourceId,
                startedAt: startedAt,
                finishedAt: finishedAt,
                outcome: outcome,
                failure: failure,
                failureStatus: failureStatus,
                countsJson: countsJson,
                isLive: isLive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgImportsTable, EpgImportRow>(table),
                  $$EpgImportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                epgChannelsStagingRefs = false,
                epgProgramsStagingRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (epgChannelsStagingRefs) db.epgChannelsStaging,
                    if (epgProgramsStagingRefs) db.epgProgramsStaging,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$EpgImportsTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$EpgImportsTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (epgChannelsStagingRefs)
                        await $_getPrefetchedData<
                          EpgImportRow,
                          $EpgImportsTable,
                          EpgChannelStagingRow
                        >(
                          currentTable: table,
                          referencedTable: $$EpgImportsTableReferences
                              ._epgChannelsStagingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpgImportsTableReferences(
                                db,
                                table,
                                p0,
                              ).epgChannelsStagingRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.importRun == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgProgramsStagingRefs)
                        await $_getPrefetchedData<
                          EpgImportRow,
                          $EpgImportsTable,
                          EpgProgramStagingRow
                        >(
                          currentTable: table,
                          referencedTable: $$EpgImportsTableReferences
                              ._epgProgramsStagingRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EpgImportsTableReferences(
                                db,
                                table,
                                p0,
                              ).epgProgramsStagingRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.importRun == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EpgImportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgImportsTable,
      EpgImportRow,
      $$EpgImportsTableFilterComposer,
      $$EpgImportsTableOrderingComposer,
      $$EpgImportsTableAnnotationComposer,
      $$EpgImportsTableCreateCompanionBuilder,
      $$EpgImportsTableUpdateCompanionBuilder,
      (EpgImportRow, $$EpgImportsTableReferences),
      EpgImportRow,
      PrefetchHooks Function({
        bool sourceId,
        bool epgChannelsStagingRefs,
        bool epgProgramsStagingRefs,
      })
    >;
typedef $$EpgChannelsTableCreateCompanionBuilder =
    EpgChannelsCompanion Function({
      Value<int> id,
      required String sourceId,
      required String xmltvId,
      Value<String?> displayName,
      Value<String?> iconUrl,
    });
typedef $$EpgChannelsTableUpdateCompanionBuilder =
    EpgChannelsCompanion Function({
      Value<int> id,
      Value<String> sourceId,
      Value<String> xmltvId,
      Value<String?> displayName,
      Value<String?> iconUrl,
    });

final class $$EpgChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $EpgChannelsTable, EpgChannelRow> {
  $$EpgChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('epg_channels__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableFilterComposer({
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

  ColumnFilters<String> get xmltvId => $composableBuilder(
    column: $table.xmltvId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableOrderingComposer({
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

  ColumnOrderings<String> get xmltvId => $composableBuilder(
    column: $table.xmltvId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get xmltvId =>
      $composableBuilder(column: $table.xmltvId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgChannelsTable,
          EpgChannelRow,
          $$EpgChannelsTableFilterComposer,
          $$EpgChannelsTableOrderingComposer,
          $$EpgChannelsTableAnnotationComposer,
          $$EpgChannelsTableCreateCompanionBuilder,
          $$EpgChannelsTableUpdateCompanionBuilder,
          (EpgChannelRow, $$EpgChannelsTableReferences),
          EpgChannelRow,
          PrefetchHooks Function({bool sourceId})
        > {
  $$EpgChannelsTableTableManager(_$AppDatabase db, $EpgChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> xmltvId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
              }) => EpgChannelsCompanion(
                id: id,
                sourceId: sourceId,
                xmltvId: xmltvId,
                displayName: displayName,
                iconUrl: iconUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required String xmltvId,
                Value<String?> displayName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
              }) => EpgChannelsCompanion.insert(
                id: id,
                sourceId: sourceId,
                xmltvId: xmltvId,
                displayName: displayName,
                iconUrl: iconUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgChannelsTable, EpgChannelRow>(table),
                  $$EpgChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$EpgChannelsTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$EpgChannelsTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgChannelsTable,
      EpgChannelRow,
      $$EpgChannelsTableFilterComposer,
      $$EpgChannelsTableOrderingComposer,
      $$EpgChannelsTableAnnotationComposer,
      $$EpgChannelsTableCreateCompanionBuilder,
      $$EpgChannelsTableUpdateCompanionBuilder,
      (EpgChannelRow, $$EpgChannelsTableReferences),
      EpgChannelRow,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$EpgChannelsStagingTableCreateCompanionBuilder =
    EpgChannelsStagingCompanion Function({
      Value<int> id,
      required int importRun,
      required String xmltvId,
      Value<String?> displayName,
      Value<String?> iconUrl,
    });
typedef $$EpgChannelsStagingTableUpdateCompanionBuilder =
    EpgChannelsStagingCompanion Function({
      Value<int> id,
      Value<int> importRun,
      Value<String> xmltvId,
      Value<String?> displayName,
      Value<String?> iconUrl,
    });

final class $$EpgChannelsStagingTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EpgChannelsStagingTable,
          EpgChannelStagingRow
        > {
  $$EpgChannelsStagingTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EpgImportsTable _importRunTable(_$AppDatabase db) => db.epgImports
      .createAlias('epg_channels_staging__import_run__epg_imports__id');

  $$EpgImportsTableProcessedTableManager get importRun {
    final $_column = $_itemColumn<int>('import_run')!;

    final manager = $$EpgImportsTableTableManager(
      $_db,
      $_db.epgImports,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importRunTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgChannelsStagingTableFilterComposer
    extends Composer<_$AppDatabase, $EpgChannelsStagingTable> {
  $$EpgChannelsStagingTableFilterComposer({
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

  ColumnFilters<String> get xmltvId => $composableBuilder(
    column: $table.xmltvId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  $$EpgImportsTableFilterComposer get importRun {
    final $$EpgImportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importRun,
      referencedTable: $db.epgImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgImportsTableFilterComposer(
            $db: $db,
            $table: $db.epgImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsStagingTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgChannelsStagingTable> {
  $$EpgChannelsStagingTableOrderingComposer({
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

  ColumnOrderings<String> get xmltvId => $composableBuilder(
    column: $table.xmltvId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpgImportsTableOrderingComposer get importRun {
    final $$EpgImportsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importRun,
      referencedTable: $db.epgImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgImportsTableOrderingComposer(
            $db: $db,
            $table: $db.epgImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsStagingTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgChannelsStagingTable> {
  $$EpgChannelsStagingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get xmltvId =>
      $composableBuilder(column: $table.xmltvId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconUrl =>
      $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  $$EpgImportsTableAnnotationComposer get importRun {
    final $$EpgImportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importRun,
      referencedTable: $db.epgImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgImportsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsStagingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgChannelsStagingTable,
          EpgChannelStagingRow,
          $$EpgChannelsStagingTableFilterComposer,
          $$EpgChannelsStagingTableOrderingComposer,
          $$EpgChannelsStagingTableAnnotationComposer,
          $$EpgChannelsStagingTableCreateCompanionBuilder,
          $$EpgChannelsStagingTableUpdateCompanionBuilder,
          (EpgChannelStagingRow, $$EpgChannelsStagingTableReferences),
          EpgChannelStagingRow,
          PrefetchHooks Function({bool importRun})
        > {
  $$EpgChannelsStagingTableTableManager(
    _$AppDatabase db,
    $EpgChannelsStagingTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgChannelsStagingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgChannelsStagingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgChannelsStagingTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> importRun = const Value.absent(),
                Value<String> xmltvId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
              }) => EpgChannelsStagingCompanion(
                id: id,
                importRun: importRun,
                xmltvId: xmltvId,
                displayName: displayName,
                iconUrl: iconUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int importRun,
                required String xmltvId,
                Value<String?> displayName = const Value.absent(),
                Value<String?> iconUrl = const Value.absent(),
              }) => EpgChannelsStagingCompanion.insert(
                id: id,
                importRun: importRun,
                xmltvId: xmltvId,
                displayName: displayName,
                iconUrl: iconUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgChannelsStagingTable, EpgChannelStagingRow>(
                    table,
                  ),
                  $$EpgChannelsStagingTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({importRun = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (importRun) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.importRun,
                        referencedTable: $$EpgChannelsStagingTableReferences
                            ._importRunTable(db),
                        referencedColumn: $$EpgChannelsStagingTableReferences
                            ._importRunTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgChannelsStagingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgChannelsStagingTable,
      EpgChannelStagingRow,
      $$EpgChannelsStagingTableFilterComposer,
      $$EpgChannelsStagingTableOrderingComposer,
      $$EpgChannelsStagingTableAnnotationComposer,
      $$EpgChannelsStagingTableCreateCompanionBuilder,
      $$EpgChannelsStagingTableUpdateCompanionBuilder,
      (EpgChannelStagingRow, $$EpgChannelsStagingTableReferences),
      EpgChannelStagingRow,
      PrefetchHooks Function({bool importRun})
    >;
typedef $$EpgProgramsStagingTableCreateCompanionBuilder =
    EpgProgramsStagingCompanion Function({
      Value<int> id,
      required int importRun,
      required String epgChannelId,
      required int startUtc,
      required int endUtc,
      required String title,
      Value<String?> subtitle,
      Value<String?> description,
      Value<String?> category,
    });
typedef $$EpgProgramsStagingTableUpdateCompanionBuilder =
    EpgProgramsStagingCompanion Function({
      Value<int> id,
      Value<int> importRun,
      Value<String> epgChannelId,
      Value<int> startUtc,
      Value<int> endUtc,
      Value<String> title,
      Value<String?> subtitle,
      Value<String?> description,
      Value<String?> category,
    });

final class $$EpgProgramsStagingTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EpgProgramsStagingTable,
          EpgProgramStagingRow
        > {
  $$EpgProgramsStagingTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EpgImportsTable _importRunTable(_$AppDatabase db) => db.epgImports
      .createAlias('epg_programs_staging__import_run__epg_imports__id');

  $$EpgImportsTableProcessedTableManager get importRun {
    final $_column = $_itemColumn<int>('import_run')!;

    final manager = $$EpgImportsTableTableManager(
      $_db,
      $_db.epgImports,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importRunTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgProgramsStagingTableFilterComposer
    extends Composer<_$AppDatabase, $EpgProgramsStagingTable> {
  $$EpgProgramsStagingTableFilterComposer({
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

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  $$EpgImportsTableFilterComposer get importRun {
    final $$EpgImportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importRun,
      referencedTable: $db.epgImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgImportsTableFilterComposer(
            $db: $db,
            $table: $db.epgImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgramsStagingTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgProgramsStagingTable> {
  $$EpgProgramsStagingTableOrderingComposer({
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

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  $$EpgImportsTableOrderingComposer get importRun {
    final $$EpgImportsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importRun,
      referencedTable: $db.epgImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgImportsTableOrderingComposer(
            $db: $db,
            $table: $db.epgImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgramsStagingTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgProgramsStagingTable> {
  $$EpgProgramsStagingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<int> get endUtc =>
      $composableBuilder(column: $table.endUtc, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  $$EpgImportsTableAnnotationComposer get importRun {
    final $$EpgImportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importRun,
      referencedTable: $db.epgImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgImportsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgProgramsStagingTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgProgramsStagingTable,
          EpgProgramStagingRow,
          $$EpgProgramsStagingTableFilterComposer,
          $$EpgProgramsStagingTableOrderingComposer,
          $$EpgProgramsStagingTableAnnotationComposer,
          $$EpgProgramsStagingTableCreateCompanionBuilder,
          $$EpgProgramsStagingTableUpdateCompanionBuilder,
          (EpgProgramStagingRow, $$EpgProgramsStagingTableReferences),
          EpgProgramStagingRow,
          PrefetchHooks Function({bool importRun})
        > {
  $$EpgProgramsStagingTableTableManager(
    _$AppDatabase db,
    $EpgProgramsStagingTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgProgramsStagingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgProgramsStagingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgProgramsStagingTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> importRun = const Value.absent(),
                Value<String> epgChannelId = const Value.absent(),
                Value<int> startUtc = const Value.absent(),
                Value<int> endUtc = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> subtitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> category = const Value.absent(),
              }) => EpgProgramsStagingCompanion(
                id: id,
                importRun: importRun,
                epgChannelId: epgChannelId,
                startUtc: startUtc,
                endUtc: endUtc,
                title: title,
                subtitle: subtitle,
                description: description,
                category: category,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int importRun,
                required String epgChannelId,
                required int startUtc,
                required int endUtc,
                required String title,
                Value<String?> subtitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> category = const Value.absent(),
              }) => EpgProgramsStagingCompanion.insert(
                id: id,
                importRun: importRun,
                epgChannelId: epgChannelId,
                startUtc: startUtc,
                endUtc: endUtc,
                title: title,
                subtitle: subtitle,
                description: description,
                category: category,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgProgramsStagingTable, EpgProgramStagingRow>(
                    table,
                  ),
                  $$EpgProgramsStagingTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({importRun = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (importRun) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.importRun,
                        referencedTable: $$EpgProgramsStagingTableReferences
                            ._importRunTable(db),
                        referencedColumn: $$EpgProgramsStagingTableReferences
                            ._importRunTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgProgramsStagingTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgProgramsStagingTable,
      EpgProgramStagingRow,
      $$EpgProgramsStagingTableFilterComposer,
      $$EpgProgramsStagingTableOrderingComposer,
      $$EpgProgramsStagingTableAnnotationComposer,
      $$EpgProgramsStagingTableCreateCompanionBuilder,
      $$EpgProgramsStagingTableUpdateCompanionBuilder,
      (EpgProgramStagingRow, $$EpgProgramsStagingTableReferences),
      EpgProgramStagingRow,
      PrefetchHooks Function({bool importRun})
    >;
typedef $$EpgMappingsTableCreateCompanionBuilder =
    EpgMappingsCompanion Function({
      required String sourceId,
      required String channelRemoteKey,
      required String xmltvId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$EpgMappingsTableUpdateCompanionBuilder =
    EpgMappingsCompanion Function({
      Value<String> sourceId,
      Value<String> channelRemoteKey,
      Value<String> xmltvId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$EpgMappingsTableReferences
    extends BaseReferences<_$AppDatabase, $EpgMappingsTable, EpgMappingRow> {
  $$EpgMappingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('epg_mappings__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $EpgMappingsTable> {
  $$EpgMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get channelRemoteKey => $composableBuilder(
    column: $table.channelRemoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get xmltvId => $composableBuilder(
    column: $table.xmltvId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgMappingsTable> {
  $$EpgMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get channelRemoteKey => $composableBuilder(
    column: $table.channelRemoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get xmltvId => $composableBuilder(
    column: $table.xmltvId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgMappingsTable> {
  $$EpgMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get channelRemoteKey => $composableBuilder(
    column: $table.channelRemoteKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get xmltvId =>
      $composableBuilder(column: $table.xmltvId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgMappingsTable,
          EpgMappingRow,
          $$EpgMappingsTableFilterComposer,
          $$EpgMappingsTableOrderingComposer,
          $$EpgMappingsTableAnnotationComposer,
          $$EpgMappingsTableCreateCompanionBuilder,
          $$EpgMappingsTableUpdateCompanionBuilder,
          (EpgMappingRow, $$EpgMappingsTableReferences),
          EpgMappingRow,
          PrefetchHooks Function({bool sourceId})
        > {
  $$EpgMappingsTableTableManager(_$AppDatabase db, $EpgMappingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgMappingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgMappingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> channelRemoteKey = const Value.absent(),
                Value<String> xmltvId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpgMappingsCompanion(
                sourceId: sourceId,
                channelRemoteKey: channelRemoteKey,
                xmltvId: xmltvId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String channelRemoteKey,
                required String xmltvId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EpgMappingsCompanion.insert(
                sourceId: sourceId,
                channelRemoteKey: channelRemoteKey,
                xmltvId: xmltvId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgMappingsTable, EpgMappingRow>(table),
                  $$EpgMappingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$EpgMappingsTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$EpgMappingsTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgMappingsTable,
      EpgMappingRow,
      $$EpgMappingsTableFilterComposer,
      $$EpgMappingsTableOrderingComposer,
      $$EpgMappingsTableAnnotationComposer,
      $$EpgMappingsTableCreateCompanionBuilder,
      $$EpgMappingsTableUpdateCompanionBuilder,
      (EpgMappingRow, $$EpgMappingsTableReferences),
      EpgMappingRow,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$EpgMatchesTableCreateCompanionBuilder = EpgMatchesCompanion Function({
  Value<int> channelId,
  required String sourceId,
  required String xmltvId,
  required EpgMatchRule rule,
});
typedef $$EpgMatchesTableUpdateCompanionBuilder = EpgMatchesCompanion Function({
  Value<int> channelId,
  Value<String> sourceId,
  Value<String> xmltvId,
  Value<EpgMatchRule> rule,
});

final class $$EpgMatchesTableReferences
    extends BaseReferences<_$AppDatabase, $EpgMatchesTable, EpgMatchRow> {
  $$EpgMatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChannelsTable _channelIdTable(_$AppDatabase db) =>
      db.channels.createAlias('epg_matches__channel_id__channels__id');

  $$ChannelsTableProcessedTableManager get channelId {
    final $_column = $_itemColumn<int>('channel_id')!;

    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_channelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('epg_matches__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgMatchesTableFilterComposer
    extends Composer<_$AppDatabase, $EpgMatchesTable> {
  $$EpgMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get xmltvId => $composableBuilder(
    column: $table.xmltvId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EpgMatchRule, EpgMatchRule, String> get rule =>
      $composableBuilder(
        column: $table.rule,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ChannelsTableFilterComposer get channelId {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgMatchesTable> {
  $$EpgMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get xmltvId => $composableBuilder(
    column: $table.xmltvId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rule => $composableBuilder(
    column: $table.rule,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChannelsTableOrderingComposer get channelId {
    final $$ChannelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableOrderingComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgMatchesTable> {
  $$EpgMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get xmltvId =>
      $composableBuilder(column: $table.xmltvId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EpgMatchRule, String> get rule =>
      $composableBuilder(column: $table.rule, builder: (column) => column);

  $$ChannelsTableAnnotationComposer get channelId {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.channelId,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgMatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgMatchesTable,
          EpgMatchRow,
          $$EpgMatchesTableFilterComposer,
          $$EpgMatchesTableOrderingComposer,
          $$EpgMatchesTableAnnotationComposer,
          $$EpgMatchesTableCreateCompanionBuilder,
          $$EpgMatchesTableUpdateCompanionBuilder,
          (EpgMatchRow, $$EpgMatchesTableReferences),
          EpgMatchRow,
          PrefetchHooks Function({bool channelId, bool sourceId})
        > {
  $$EpgMatchesTableTableManager(_$AppDatabase db, $EpgMatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> channelId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> xmltvId = const Value.absent(),
                Value<EpgMatchRule> rule = const Value.absent(),
              }) => EpgMatchesCompanion(
                channelId: channelId,
                sourceId: sourceId,
                xmltvId: xmltvId,
                rule: rule,
              ),
          createCompanionCallback:
              ({
                Value<int> channelId = const Value.absent(),
                required String sourceId,
                required String xmltvId,
                required EpgMatchRule rule,
              }) => EpgMatchesCompanion.insert(
                channelId: channelId,
                sourceId: sourceId,
                xmltvId: xmltvId,
                rule: rule,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgMatchesTable, EpgMatchRow>(table),
                  $$EpgMatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({channelId = false, sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (channelId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.channelId,
                        referencedTable: $$EpgMatchesTableReferences
                            ._channelIdTable(db),
                        referencedColumn: $$EpgMatchesTableReferences
                            ._channelIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$EpgMatchesTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$EpgMatchesTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgMatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgMatchesTable,
      EpgMatchRow,
      $$EpgMatchesTableFilterComposer,
      $$EpgMatchesTableOrderingComposer,
      $$EpgMatchesTableAnnotationComposer,
      $$EpgMatchesTableCreateCompanionBuilder,
      $$EpgMatchesTableUpdateCompanionBuilder,
      (EpgMatchRow, $$EpgMatchesTableReferences),
      EpgMatchRow,
      PrefetchHooks Function({bool channelId, bool sourceId})
    >;
typedef $$SyncRunsTableCreateCompanionBuilder = SyncRunsCompanion Function({
  Value<int> id,
  required String sourceId,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  Value<SyncOutcome> outcome,
  Value<String?> failure,
  Value<int?> failureStatus,
  Value<String?> countsJson,
});
typedef $$SyncRunsTableUpdateCompanionBuilder = SyncRunsCompanion Function({
  Value<int> id,
  Value<String> sourceId,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<SyncOutcome> outcome,
  Value<String?> failure,
  Value<int?> failureStatus,
  Value<String?> countsJson,
});

final class $$SyncRunsTableReferences
    extends BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRunRow> {
  $$SyncRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.sources.createAlias('sync_runs__source_id__sources__id');

  $$SourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$SourcesTableTableManager(
      $_db,
      $_db.sources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncRunsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SyncOutcome, SyncOutcome, String>
  get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get failure => $composableBuilder(
    column: $table.failure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failureStatus => $composableBuilder(
    column: $table.failureStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$SourcesTableFilterComposer get sourceId {
    final $$SourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableFilterComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failure => $composableBuilder(
    column: $table.failure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failureStatus => $composableBuilder(
    column: $table.failureStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$SourcesTableOrderingComposer get sourceId {
    final $$SourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableOrderingComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SyncOutcome, String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get failure =>
      $composableBuilder(column: $table.failure, builder: (column) => column);

  GeneratedColumn<int> get failureStatus => $composableBuilder(
    column: $table.failureStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get countsJson => $composableBuilder(
    column: $table.countsJson,
    builder: (column) => column,
  );

  $$SourcesTableAnnotationComposer get sourceId {
    final $$SourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.sources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.sources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRunsTable,
          SyncRunRow,
          $$SyncRunsTableFilterComposer,
          $$SyncRunsTableOrderingComposer,
          $$SyncRunsTableAnnotationComposer,
          $$SyncRunsTableCreateCompanionBuilder,
          $$SyncRunsTableUpdateCompanionBuilder,
          (SyncRunRow, $$SyncRunsTableReferences),
          SyncRunRow,
          PrefetchHooks Function({bool sourceId})
        > {
  $$SyncRunsTableTableManager(_$AppDatabase db, $SyncRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<SyncOutcome> outcome = const Value.absent(),
                Value<String?> failure = const Value.absent(),
                Value<int?> failureStatus = const Value.absent(),
                Value<String?> countsJson = const Value.absent(),
              }) => SyncRunsCompanion(
                id: id,
                sourceId: sourceId,
                startedAt: startedAt,
                finishedAt: finishedAt,
                outcome: outcome,
                failure: failure,
                failureStatus: failureStatus,
                countsJson: countsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceId,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<SyncOutcome> outcome = const Value.absent(),
                Value<String?> failure = const Value.absent(),
                Value<int?> failureStatus = const Value.absent(),
                Value<String?> countsJson = const Value.absent(),
              }) => SyncRunsCompanion.insert(
                id: id,
                sourceId: sourceId,
                startedAt: startedAt,
                finishedAt: finishedAt,
                outcome: outcome,
                failure: failure,
                failureStatus: failureStatus,
                countsJson: countsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncRunsTable, SyncRunRow>(table),
                  $$SyncRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sourceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceId,
                        referencedTable: $$SyncRunsTableReferences
                            ._sourceIdTable(db),
                        referencedColumn: $$SyncRunsTableReferences
                            ._sourceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SyncRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRunsTable,
      SyncRunRow,
      $$SyncRunsTableFilterComposer,
      $$SyncRunsTableOrderingComposer,
      $$SyncRunsTableAnnotationComposer,
      $$SyncRunsTableCreateCompanionBuilder,
      $$SyncRunsTableUpdateCompanionBuilder,
      (SyncRunRow, $$SyncRunsTableReferences),
      SyncRunRow,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$MovieDetailsTableCreateCompanionBuilder =
    MovieDetailsCompanion Function({
      Value<int> movieId,
      Value<String?> plot,
      Value<String?> castNames,
      Value<String?> director,
      Value<String?> genre,
      Value<int?> runtimeMinutes,
      Value<String?> backdropUrl,
      Value<int?> videoHeight,
      Value<int?> audioChannels,
      required DateTime fetchedAt,
    });
typedef $$MovieDetailsTableUpdateCompanionBuilder =
    MovieDetailsCompanion Function({
      Value<int> movieId,
      Value<String?> plot,
      Value<String?> castNames,
      Value<String?> director,
      Value<String?> genre,
      Value<int?> runtimeMinutes,
      Value<String?> backdropUrl,
      Value<int?> videoHeight,
      Value<int?> audioChannels,
      Value<DateTime> fetchedAt,
    });

final class $$MovieDetailsTableReferences
    extends BaseReferences<_$AppDatabase, $MovieDetailsTable, MovieDetailsRow> {
  $$MovieDetailsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MoviesTable _movieIdTable(_$AppDatabase db) =>
      db.movies.createAlias('movie_details__movie_id__movies__id');

  $$MoviesTableProcessedTableManager get movieId {
    final $_column = $_itemColumn<int>('movie_id')!;

    final manager = $$MoviesTableTableManager(
      $_db,
      $_db.movies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_movieIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MovieDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $MovieDetailsTable> {
  $$MovieDetailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get castNames => $composableBuilder(
    column: $table.castNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runtimeMinutes => $composableBuilder(
    column: $table.runtimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioChannels => $composableBuilder(
    column: $table.audioChannels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MoviesTableFilterComposer get movieId {
    final $$MoviesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.movieId,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableFilterComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MovieDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $MovieDetailsTable> {
  $$MovieDetailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get castNames => $composableBuilder(
    column: $table.castNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runtimeMinutes => $composableBuilder(
    column: $table.runtimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioChannels => $composableBuilder(
    column: $table.audioChannels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MoviesTableOrderingComposer get movieId {
    final $$MoviesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.movieId,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableOrderingComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MovieDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MovieDetailsTable> {
  $$MovieDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get castNames =>
      $composableBuilder(column: $table.castNames, builder: (column) => column);

  GeneratedColumn<String> get director =>
      $composableBuilder(column: $table.director, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get runtimeMinutes => $composableBuilder(
    column: $table.runtimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backdropUrl => $composableBuilder(
    column: $table.backdropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get videoHeight => $composableBuilder(
    column: $table.videoHeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioChannels => $composableBuilder(
    column: $table.audioChannels,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  $$MoviesTableAnnotationComposer get movieId {
    final $$MoviesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.movieId,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableAnnotationComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MovieDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MovieDetailsTable,
          MovieDetailsRow,
          $$MovieDetailsTableFilterComposer,
          $$MovieDetailsTableOrderingComposer,
          $$MovieDetailsTableAnnotationComposer,
          $$MovieDetailsTableCreateCompanionBuilder,
          $$MovieDetailsTableUpdateCompanionBuilder,
          (MovieDetailsRow, $$MovieDetailsTableReferences),
          MovieDetailsRow,
          PrefetchHooks Function({bool movieId})
        > {
  $$MovieDetailsTableTableManager(_$AppDatabase db, $MovieDetailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MovieDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MovieDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MovieDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> movieId = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> castNames = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> runtimeMinutes = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<int?> videoHeight = const Value.absent(),
                Value<int?> audioChannels = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => MovieDetailsCompanion(
                movieId: movieId,
                plot: plot,
                castNames: castNames,
                director: director,
                genre: genre,
                runtimeMinutes: runtimeMinutes,
                backdropUrl: backdropUrl,
                videoHeight: videoHeight,
                audioChannels: audioChannels,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> movieId = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> castNames = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> runtimeMinutes = const Value.absent(),
                Value<String?> backdropUrl = const Value.absent(),
                Value<int?> videoHeight = const Value.absent(),
                Value<int?> audioChannels = const Value.absent(),
                required DateTime fetchedAt,
              }) => MovieDetailsCompanion.insert(
                movieId: movieId,
                plot: plot,
                castNames: castNames,
                director: director,
                genre: genre,
                runtimeMinutes: runtimeMinutes,
                backdropUrl: backdropUrl,
                videoHeight: videoHeight,
                audioChannels: audioChannels,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MovieDetailsTable, MovieDetailsRow>(table),
                  $$MovieDetailsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({movieId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (movieId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.movieId,
                        referencedTable: $$MovieDetailsTableReferences
                            ._movieIdTable(db),
                        referencedColumn: $$MovieDetailsTableReferences
                            ._movieIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MovieDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MovieDetailsTable,
      MovieDetailsRow,
      $$MovieDetailsTableFilterComposer,
      $$MovieDetailsTableOrderingComposer,
      $$MovieDetailsTableAnnotationComposer,
      $$MovieDetailsTableCreateCompanionBuilder,
      $$MovieDetailsTableUpdateCompanionBuilder,
      (MovieDetailsRow, $$MovieDetailsTableReferences),
      MovieDetailsRow,
      PrefetchHooks Function({bool movieId})
    >;
typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  required int seriesId,
  required String remoteKey,
  required int season,
  required int episode,
  required String title,
  Value<String?> ext,
  Value<int?> durationSeconds,
  Value<String?> plot,
  Value<String?> stillUrl,
  Value<String?> streamUrl,
  Value<String?> extrasJson,
  Value<int?> seenRun,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  Value<int> seriesId,
  Value<String> remoteKey,
  Value<int> season,
  Value<int> episode,
  Value<String> title,
  Value<String?> ext,
  Value<int?> durationSeconds,
  Value<String?> plot,
  Value<String?> stillUrl,
  Value<String?> streamUrl,
  Value<String?> extrasJson,
  Value<int?> seenRun,
});

final class $$EpisodesTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodesTable, EpisodeRow> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SeriesTable _seriesIdTable(_$AppDatabase db) =>
      db.series.createAlias('episodes__series_id__series__id');

  $$SeriesTableProcessedTableManager get seriesId {
    final $_column = $_itemColumn<int>('series_id')!;

    final manager = $$SeriesTableTableManager(
      $_db,
      $_db.series,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
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

  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stillUrl => $composableBuilder(
    column: $table.stillUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnFilters(column),
  );

  $$SeriesTableFilterComposer get seriesId {
    final $$SeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableFilterComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
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

  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stillUrl => $composableBuilder(
    column: $table.stillUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenRun => $composableBuilder(
    column: $table.seenRun,
    builder: (column) => ColumnOrderings(column),
  );

  $$SeriesTableOrderingComposer get seriesId {
    final $$SeriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableOrderingComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get stillUrl =>
      $composableBuilder(column: $table.stillUrl, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seenRun =>
      $composableBuilder(column: $table.seenRun, builder: (column) => column);

  $$SeriesTableAnnotationComposer get seriesId {
    final $$SeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesTable,
          EpisodeRow,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (EpisodeRow, $$EpisodesTableReferences),
          EpisodeRow,
          PrefetchHooks Function({bool seriesId})
        > {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> seriesId = const Value.absent(),
                Value<String> remoteKey = const Value.absent(),
                Value<int> season = const Value.absent(),
                Value<int> episode = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> stillUrl = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> extrasJson = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                seriesId: seriesId,
                remoteKey: remoteKey,
                season: season,
                episode: episode,
                title: title,
                ext: ext,
                durationSeconds: durationSeconds,
                plot: plot,
                stillUrl: stillUrl,
                streamUrl: streamUrl,
                extrasJson: extrasJson,
                seenRun: seenRun,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int seriesId,
                required String remoteKey,
                required int season,
                required int episode,
                required String title,
                Value<String?> ext = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> stillUrl = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> extrasJson = const Value.absent(),
                Value<int?> seenRun = const Value.absent(),
              }) => EpisodesCompanion.insert(
                id: id,
                seriesId: seriesId,
                remoteKey: remoteKey,
                season: season,
                episode: episode,
                title: title,
                ext: ext,
                durationSeconds: durationSeconds,
                plot: plot,
                stillUrl: stillUrl,
                streamUrl: streamUrl,
                extrasJson: extrasJson,
                seenRun: seenRun,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodesTable, EpisodeRow>(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({seriesId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (seriesId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.seriesId,
                        referencedTable: $$EpisodesTableReferences
                            ._seriesIdTable(db),
                        referencedColumn: $$EpisodesTableReferences
                            ._seriesIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesTable,
      EpisodeRow,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (EpisodeRow, $$EpisodesTableReferences),
      EpisodeRow,
      PrefetchHooks Function({bool seriesId})
    >;
typedef $$CastDevicesTableCreateCompanionBuilder =
    CastDevicesCompanion Function({
      required String deviceId,
      required String name,
      Value<String?> model,
      required String lastHost,
      Value<int> lastPort,
      Value<bool> isManual,
      Value<HevcSupport> hevcSupport,
      Value<String?> learnedJson,
      Value<DateTime?> lastUsedAt,
      Value<int> rowid,
    });
typedef $$CastDevicesTableUpdateCompanionBuilder =
    CastDevicesCompanion Function({
      Value<String> deviceId,
      Value<String> name,
      Value<String?> model,
      Value<String> lastHost,
      Value<int> lastPort,
      Value<bool> isManual,
      Value<HevcSupport> hevcSupport,
      Value<String?> learnedJson,
      Value<DateTime?> lastUsedAt,
      Value<int> rowid,
    });

class $$CastDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $CastDevicesTable> {
  $$CastDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastHost => $composableBuilder(
    column: $table.lastHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPort => $composableBuilder(
    column: $table.lastPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<HevcSupport, HevcSupport, String>
  get hevcSupport => $composableBuilder(
    column: $table.hevcSupport,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get learnedJson => $composableBuilder(
    column: $table.learnedJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CastDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $CastDevicesTable> {
  $$CastDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastHost => $composableBuilder(
    column: $table.lastHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPort => $composableBuilder(
    column: $table.lastPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hevcSupport => $composableBuilder(
    column: $table.hevcSupport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learnedJson => $composableBuilder(
    column: $table.learnedJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CastDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CastDevicesTable> {
  $$CastDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get lastHost =>
      $composableBuilder(column: $table.lastHost, builder: (column) => column);

  GeneratedColumn<int> get lastPort =>
      $composableBuilder(column: $table.lastPort, builder: (column) => column);

  GeneratedColumn<bool> get isManual =>
      $composableBuilder(column: $table.isManual, builder: (column) => column);

  GeneratedColumnWithTypeConverter<HevcSupport, String> get hevcSupport =>
      $composableBuilder(
        column: $table.hevcSupport,
        builder: (column) => column,
      );

  GeneratedColumn<String> get learnedJson => $composableBuilder(
    column: $table.learnedJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );
}

class $$CastDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CastDevicesTable,
          CastDeviceRow,
          $$CastDevicesTableFilterComposer,
          $$CastDevicesTableOrderingComposer,
          $$CastDevicesTableAnnotationComposer,
          $$CastDevicesTableCreateCompanionBuilder,
          $$CastDevicesTableUpdateCompanionBuilder,
          (
            CastDeviceRow,
            BaseReferences<_$AppDatabase, $CastDevicesTable, CastDeviceRow>,
          ),
          CastDeviceRow,
          PrefetchHooks Function()
        > {
  $$CastDevicesTableTableManager(_$AppDatabase db, $CastDevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CastDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CastDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CastDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String> lastHost = const Value.absent(),
                Value<int> lastPort = const Value.absent(),
                Value<bool> isManual = const Value.absent(),
                Value<HevcSupport> hevcSupport = const Value.absent(),
                Value<String?> learnedJson = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CastDevicesCompanion(
                deviceId: deviceId,
                name: name,
                model: model,
                lastHost: lastHost,
                lastPort: lastPort,
                isManual: isManual,
                hevcSupport: hevcSupport,
                learnedJson: learnedJson,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String name,
                Value<String?> model = const Value.absent(),
                required String lastHost,
                Value<int> lastPort = const Value.absent(),
                Value<bool> isManual = const Value.absent(),
                Value<HevcSupport> hevcSupport = const Value.absent(),
                Value<String?> learnedJson = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CastDevicesCompanion.insert(
                deviceId: deviceId,
                name: name,
                model: model,
                lastHost: lastHost,
                lastPort: lastPort,
                isManual: isManual,
                hevcSupport: hevcSupport,
                learnedJson: learnedJson,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CastDevicesTable, CastDeviceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CastDevicesTable,
                    CastDeviceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CastDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CastDevicesTable,
      CastDeviceRow,
      $$CastDevicesTableFilterComposer,
      $$CastDevicesTableOrderingComposer,
      $$CastDevicesTableAnnotationComposer,
      $$CastDevicesTableCreateCompanionBuilder,
      $$CastDevicesTableUpdateCompanionBuilder,
      (
        CastDeviceRow,
        BaseReferences<_$AppDatabase, $CastDevicesTable, CastDeviceRow>,
      ),
      CastDeviceRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(_db, _db.libraryFolders);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$LibraryItemsTableTableManager get libraryItems =>
      $$LibraryItemsTableTableManager(_db, _db.libraryItems);
  $LibraryFtsTableManager get libraryFts =>
      $LibraryFtsTableManager(_db, _db.libraryFts);
  $$FavoriteGroupsTableTableManager get favoriteGroups =>
      $$FavoriteGroupsTableTableManager(_db, _db.favoriteGroups);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$WatchHistoryTableTableManager get watchHistory =>
      $$WatchHistoryTableTableManager(_db, _db.watchHistory);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $ChannelsFtsTableManager get channelsFts =>
      $ChannelsFtsTableManager(_db, _db.channelsFts);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db, _db.movies);
  $MoviesFtsTableManager get moviesFts =>
      $MoviesFtsTableManager(_db, _db.moviesFts);
  $$SeriesTableTableManager get series =>
      $$SeriesTableTableManager(_db, _db.series);
  $SeriesFtsTableManager get seriesFts =>
      $SeriesFtsTableManager(_db, _db.seriesFts);
  $$EpgProgramsTableTableManager get epgPrograms =>
      $$EpgProgramsTableTableManager(_db, _db.epgPrograms);
  $ProgramsFtsTableManager get programsFts =>
      $ProgramsFtsTableManager(_db, _db.programsFts);
  $$EpgImportsTableTableManager get epgImports =>
      $$EpgImportsTableTableManager(_db, _db.epgImports);
  $$EpgChannelsTableTableManager get epgChannels =>
      $$EpgChannelsTableTableManager(_db, _db.epgChannels);
  $$EpgChannelsStagingTableTableManager get epgChannelsStaging =>
      $$EpgChannelsStagingTableTableManager(_db, _db.epgChannelsStaging);
  $$EpgProgramsStagingTableTableManager get epgProgramsStaging =>
      $$EpgProgramsStagingTableTableManager(_db, _db.epgProgramsStaging);
  $$EpgMappingsTableTableManager get epgMappings =>
      $$EpgMappingsTableTableManager(_db, _db.epgMappings);
  $$EpgMatchesTableTableManager get epgMatches =>
      $$EpgMatchesTableTableManager(_db, _db.epgMatches);
  $$SyncRunsTableTableManager get syncRuns =>
      $$SyncRunsTableTableManager(_db, _db.syncRuns);
  $$MovieDetailsTableTableManager get movieDetails =>
      $$MovieDetailsTableTableManager(_db, _db.movieDetails);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$CastDevicesTableTableManager get castDevices =>
      $$CastDevicesTableTableManager(_db, _db.castDevices);
}
