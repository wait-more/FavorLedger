import 'package:favor_ledger/data/local/database.dart';

class MergeResult {
  const MergeResult({
    required this.persons,
    required this.records,
    required this.appliedPersonChanges,
    required this.appliedRecordChanges,
  });

  final List<Person> persons;
  final List<FavorRecord> records;

  /// 因远程侧写入本地的亲友数（新建或远程版本胜出）。
  final int appliedPersonChanges;

  /// 因远程侧写入本地的往来数（新建或远程版本胜出）。
  final int appliedRecordChanges;

  bool get hasRemoteApplied =>
      appliedPersonChanges > 0 || appliedRecordChanges > 0;
}

/// 实体级合并：按 id 并集，永不丢只在一侧存在的记录。
/// 同一 id 用逻辑时钟优先，其次 updatedAt，再比 originDeviceId。
MergeResult mergeLedgers({
  required List<Person> localPersons,
  required List<FavorRecord> localRecords,
  required List<Person> remotePersons,
  required List<FavorRecord> remoteRecords,
}) {
  final persons = _mergeById(
    local: localPersons,
    remote: remotePersons,
    idOf: (p) => p.id,
    clockOf: (p) => p.clock,
    updatedAtOf: (p) => p.updatedAt,
    originOf: (p) => p.originDeviceId,
  );
  final records = _mergeById(
    local: localRecords,
    remote: remoteRecords,
    idOf: (r) => r.id,
    clockOf: (r) => r.clock,
    updatedAtOf: (r) => r.updatedAt,
    originOf: (r) => r.originDeviceId,
  );
  return MergeResult(
    persons: persons.items,
    records: records.items,
    appliedPersonChanges: persons.remoteApplied,
    appliedRecordChanges: records.remoteApplied,
  );
}

int compareSyncVersion({
  required int localClock,
  required DateTime localUpdatedAt,
  required String localOrigin,
  required int remoteClock,
  required DateTime remoteUpdatedAt,
  required String remoteOrigin,
}) {
  if (localClock != remoteClock && (localClock > 0 || remoteClock > 0)) {
    return localClock.compareTo(remoteClock);
  }
  final time = localUpdatedAt.compareTo(remoteUpdatedAt);
  if (time != 0) return time;
  return localOrigin.compareTo(remoteOrigin);
}

class _MergeBucket<T> {
  const _MergeBucket({required this.items, required this.remoteApplied});

  final List<T> items;
  final int remoteApplied;
}

_MergeBucket<T> _mergeById<T>({
  required List<T> local,
  required List<T> remote,
  required String Function(T) idOf,
  required int Function(T) clockOf,
  required DateTime Function(T) updatedAtOf,
  required String Function(T) originOf,
}) {
  final map = <String, T>{};
  for (final item in local) {
    map[idOf(item)] = item;
  }
  var remoteApplied = 0;
  for (final item in remote) {
    final id = idOf(item);
    final existing = map[id];
    if (existing == null) {
      map[id] = item;
      remoteApplied++;
      continue;
    }
    final cmp = compareSyncVersion(
      localClock: clockOf(existing),
      localUpdatedAt: updatedAtOf(existing),
      localOrigin: originOf(existing),
      remoteClock: clockOf(item),
      remoteUpdatedAt: updatedAtOf(item),
      remoteOrigin: originOf(item),
    );
    if (cmp < 0) {
      map[id] = item;
      remoteApplied++;
    }
  }
  return _MergeBucket(items: map.values.toList(), remoteApplied: remoteApplied);
}
