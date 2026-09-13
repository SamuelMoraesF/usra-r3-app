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
  static const VerificationMeta _viaMeta = const VerificationMeta('via');
  @override
  late final GeneratedColumn<String> via = GeneratedColumn<String>(
    'via',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('repeater'),
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
  static const VerificationMeta _operatorGridMeta = const VerificationMeta(
    'operatorGrid',
  );
  @override
  late final GeneratedColumn<String> operatorGrid = GeneratedColumn<String>(
    'operator_grid',
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
  static const VerificationMeta _trafficMessageMeta = const VerificationMeta(
    'trafficMessage',
  );
  @override
  late final GeneratedColumn<String> trafficMessage = GeneratedColumn<String>(
    'traffic_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    callsign,
    via,
    frequency,
    operatorName,
    location,
    operatorGrid,
    powerWatts,
    stationType,
    traffic,
    trafficMessage,
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
    if (data.containsKey('via')) {
      context.handle(
        _viaMeta,
        via.isAcceptableOrUnknown(data['via']!, _viaMeta),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
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
    if (data.containsKey('operator_grid')) {
      context.handle(
        _operatorGridMeta,
        operatorGrid.isAcceptableOrUnknown(
          data['operator_grid']!,
          _operatorGridMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operatorGridMeta);
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
    if (data.containsKey('traffic_message')) {
      context.handle(
        _trafficMessageMeta,
        trafficMessage.isAcceptableOrUnknown(
          data['traffic_message']!,
          _trafficMessageMeta,
        ),
      );
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
      via: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}via'],
      )!,
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      operatorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operator_name'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      operatorGrid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operator_grid'],
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
      trafficMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}traffic_message'],
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
  final String via;
  final String frequency;
  final String operatorName;
  final String location;
  final String operatorGrid;
  final double powerWatts;
  final String stationType;
  final String traffic;
  final String trafficMessage;
  const LogEntry({
    required this.id,
    required this.createdAt,
    required this.callsign,
    required this.via,
    required this.frequency,
    required this.operatorName,
    required this.location,
    required this.operatorGrid,
    required this.powerWatts,
    required this.stationType,
    required this.traffic,
    required this.trafficMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['callsign'] = Variable<String>(callsign);
    map['via'] = Variable<String>(via);
    map['frequency'] = Variable<String>(frequency);
    map['operator_name'] = Variable<String>(operatorName);
    map['location'] = Variable<String>(location);
    map['operator_grid'] = Variable<String>(operatorGrid);
    map['power_watts'] = Variable<double>(powerWatts);
    map['station_type'] = Variable<String>(stationType);
    map['traffic'] = Variable<String>(traffic);
    map['traffic_message'] = Variable<String>(trafficMessage);
    return map;
  }

  LogEntriesCompanion toCompanion(bool nullToAbsent) {
    return LogEntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      callsign: Value(callsign),
      via: Value(via),
      frequency: Value(frequency),
      operatorName: Value(operatorName),
      location: Value(location),
      operatorGrid: Value(operatorGrid),
      powerWatts: Value(powerWatts),
      stationType: Value(stationType),
      traffic: Value(traffic),
      trafficMessage: Value(trafficMessage),
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
      via: serializer.fromJson<String>(json['via']),
      frequency: serializer.fromJson<String>(json['frequency']),
      operatorName: serializer.fromJson<String>(json['operatorName']),
      location: serializer.fromJson<String>(json['location']),
      operatorGrid: serializer.fromJson<String>(json['operatorGrid']),
      powerWatts: serializer.fromJson<double>(json['powerWatts']),
      stationType: serializer.fromJson<String>(json['stationType']),
      traffic: serializer.fromJson<String>(json['traffic']),
      trafficMessage: serializer.fromJson<String>(json['trafficMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'callsign': serializer.toJson<String>(callsign),
      'via': serializer.toJson<String>(via),
      'frequency': serializer.toJson<String>(frequency),
      'operatorName': serializer.toJson<String>(operatorName),
      'location': serializer.toJson<String>(location),
      'operatorGrid': serializer.toJson<String>(operatorGrid),
      'powerWatts': serializer.toJson<double>(powerWatts),
      'stationType': serializer.toJson<String>(stationType),
      'traffic': serializer.toJson<String>(traffic),
      'trafficMessage': serializer.toJson<String>(trafficMessage),
    };
  }

  LogEntry copyWith({
    int? id,
    DateTime? createdAt,
    String? callsign,
    String? via,
    String? frequency,
    String? operatorName,
    String? location,
    String? operatorGrid,
    double? powerWatts,
    String? stationType,
    String? traffic,
    String? trafficMessage,
  }) => LogEntry(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    callsign: callsign ?? this.callsign,
    via: via ?? this.via,
    frequency: frequency ?? this.frequency,
    operatorName: operatorName ?? this.operatorName,
    location: location ?? this.location,
    operatorGrid: operatorGrid ?? this.operatorGrid,
    powerWatts: powerWatts ?? this.powerWatts,
    stationType: stationType ?? this.stationType,
    traffic: traffic ?? this.traffic,
    trafficMessage: trafficMessage ?? this.trafficMessage,
  );
  LogEntry copyWithCompanion(LogEntriesCompanion data) {
    return LogEntry(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      callsign: data.callsign.present ? data.callsign.value : this.callsign,
      via: data.via.present ? data.via.value : this.via,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      operatorName: data.operatorName.present
          ? data.operatorName.value
          : this.operatorName,
      location: data.location.present ? data.location.value : this.location,
      operatorGrid: data.operatorGrid.present
          ? data.operatorGrid.value
          : this.operatorGrid,
      powerWatts: data.powerWatts.present
          ? data.powerWatts.value
          : this.powerWatts,
      stationType: data.stationType.present
          ? data.stationType.value
          : this.stationType,
      traffic: data.traffic.present ? data.traffic.value : this.traffic,
      trafficMessage: data.trafficMessage.present
          ? data.trafficMessage.value
          : this.trafficMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogEntry(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('callsign: $callsign, ')
          ..write('via: $via, ')
          ..write('frequency: $frequency, ')
          ..write('operatorName: $operatorName, ')
          ..write('location: $location, ')
          ..write('operatorGrid: $operatorGrid, ')
          ..write('powerWatts: $powerWatts, ')
          ..write('stationType: $stationType, ')
          ..write('traffic: $traffic, ')
          ..write('trafficMessage: $trafficMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    callsign,
    via,
    frequency,
    operatorName,
    location,
    operatorGrid,
    powerWatts,
    stationType,
    traffic,
    trafficMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogEntry &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.callsign == this.callsign &&
          other.via == this.via &&
          other.frequency == this.frequency &&
          other.operatorName == this.operatorName &&
          other.location == this.location &&
          other.operatorGrid == this.operatorGrid &&
          other.powerWatts == this.powerWatts &&
          other.stationType == this.stationType &&
          other.traffic == this.traffic &&
          other.trafficMessage == this.trafficMessage);
}

class LogEntriesCompanion extends UpdateCompanion<LogEntry> {
  final Value<int> id;
  final Value<DateTime> createdAt;
  final Value<String> callsign;
  final Value<String> via;
  final Value<String> frequency;
  final Value<String> operatorName;
  final Value<String> location;
  final Value<String> operatorGrid;
  final Value<double> powerWatts;
  final Value<String> stationType;
  final Value<String> traffic;
  final Value<String> trafficMessage;
  const LogEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.callsign = const Value.absent(),
    this.via = const Value.absent(),
    this.frequency = const Value.absent(),
    this.operatorName = const Value.absent(),
    this.location = const Value.absent(),
    this.operatorGrid = const Value.absent(),
    this.powerWatts = const Value.absent(),
    this.stationType = const Value.absent(),
    this.traffic = const Value.absent(),
    this.trafficMessage = const Value.absent(),
  });
  LogEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime createdAt,
    required String callsign,
    this.via = const Value.absent(),
    this.frequency = const Value.absent(),
    required String operatorName,
    required String location,
    required String operatorGrid,
    required double powerWatts,
    required String stationType,
    required String traffic,
    this.trafficMessage = const Value.absent(),
  }) : createdAt = Value(createdAt),
       callsign = Value(callsign),
       operatorName = Value(operatorName),
       location = Value(location),
       operatorGrid = Value(operatorGrid),
       powerWatts = Value(powerWatts),
       stationType = Value(stationType),
       traffic = Value(traffic);
  static Insertable<LogEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? callsign,
    Expression<String>? via,
    Expression<String>? frequency,
    Expression<String>? operatorName,
    Expression<String>? location,
    Expression<String>? operatorGrid,
    Expression<double>? powerWatts,
    Expression<String>? stationType,
    Expression<String>? traffic,
    Expression<String>? trafficMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (callsign != null) 'callsign': callsign,
      if (via != null) 'via': via,
      if (frequency != null) 'frequency': frequency,
      if (operatorName != null) 'operator_name': operatorName,
      if (location != null) 'location': location,
      if (operatorGrid != null) 'operator_grid': operatorGrid,
      if (powerWatts != null) 'power_watts': powerWatts,
      if (stationType != null) 'station_type': stationType,
      if (traffic != null) 'traffic': traffic,
      if (trafficMessage != null) 'traffic_message': trafficMessage,
    });
  }

  LogEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? createdAt,
    Value<String>? callsign,
    Value<String>? via,
    Value<String>? frequency,
    Value<String>? operatorName,
    Value<String>? location,
    Value<String>? operatorGrid,
    Value<double>? powerWatts,
    Value<String>? stationType,
    Value<String>? traffic,
    Value<String>? trafficMessage,
  }) {
    return LogEntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      callsign: callsign ?? this.callsign,
      via: via ?? this.via,
      frequency: frequency ?? this.frequency,
      operatorName: operatorName ?? this.operatorName,
      location: location ?? this.location,
      operatorGrid: operatorGrid ?? this.operatorGrid,
      powerWatts: powerWatts ?? this.powerWatts,
      stationType: stationType ?? this.stationType,
      traffic: traffic ?? this.traffic,
      trafficMessage: trafficMessage ?? this.trafficMessage,
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
    if (via.present) {
      map['via'] = Variable<String>(via.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (operatorName.present) {
      map['operator_name'] = Variable<String>(operatorName.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (operatorGrid.present) {
      map['operator_grid'] = Variable<String>(operatorGrid.value);
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
    if (trafficMessage.present) {
      map['traffic_message'] = Variable<String>(trafficMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('callsign: $callsign, ')
          ..write('via: $via, ')
          ..write('frequency: $frequency, ')
          ..write('operatorName: $operatorName, ')
          ..write('location: $location, ')
          ..write('operatorGrid: $operatorGrid, ')
          ..write('powerWatts: $powerWatts, ')
          ..write('stationType: $stationType, ')
          ..write('traffic: $traffic, ')
          ..write('trafficMessage: $trafficMessage')
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
      Value<String> via,
      Value<String> frequency,
      required String operatorName,
      required String location,
      required String operatorGrid,
      required double powerWatts,
      required String stationType,
      required String traffic,
      Value<String> trafficMessage,
    });
typedef $$LogEntriesTableUpdateCompanionBuilder =
    LogEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> createdAt,
      Value<String> callsign,
      Value<String> via,
      Value<String> frequency,
      Value<String> operatorName,
      Value<String> location,
      Value<String> operatorGrid,
      Value<double> powerWatts,
      Value<String> stationType,
      Value<String> traffic,
      Value<String> trafficMessage,
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

  ColumnFilters<String> get via => $composableBuilder(
    column: $table.via,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
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

  ColumnFilters<String> get operatorGrid => $composableBuilder(
    column: $table.operatorGrid,
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

  ColumnFilters<String> get trafficMessage => $composableBuilder(
    column: $table.trafficMessage,
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

  ColumnOrderings<String> get via => $composableBuilder(
    column: $table.via,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
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

  ColumnOrderings<String> get operatorGrid => $composableBuilder(
    column: $table.operatorGrid,
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

  ColumnOrderings<String> get trafficMessage => $composableBuilder(
    column: $table.trafficMessage,
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

  GeneratedColumn<String> get via =>
      $composableBuilder(column: $table.via, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get operatorName => $composableBuilder(
    column: $table.operatorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get operatorGrid => $composableBuilder(
    column: $table.operatorGrid,
    builder: (column) => column,
  );

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

  GeneratedColumn<String> get trafficMessage => $composableBuilder(
    column: $table.trafficMessage,
    builder: (column) => column,
  );
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
                Value<String> via = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<String> operatorName = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> operatorGrid = const Value.absent(),
                Value<double> powerWatts = const Value.absent(),
                Value<String> stationType = const Value.absent(),
                Value<String> traffic = const Value.absent(),
                Value<String> trafficMessage = const Value.absent(),
              }) => LogEntriesCompanion(
                id: id,
                createdAt: createdAt,
                callsign: callsign,
                via: via,
                frequency: frequency,
                operatorName: operatorName,
                location: location,
                operatorGrid: operatorGrid,
                powerWatts: powerWatts,
                stationType: stationType,
                traffic: traffic,
                trafficMessage: trafficMessage,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime createdAt,
                required String callsign,
                Value<String> via = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                required String operatorName,
                required String location,
                required String operatorGrid,
                required double powerWatts,
                required String stationType,
                required String traffic,
                Value<String> trafficMessage = const Value.absent(),
              }) => LogEntriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                callsign: callsign,
                via: via,
                frequency: frequency,
                operatorName: operatorName,
                location: location,
                operatorGrid: operatorGrid,
                powerWatts: powerWatts,
                stationType: stationType,
                traffic: traffic,
                trafficMessage: trafficMessage,
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
