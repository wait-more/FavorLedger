import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/data/sync/sync_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 下拉刷新：自动同步开启则拉云端合并；否则仅刷新本地列表。
Future<void> refreshLedger(WidgetRef ref) async {
  final store = ref.read(settingsStoreProvider).requireValue;
  final cfg = await store.loadWebDav();
  if (cfg.isConfigured && cfg.autoSync) {
    try {
      await ref.read(syncHubProvider.notifier).syncNow(
            trigger: SyncTrigger.pull,
          );
    } catch (_) {
      // SyncHub 已 toast
    }
    return;
  }

  ref.invalidate(personSummariesProvider);
  ref.invalidate(peopleProvider);
  ref.invalidate(flowProvider);
  ref.invalidate(activeRecordsProvider);
}
