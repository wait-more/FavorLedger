import 'package:favor_ledger/core/utils/money.dart';
import 'package:favor_ledger/data/local/database.dart';
import 'package:favor_ledger/data/sync/merge.dart';
import 'package:flutter_test/flutter_test.dart';

Person _person({
  required String id,
  required String name,
  required DateTime updatedAt,
  int clock = 0,
  String origin = '',
}) {
  return Person(
    id: id,
    name: name,
    namePinyin: name,
    note: '',
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: null,
    clock: clock,
    originDeviceId: origin,
  );
}

FavorRecord _record({
  required String id,
  required DateTime updatedAt,
  int clock = 0,
  String origin = '',
}) {
  return FavorRecord(
    id: id,
    personId: 'p',
    direction: 'out',
    amountCents: 100,
    occurredAt: updatedAt,
    event: '',
    note: '',
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: null,
    clock: clock,
    originDeviceId: origin,
  );
}

void main() {
  test('yuanToCents rounds correctly', () {
    expect(yuanToCents('800'), 80000);
    expect(yuanToCents('12.34'), 1234);
    expect(centsToYuan(1234), '12.34');
  });

  test('merge prefers higher logical clock over wall clock', () {
    final olderWall = DateTime.utc(2024, 2, 1);
    final newerWall = DateTime.utc(2024, 3, 1);
    final local = _person(id: '1', name: '本地', updatedAt: newerWall, clock: 3);
    final remote = _person(id: '1', name: '远程', updatedAt: olderWall, clock: 8);
    final merged = mergeLedgers(
      localPersons: [local],
      localRecords: const [],
      remotePersons: [remote],
      remoteRecords: const [],
    );
    expect(merged.persons.single.name, '远程');
  });

  test('merge keeps records that exist on only one side', () {
    final t = DateTime.utc(2024, 1, 1);
    final merged = mergeLedgers(
      localPersons: const [],
      localRecords: [_record(id: 'a', updatedAt: t, clock: 1)],
      remotePersons: const [],
      remoteRecords: [_record(id: 'b', updatedAt: t, clock: 1)],
    );
    expect(merged.records.map((e) => e.id).toSet(), {'a', 'b'});
  });

  test('equal clock falls back to updatedAt', () {
    final t1 = DateTime.utc(2024, 1, 1);
    final t2 = DateTime.utc(2024, 2, 1);
    final local = _person(id: '1', name: '本地', updatedAt: t1, clock: 2);
    final remote = _person(id: '1', name: '远程', updatedAt: t2, clock: 2);
    final merged = mergeLedgers(
      localPersons: [local],
      localRecords: const [],
      remotePersons: [remote],
      remoteRecords: const [],
    );
    expect(merged.persons.single.name, '远程');
  });
}
