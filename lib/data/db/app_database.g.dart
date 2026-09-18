// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
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

  /// The Xtream server base URL, the playlist URL, or the local file path,
  /// depending on [type].
  final String url;

  /// Xtream only. Not a secret, but it never reaches a log unredacted.
  final String? username;

  /// The flutter_secure_storage key holding this source's password.
  final String? credentialRef;

  /// Overrides the XMLTV URL the provider advertises.
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
  List<GeneratedColumn> get $columns => [name, displayName];
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
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
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
      'fts5(name, display_name, content=\'channels\', content_rowid=\'id\', tokenize=\'unicode61 remove_diacritics 2\', prefix=\'2 3\')';
}

class ChannelsFt extends DataClass implements Insertable<ChannelsFt> {
  final String name;
  final String displayName;
  const ChannelsFt({required this.name, required this.displayName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['display_name'] = Variable<String>(displayName);
    return map;
  }

  ChannelsFtsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsFtsCompanion(
      name: Value(name),
      displayName: Value(displayName),
    );
  }

  factory ChannelsFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelsFt(
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String>(json['display_name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'display_name': serializer.toJson<String>(displayName),
    };
  }

  ChannelsFt copyWith({String? name, String? displayName}) => ChannelsFt(
    name: name ?? this.name,
    displayName: displayName ?? this.displayName,
  );
  ChannelsFt copyWithCompanion(ChannelsFtsCompanion data) {
    return ChannelsFt(
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsFt(')
          ..write('name: $name, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, displayName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelsFt &&
          other.name == this.name &&
          other.displayName == this.displayName);
}

class ChannelsFtsCompanion extends UpdateCompanion<ChannelsFt> {
  final Value<String> name;
  final Value<String> displayName;
  final Value<int> rowid;
  const ChannelsFtsCompanion({
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsFtsCompanion.insert({
    required String name,
    required String displayName,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       displayName = Value(displayName);
  static Insertable<ChannelsFt> custom({
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsFtsCompanion copyWith({
    Value<String>? name,
    Value<String>? displayName,
    Value<int>? rowid,
  }) {
    return ChannelsFtsCompanion(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
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
          ..write('name: $name, ')
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
    Value<String?> countsJson = const Value.absent(),
  }) => SyncRunRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    outcome: outcome ?? this.outcome,
    failure: failure.present ? failure.value : this.failure,
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
          other.countsJson == this.countsJson);
}

class SyncRunsCompanion extends UpdateCompanion<SyncRunRow> {
  final Value<int> id;
  final Value<String> sourceId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<SyncOutcome> outcome;
  final Value<String?> failure;
  final Value<String?> countsJson;
  const SyncRunsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.failure = const Value.absent(),
    this.countsJson = const Value.absent(),
  });
  SyncRunsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceId,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.failure = const Value.absent(),
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
    Expression<String>? countsJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (outcome != null) 'outcome': outcome,
      if (failure != null) 'failure': failure,
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
    Value<String?>? countsJson,
  }) {
    return SyncRunsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      outcome: outcome ?? this.outcome,
      failure: failure ?? this.failure,
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
  final DateTime fetchedAt;
  const MovieDetailsRow({
    required this.movieId,
    this.plot,
    this.castNames,
    this.director,
    this.genre,
    this.runtimeMinutes,
    this.backdropUrl,
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
  final Value<DateTime> fetchedAt;
  const MovieDetailsCompanion({
    this.movieId = const Value.absent(),
    this.plot = const Value.absent(),
    this.castNames = const Value.absent(),
    this.director = const Value.absent(),
    this.genre = const Value.absent(),
    this.runtimeMinutes = const Value.absent(),
    this.backdropUrl = const Value.absent(),
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final ChannelsFts channelsFts = ChannelsFts(this);
  late final Trigger channelsFtsInsert = Trigger(
    'CREATE TRIGGER channels_fts_insert AFTER INSERT ON channels BEGIN INSERT INTO channels_fts ("rowid", name, display_name) VALUES (new.id, new.name, new.display_name);END',
    'channels_fts_insert',
  );
  late final Trigger channelsFtsDelete = Trigger(
    'CREATE TRIGGER channels_fts_delete AFTER DELETE ON channels BEGIN INSERT INTO channels_fts (channels_fts, "rowid", name, display_name) VALUES (\'delete\', old.id, old.name, old.display_name);END',
    'channels_fts_delete',
  );
  late final Trigger channelsFtsUpdate = Trigger(
    'CREATE TRIGGER channels_fts_update AFTER UPDATE OF name, display_name ON channels WHEN old.name IS NOT new.name OR old.display_name IS NOT new.display_name BEGIN INSERT INTO channels_fts (channels_fts, "rowid", name, display_name) VALUES (\'delete\', old.id, old.name, old.display_name);INSERT INTO channels_fts ("rowid", name, display_name) VALUES (new.id, new.name, new.display_name);END',
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
  late final Index seriesCategory = Index(
    'series_category',
    'CREATE INDEX series_category ON series (category_id)',
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final SourcesDao sourcesDao = SourcesDao(this as AppDatabase);
  late final SyncRunsDao syncRunsDao = SyncRunsDao(this as AppDatabase);
  late final CategoriesDao categoriesDao = CategoriesDao(this as AppDatabase);
  late final ChannelsDao channelsDao = ChannelsDao(this as AppDatabase);
  late final MoviesDao moviesDao = MoviesDao(this as AppDatabase);
  late final SeriesDao seriesDao = SeriesDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sources,
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
    syncRuns,
    movieDetails,
    episodes,
    categoriesSourceKind,
    channelsCategory,
    moviesCategory,
    seriesCategory,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
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
            bool categoriesRefs,
            bool channelsRefs,
            bool moviesRefs,
            bool seriesRefs,
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
                categoriesRefs = false,
                channelsRefs = false,
                moviesRefs = false,
                seriesRefs = false,
                syncRunsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (categoriesRefs) db.categories,
                    if (channelsRefs) db.channels,
                    if (moviesRefs) db.movies,
                    if (seriesRefs) db.series,
                    if (syncRunsRefs) db.syncRuns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
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
        bool categoriesRefs,
        bool channelsRefs,
        bool moviesRefs,
        bool seriesRefs,
        bool syncRunsRefs,
      })
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
          PrefetchHooks Function({bool sourceId, bool categoryId})
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
          prefetchHooksCallback: ({sourceId = false, categoryId = false}) {
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
                return [];
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
      PrefetchHooks Function({bool sourceId, bool categoryId})
    >;
typedef $ChannelsFtsCreateCompanionBuilder = ChannelsFtsCompanion Function({
  required String name,
  required String displayName,
  Value<int> rowid,
});
typedef $ChannelsFtsUpdateCompanionBuilder = ChannelsFtsCompanion Function({
  Value<String> name,
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
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
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
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
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
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

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
                Value<String> name = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsFtsCompanion(
                name: name,
                displayName: displayName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required String displayName,
                Value<int> rowid = const Value.absent(),
              }) => ChannelsFtsCompanion.insert(
                name: name,
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
typedef $$SyncRunsTableCreateCompanionBuilder = SyncRunsCompanion Function({
  Value<int> id,
  required String sourceId,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  Value<SyncOutcome> outcome,
  Value<String?> failure,
  Value<String?> countsJson,
});
typedef $$SyncRunsTableUpdateCompanionBuilder = SyncRunsCompanion Function({
  Value<int> id,
  Value<String> sourceId,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<SyncOutcome> outcome,
  Value<String?> failure,
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
                Value<String?> countsJson = const Value.absent(),
              }) => SyncRunsCompanion(
                id: id,
                sourceId: sourceId,
                startedAt: startedAt,
                finishedAt: finishedAt,
                outcome: outcome,
                failure: failure,
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
                Value<String?> countsJson = const Value.absent(),
              }) => SyncRunsCompanion.insert(
                id: id,
                sourceId: sourceId,
                startedAt: startedAt,
                finishedAt: finishedAt,
                outcome: outcome,
                failure: failure,
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
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => MovieDetailsCompanion(
                movieId: movieId,
                plot: plot,
                castNames: castNames,
                director: director,
                genre: genre,
                runtimeMinutes: runtimeMinutes,
                backdropUrl: backdropUrl,
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
                required DateTime fetchedAt,
              }) => MovieDetailsCompanion.insert(
                movieId: movieId,
                plot: plot,
                castNames: castNames,
                director: director,
                genre: genre,
                runtimeMinutes: runtimeMinutes,
                backdropUrl: backdropUrl,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
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
  $$SyncRunsTableTableManager get syncRuns =>
      $$SyncRunsTableTableManager(_db, _db.syncRuns);
  $$MovieDetailsTableTableManager get movieDetails =>
      $$MovieDetailsTableTableManager(_db, _db.movieDetails);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
