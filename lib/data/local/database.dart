import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Persons extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get namePinyin => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get clock => integer().withDefault(const Constant(0))();
  TextColumn get originDeviceId => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FavorRecords extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text()();
  TextColumn get direction => text()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get event => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get clock => integer().withDefault(const Constant(0))();
  TextColumn get originDeviceId => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Persons, FavorRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(persons, persons.clock);
            await m.addColumn(persons, persons.originDeviceId);
            await m.addColumn(favorRecords, favorRecords.clock);
            await m.addColumn(favorRecords, favorRecords.originDeviceId);
          }
        },
      );

  static QueryExecutor _open() {
    return driftDatabase(name: 'favor_ledger');
  }

  Stream<List<Person>> watchActivePersons() {
    return (select(persons)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.namePinyin)]))
        .watch();
  }

  Stream<void> watchLedgerChanges() {
    final query = select(persons).join([
      leftOuterJoin(
        favorRecords,
        favorRecords.personId.equalsExp(persons.id),
      ),
    ]);
    return query.watch().map((_) {});
  }

  Future<List<Person>> getActivePersons() {
    return (select(persons)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.namePinyin)]))
        .get();
  }

  Future<List<Person>> getAllPersonsIncludingDeleted() => select(persons).get();

  Future<Person?> getPerson(String id) {
    return (select(persons)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Person?> watchPerson(String id) {
    return (select(persons)..where((t) => t.id.equals(id)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<void> upsertPerson(PersonsCompanion companion) {
    return into(persons).insertOnConflictUpdate(companion);
  }

  Future<void> softDeletePerson({
    required String id,
    required DateTime at,
    required int clock,
    required String originDeviceId,
  }) async {
    await (update(persons)..where((t) => t.id.equals(id))).write(
      PersonsCompanion(
        deletedAt: Value(at),
        updatedAt: Value(at),
        clock: Value(clock),
        originDeviceId: Value(originDeviceId),
      ),
    );
    await (update(favorRecords)
          ..where((t) => t.personId.equals(id) & t.deletedAt.isNull()))
        .write(
      FavorRecordsCompanion(
        deletedAt: Value(at),
        updatedAt: Value(at),
        clock: Value(clock),
        originDeviceId: Value(originDeviceId),
      ),
    );
  }

  Stream<List<FavorRecord>> watchRecordsForPerson(String personId) {
    return (select(favorRecords)
          ..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.occurredAt),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Stream<List<TypedResult>> watchFlowJoined() {
    final query = select(favorRecords).join([
      innerJoin(persons, persons.id.equalsExp(favorRecords.personId)),
    ])
      ..where(favorRecords.deletedAt.isNull() & persons.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.desc(favorRecords.occurredAt),
        OrderingTerm.desc(favorRecords.createdAt),
      ]);
    return query.watch();
  }

  Stream<List<FavorRecord>> watchActiveRecords() {
    return (select(favorRecords)..where((t) => t.deletedAt.isNull())).watch();
  }

  Future<List<FavorRecord>> getActiveRecords() {
    return (select(favorRecords)..where((t) => t.deletedAt.isNull())).get();
  }

  Future<List<FavorRecord>> getAllRecordsIncludingDeleted() =>
      select(favorRecords).get();

  Future<FavorRecord?> getRecord(String id) {
    return (select(favorRecords)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertRecord(FavorRecordsCompanion companion) {
    return into(favorRecords).insertOnConflictUpdate(companion);
  }

  Future<void> softDeleteRecord({
    required String id,
    required DateTime at,
    required int clock,
    required String originDeviceId,
  }) {
    return (update(favorRecords)..where((t) => t.id.equals(id))).write(
      FavorRecordsCompanion(
        deletedAt: Value(at),
        updatedAt: Value(at),
        clock: Value(clock),
        originDeviceId: Value(originDeviceId),
      ),
    );
  }

  Future<({int totalIn, int totalOut})> totalsForPerson(String personId) async {
    final rows = await (select(favorRecords)
          ..where((t) => t.personId.equals(personId) & t.deletedAt.isNull()))
        .get();
    var totalIn = 0;
    var totalOut = 0;
    for (final r in rows) {
      if (r.direction == 'in') {
        totalIn += r.amountCents;
      } else {
        totalOut += r.amountCents;
      }
    }
    return (totalIn: totalIn, totalOut: totalOut);
  }

  Future<Map<String, ({int totalIn, int totalOut, FavorRecord? latest})>>
      aggregatesByPerson() async {
    final rows = await getActiveRecords();
    final map = <String, ({int totalIn, int totalOut, FavorRecord? latest})>{};
    for (final r in rows) {
      final prev = map[r.personId];
      var totalIn = prev?.totalIn ?? 0;
      var totalOut = prev?.totalOut ?? 0;
      if (r.direction == 'in') {
        totalIn += r.amountCents;
      } else {
        totalOut += r.amountCents;
      }
      FavorRecord? latest = prev?.latest;
      if (latest == null ||
          r.occurredAt.isAfter(latest.occurredAt) ||
          (r.occurredAt.isAtSameMomentAs(latest.occurredAt) &&
              r.createdAt.isAfter(latest.createdAt))) {
        latest = r;
      }
      map[r.personId] = (totalIn: totalIn, totalOut: totalOut, latest: latest);
    }
    return map;
  }

  Future<({int totalIn, int totalOut})> yearTotals(int year) async {
    final start = DateTime(year);
    final end = DateTime(year + 1);
    final rows = await (select(favorRecords)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.occurredAt.isBiggerOrEqualValue(start) &
                t.occurredAt.isSmallerThanValue(end),
          ))
        .get();
    var totalIn = 0;
    var totalOut = 0;
    for (final r in rows) {
      if (r.direction == 'in') {
        totalIn += r.amountCents;
      } else {
        totalOut += r.amountCents;
      }
    }
    return (totalIn: totalIn, totalOut: totalOut);
  }

  Future<void> replaceAllFromSync({
    required List<PersonsCompanion> personRows,
    required List<FavorRecordsCompanion> recordRows,
  }) async {
    await transaction(() async {
      await delete(favorRecords).go();
      await delete(persons).go();
      await batch((b) {
        b.insertAll(persons, personRows);
        b.insertAll(favorRecords, recordRows);
      });
    });
  }

  Future<void> upsertMergedPreservingUnknown({
    required List<PersonsCompanion> personRows,
    required List<FavorRecordsCompanion> recordRows,
  }) async {
    await transaction(() async {
      await batch((b) {
        b.insertAllOnConflictUpdate(persons, personRows);
        b.insertAllOnConflictUpdate(favorRecords, recordRows);
      });
    });
  }

  Future<void> upsertManyFromSync({
    required List<PersonsCompanion> personRows,
    required List<FavorRecordsCompanion> recordRows,
  }) async {
    await transaction(() async {
      for (final p in personRows) {
        await into(persons).insertOnConflictUpdate(p);
      }
      for (final r in recordRows) {
        await into(favorRecords).insertOnConflictUpdate(r);
      }
    });
  }
}
