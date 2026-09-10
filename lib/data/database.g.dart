// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LogEntriesTable extends LogEntries
    with TableInfo<$LogEntriesTable, LogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _callsignMeta = const VerificationMeta(
    'callsign',
  );
  @override
  late final GeneratedColumn<String> callsign = GeneratedColumn<String>(
    'callsign',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operatorNameMeta = const VerificationMeta(
    'operatorName',
  );
  @override
  late final GeneratedColumn<String> operatorName = GeneratedColumn<String>(
    'operator_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _powerWattsMeta = const VerificationMeta(
    'powerWatts',
  );
  @override
  late final GeneratedColumn<double> powerWatts = GeneratedColumn<double>(
    'power_watts',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stationTypeMeta = const VerificationMeta(
    'stationType',
  );
  @override
  late final GeneratedColumn<String> stationType = GeneratedColumn<String>(
    'station_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trafficMeta = const VerificationMeta(
    'traffic',
  );
  @override
  late final GeneratedColumn<String> traffic = GeneratedColumn<String>(
    'traffic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    callsign,
    operatorName,
    location,
    powerWatts,
    stationType,
    traffic,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('callsign')) {
      context.handle(
        _callsignMeta,
        callsign.isAcceptableOrUnknown(data['callsign']!, _callsignMeta),
      );
    } else if (isInserting) {
      context.missing(_callsignMeta);
    }
    if (data.containsKey('operator_name')) {
      context.handle(
        _operatorNameMeta,
        operatorName.isAcceptableOrUnknown(
          data['operator_name']!,
          _operatorNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operatorNameMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('power_watts')) {
      context.handle(
        _powerWattsMeta,
        powerWatts.isAcceptableOrUnknown(data['power_watts']!, _powerWattsMeta),
      );
    } else if (isInserting) {
      context.missing(_powerWattsMeta);
    }
    if (data.containsKey('station_type')) {
      context.handle(
        _stationTypeMeta,
        stationType.isAcceptableOrUnknown(
          data['station_type']!,
          _stationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stationTypeMeta);
    }
    if (data.containsKey('traffic')) {
      context.handle(
        _trafficMeta,
        traffic.isAcceptableOrUnknown(data['traffic']!, _trafficMeta),
      );
    } else if (isInserting) {
      context.missing(_trafficMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      callsign: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}callsign'],
      )!,
      operatorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operator_name'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      powerWatts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}power_watts'],
      )!,
      stationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station_type'],
      )!,
      traffic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}traffic'],
      )!,
    );
  }

  @override
  $LogEntriesTable createAlias(String alias) {
    return $LogEntriesTable(attachedDatabase, alias);
  }
}

class LogEntry extends DataClass implements Insertable<LogEntry> {
  final int id;
  final DateTime createdAt;
  final String callsign;
  final String operatorName;
  final String location;
  final double powerWatts;
  final String stationType;
  final String traffic;
  const LogEntry({
    required this.id,
    required this.createdAt,
    required this.callsign,
    required this.operatorName,
    required this.location,
    required this.powerWatts,
    required this.stationType,
    required this.traffic,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['callsign'] = Variable<String>(callsign);
    map['operator_name'] = Variable<String>(operatorName);
    map['location'] = Variable<String>(location);
    map['power_watts'] = Variable<double>(powerWatts);
    map['station_type'] = Variable<String>(stationType);
    map['traffic'] = Variable<String>(traffic);
    return map;
  }

  LogEntriesCompanion toCompanion(bool nullToAbsent) {
    return LogEntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      callsign: Value(callsign),
      operatorName: Value(operatorName),
      location: Value(location),
      powerWatts: Value(powerWatts),
      stationType: Value(stationType),
      traffic: Value(traffic),
    );
  }

  factory LogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogEntry(
      id: serializer.fromJson<int>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      callsign: serializer.fromJson<String>(json['callsign']),
      operatorName: serializer.fromJson<String>(json['operatorName']),
      location: serializer.fromJson<String>(json['location']),
      powerWatts: serializer.fromJson<double>(json['powerWatts']),
      stationType: serializer.fromJson<String>(json['stationType']),
      traffic: serializer.fromJson<String>(json['traffic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'callsign': serializer.toJson<String>(callsign),
      'operatorName': serializer.toJson<String>(operatorName),
      'location': serializer.toJson<String>(location),
      'powerWatts': serializer.toJson<double>(powerWatts),
      'stationType': serializer.toJson<String>(stationType),
      'traffic': serializer.toJson<String>(traffic),
    };
  }

  LogEntry copyWith({
    int? id,
    DateTime? createdAt,
    String? callsign,
    String? operatorName,
    String? location,
    double? powerWatts,
    String? stationType,
    String? traffic,
  }) => LogEntry(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    callsign: callsign ?? this.callsign,
    operatorName: operatorName ?? this.operatorName,
    location: location ?? this.location,
    powerWatts: powerWatts ?? this.powerWatts,
    stationType: stationType ?? this.stationType,
    traffic: traffic ?? this.traffic,
  );
  LogEntry copyWithCompanion(LogEntriesCompanion data) {
    return LogEntry(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      callsign: data.callsign.present ? data.callsign.value : this.callsign,
      operatorName: data.operatorName.present
          ? data.operatorName.value
          : this.operatorName,
      location: data.location.present ? data.location.value : this.location,
      powerWatts: data.powerWatts.present
          ? data.powerWatts.value
          : this.powerWatts,
      stationType: data.stationType.present
          ? data.stationType.value
          : this.stationType,
      traffic: data.traffic.present ? data.traffic.value : this.traffic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogEntry(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('callsign: $callsign, ')
          ..write('operatorName: $operatorName, ')
          ..write('location: $location, ')
          ..write('powerWatts: $powerWatts, ')
          ..write('stationType: $stationType, ')
          ..write('traffic: $traffic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    callsign,
    operatorName,
    location,
    powerWatts,
    stationType,
    traffic,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogEntry &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.callsign == this.callsign &&
          other.operatorName == this.operatorName &&
          other.location == this.location &&
          other.powerWatts == this.powerWatts &&
          other.stationType == this.stationType &&
          other.traffic == this.traffic);
}

class LogEntriesCompanion extends UpdateCompanion<LogEntry> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> callsign;
  final Value<String> operatorName;
  final Value<String> location;
  final Value<double> powerWatts;
  final Value<String> stationType;
  final Value<String> traffic;
  const LogEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.callsign = const Value.absent(),
    this.operatorName = const Value.absent(),
    this.location = const Value.absent(),
    this.powerWatts = const Value.absent(),
    this.stationType = const Value.absent(),
    this.traffic = const Value.absent(),
  });
  LogEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdAt,
    required String callsign,
    required String operatorName,
    required String location,
    required double powerWatts,
    required String stationType,
    required String traffic,
  }) : createdAt = Value(createdAt),
       callsign = Value(callsign),
       operatorName = Value(operatorName),
       location = Value(location),
       powerWatts = Value(powerWatts),
       stationType = Value(stationType),
       traffic = Value(traffic);
  static Insertable<LogEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? callsign,
    Expression<String>? operatorName,
    Expression<String>? location,
    Expression<double>? powerWatts,
    Expression<String>? stationType,
    Expression<String>? traffic,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (callsign != null) 'callsign': callsign,
      if (operatorName != null) 'operator_name': operatorName,
      if (location != null) 'location': location,
      if (powerWatts != null) 'power_watts': powerWatts,
      if (stationType != null) 'station_type': stationType,
      if (traffic != null) 'traffic': traffic,
    });
  }

  LogEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<String>? callsign,
    Value<String>? operatorName,
    Value<String>? location,
    Value<double>? powerWatts,
    Value<String>? stationType,
    Value<String>? traffic,
  }) {
    return LogEntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      callsign: callsign ?? this.callsign,
      operatorName: operatorName ?? this.operatorName,
      location: location ?? this.location,
      powerWatts: powerWatts ?? this.powerWatts,
      stationType: stationType ?? this.stationType,
      traffic: traffic ?? this.traffic,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (callsign.present) {
      map['callsign'] = Variable<String>(callsign.value);
    }
    if (operatorName.present) {
      map['operator_name'] = Variable<String>(operatorName.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (powerWatts.present) {
      map['power_watts'] = Variable<double>(powerWatts.value);
    }
    if (stationType.present) {
      map['station_type'] = Variable<String>(stationType.value);
    }
    if (traffic.present) {
      map['traffic'] = Variable<String>(traffic.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('callsign: $callsign, ')
          ..write('operatorName: $operatorName, ')
          ..write('location: $location, ')
          ..write('powerWatts: $powerWatts, ')
          ..write('stationType: $stationType, ')
          ..write('traffic: $traffic')
          ..write(')'))
        .toString();
  }
}

abstract class _$UsraDatabase extends GeneratedDatabase {
  _$UsraDatabase(QueryExecutor e) : super(e);
  $UsraDatabaseManager get managers => $UsraDatabaseManager(this);
  late final $LogEntriesTable logEntries = $LogEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [logEntries];
}

typedef $$LogEntriesTableCreateCompanionBuilder =
    LogEntriesCompanion Function({
      Value<int> id,
      required DateTime createdAt,
      required String callsign,
      required String operatorName,
      required String location,
      required double powerWatts,
      required String stationType,
      required String traffic,
    });
typedef $$LogEntriesTableUpdateCompanionBuilder =
    LogEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<String> callsign,
      Value<String> operatorName,
      Value<String> location,
      Value<double> powerWatts,
      Value<String> stationType,
      Value<String> traffic,
    });

class $$LogEntriesTableFilterComposer
    extends Composer<_$UsraDatabase, $LogEntriesTable> {
  $$LogEntriesTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get callsign => $composableBuilder(
    column: $table.callsign,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operatorName => $composableBuilder(
    column: $table.operatorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get powerWatts => $composableBuilder(
    column: $table.powerWatts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stationType => $composableBuilder(
    column: $table.stationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get traffic => $composableBuilder(
    column: $table.traffic,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LogEntriesTableOrderingComposer
    extends Composer<_$UsraDatabase, $LogEntriesTable> {
  $$LogEntriesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get callsign => $composableBuilder(
    column: $table.callsign,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operatorName => $composableBuilder(
    column: $table.operatorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get powerWatts => $composableBuilder(
    column: $table.powerWatts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stationType => $composableBuilder(
    column: $table.stationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get traffic => $composableBuilder(
    column: $table.traffic,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LogEntriesTableAnnotationComposer
    extends Composer<_$UsraDatabase, $LogEntriesTable> {
  $$LogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get callsign =>
      $composableBuilder(column: $table.callsign, builder: (column) => column);

  GeneratedColumn<String> get operatorName => $composableBuilder(
    column: $table.operatorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<double> get powerWatts => $composableBuilder(
    column: $table.powerWatts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stationType => $composableBuilder(
    column: $table.stationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get traffic =>
      $composableBuilder(column: $table.traffic, builder: (column) => column);
}

class $$LogEntriesTableTableManager
    extends
        RootTableManager<
          _$UsraDatabase,
          $LogEntriesTable,
          LogEntry,
          $$LogEntriesTableFilterComposer,
          $$LogEntriesTableOrderingComposer,
          $$LogEntriesTableAnnotationComposer,
          $$LogEntriesTableCreateCompanionBuilder,
          $$LogEntriesTableUpdateCompanionBuilder,
          (
            LogEntry,
            BaseReferences<_$UsraDatabase, $LogEntriesTable, LogEntry>,
          ),
          LogEntry,
          PrefetchHooks Function()
        > {
  $$LogEntriesTableTableManager(_$UsraDatabase db, $LogEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> callsign = const Value.absent(),
                Value<String> operatorName = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<double> powerWatts = const Value.absent(),
                Value<String> stationType = const Value.absent(),
                Value<String> traffic = const Value.absent(),
              }) => LogEntriesCompanion(
                id: id,
                createdAt: createdAt,
                callsign: callsign,
                operatorName: operatorName,
                location: location,
                powerWatts: powerWatts,
                stationType: stationType,
                traffic: traffic,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime createdAt,
                required String callsign,
                required String operatorName,
                required String location,
                required double powerWatts,
                required String stationType,
                required String traffic,
              }) => LogEntriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                callsign: callsign,
                operatorName: operatorName,
                location: location,
                powerWatts: powerWatts,
                stationType: stationType,
                traffic: traffic,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LogEntriesTable, LogEntry>(table),
                  BaseReferences<_$UsraDatabase, $LogEntriesTable, LogEntry>(
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

typedef $$LogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$UsraDatabase,
      $LogEntriesTable,
      LogEntry,
      $$LogEntriesTableFilterComposer,
      $$LogEntriesTableOrderingComposer,
      $$LogEntriesTableAnnotationComposer,
      $$LogEntriesTableCreateCompanionBuilder,
      $$LogEntriesTableUpdateCompanionBuilder,
      (LogEntry, BaseReferences<_$UsraDatabase, $LogEntriesTable, LogEntry>),
      LogEntry,
      PrefetchHooks Function()
    >;

class $UsraDatabaseManager {
  final _$UsraDatabase _db;
  $UsraDatabaseManager(this._db);
  $$LogEntriesTableTableManager get logEntries =>
      $$LogEntriesTableTableManager(_db, _db.logEntries);
}
