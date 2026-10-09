import 'package:favor_ledger/application/auto_sync.dart';
import 'package:favor_ledger/application/ledger_actions.dart';
import 'package:favor_ledger/application/sync_hub.dart';
import 'package:favor_ledger/data/local/database.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:favor_ledger/data/sync/change_epoch.dart';
import 'package:favor_ledger/data/sync/sync_service.dart';
import 'package:favor_ledger/domain/person_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final settingsStoreProvider = FutureProvider<SettingsStore>((ref) {
  return SettingsStore.create();
});

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final changeEpochProvider = Provider<ChangeEpoch>((ref) => ChangeEpoch());

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final settings = ref.watch(settingsStoreProvider).requireValue;
  return SyncService(
    db: db,
    settings: settings,
    epoch: ref.watch(changeEpochProvider),
  );
});

final syncHubProvider =
    StateNotifierProvider<SyncHub, SyncUiState>((ref) {
  return SyncHub(
    settings: ref.watch(settingsStoreProvider).requireValue,
    syncService: ref.watch(syncServiceProvider),
  );
});

final autoSyncProvider = Provider<AutoSyncController>((ref) {
  final controller = AutoSyncController(
    settings: ref.watch(settingsStoreProvider).requireValue,
    syncHub: ref.watch(syncHubProvider.notifier),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final ledgerActionsProvider = Provider<LedgerActions>((ref) {
  final autoSync = ref.watch(autoSyncProvider);
  final epoch = ref.watch(changeEpochProvider);
  return LedgerActions(
    ref.watch(databaseProvider),
    settings: ref.watch(settingsStoreProvider).requireValue,
    onChanged: () {
      epoch.bump();
      autoSync.scheduleAfterChange();
    },
  );
});

final peopleProvider = StreamProvider<List<Person>>((ref) {
  return ref.watch(databaseProvider).watchActivePersons();
});

final personSummariesProvider = StreamProvider<List<PersonSummary>>((ref) {
  final db = ref.watch(databaseProvider);
  // 同时监听人员与往来，避免只改记录时首页/汇总不刷新
  return db.watchLedgerChanges().asyncMap((_) async {
    final persons = await db.getActivePersons();
    final aggregates = await db.aggregatesByPerson();
    return persons
        .map((p) {
          final agg = aggregates[p.id];
          return PersonSummary(
            person: p,
            totalInCents: agg?.totalIn ?? 0,
            totalOutCents: agg?.totalOut ?? 0,
            latestRecord: agg?.latest,
          );
        })
        .toList();
  });
});

final activeRecordsProvider = StreamProvider<List<FavorRecord>>((ref) {
  return ref.watch(databaseProvider).watchActiveRecords();
});

final personProvider = FutureProvider.family<Person?, String>((ref, id) {
  return ref.watch(databaseProvider).getPerson(id);
});

final personRecordsProvider =
    StreamProvider.family<List<FavorRecord>, String>((ref, personId) {
  return ref.watch(databaseProvider).watchRecordsForPerson(personId);
});

final personTotalsProvider =
    FutureProvider.family<({int totalIn, int totalOut}), String>((ref, personId) {
  // Rebuild when records change
  ref.watch(personRecordsProvider(personId));
  return ref.watch(databaseProvider).totalsForPerson(personId);
});

class FlowItem {
  const FlowItem({required this.record, required this.personName});

  final FavorRecord record;
  final String personName;
}

final flowProvider = StreamProvider<List<FlowItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchFlowJoined().map((rows) {
    return rows.map((row) {
      final record = row.readTable(db.favorRecords);
      final person = row.readTable(db.persons);
      return FlowItem(record: record, personName: person.name);
    }).toList();
  });
});

final yearStatsProvider =
    FutureProvider.family<({int totalIn, int totalOut}), int>((ref, year) async {
  // 记录变化时重算年度汇总（与 flow 解耦，避免多余依赖）
  ref.watch(activeRecordsProvider);
  return ref.watch(databaseProvider).yearTotals(year);
});
