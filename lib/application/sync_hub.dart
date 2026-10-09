import 'package:favor_ledger/core/sync_messages.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:favor_ledger/data/sync/sync_event.dart';
import 'package:favor_ledger/data/sync/sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncUiState {
  const SyncUiState({
    this.syncing = false,
    this.events = const [],
    this.pendingToast,
    this.pendingToastError = false,
    this.toastSeq = 0,
  });

  final bool syncing;
  final List<SyncEvent> events;
  final String? pendingToast;
  final bool pendingToastError;

  /// 每次需要弹出 toast 时递增，避免相同文案被去重漏弹。
  final int toastSeq;

  SyncEvent? get latest => events.isEmpty ? null : events.first;

  DateTime? get lastSuccessAt {
    for (final e in events) {
      if (e.status == SyncEventStatus.success) return e.at;
    }
    return null;
  }

  SyncUiState copyWith({
    bool? syncing,
    List<SyncEvent>? events,
    String? pendingToast,
    bool? pendingToastError,
    int? toastSeq,
    bool clearToast = false,
  }) {
    return SyncUiState(
      syncing: syncing ?? this.syncing,
      events: events ?? this.events,
      pendingToast: clearToast ? null : (pendingToast ?? this.pendingToast),
      pendingToastError:
          clearToast ? false : (pendingToastError ?? this.pendingToastError),
      toastSeq: toastSeq ?? this.toastSeq,
    );
  }
}

/// 统一入口：记录同步事件，并按策略弹出 toast。
class SyncHub extends StateNotifier<SyncUiState> {
  SyncHub({
    required this.settings,
    required this.syncService,
  }) : super(SyncUiState(events: settings.loadSyncEvents()));

  final SettingsStore settings;
  final SyncService syncService;

  void clearToast() {
    if (state.pendingToast == null && !state.pendingToastError) return;
    state = state.copyWith(clearToast: true);
  }

  Future<SyncOutcome> syncNow({required SyncTrigger trigger}) {
    return _run(trigger, () => syncService.syncNow());
  }

  Future<SyncOutcome> uploadOnly({required SyncTrigger trigger}) {
    return _run(trigger, () => syncService.uploadOnly());
  }

  Future<SyncOutcome> restoreFromRemote({
    required SyncTrigger trigger,
    bool merge = true,
  }) {
    return _run(
      trigger,
      () => syncService.restoreFromRemote(merge: merge),
    );
  }

  Future<SyncOutcome> _run(
    SyncTrigger trigger,
    Future<SyncOutcome> Function() action,
  ) async {
    state = state.copyWith(syncing: true, clearToast: true);
    try {
      final outcome = await action();
      final event = SyncEvent(
        at: DateTime.now(),
        trigger: trigger,
        status: SyncEventStatus.success,
        message: outcome.message,
        localUpdated: outcome.localUpdated,
        uploadedToCloud: outcome.uploadedToCloud,
        changedPersons: outcome.changedPersons,
        changedRecords: outcome.changedRecords,
      );
      await _commit(
        event,
        toast: _toastForSuccess(trigger, outcome),
        error: false,
      );
      return outcome;
    } catch (e) {
      final message = friendlySyncError(e);
      final event = SyncEvent(
        at: DateTime.now(),
        trigger: trigger,
        status: SyncEventStatus.failure,
        message: message,
      );
      await _commit(event, toast: message, error: true);
      rethrow;
    } finally {
      if (mounted) {
        state = state.copyWith(syncing: false);
      }
    }
  }

  String? _toastForSuccess(SyncTrigger trigger, SyncOutcome outcome) {
    // 只在「云端改了本地」或「本地变更已推上云端」时提示；无实质变更不打扰。
    if (outcome.localUpdated || outcome.uploadedToCloud) {
      return outcome.message;
    }
    return null;
  }

  Future<void> _commit(
    SyncEvent event, {
    String? toast,
    bool error = false,
  }) async {
    await settings.appendSyncEvent(event);
    if (!mounted) return;
    state = state.copyWith(
      events: settings.loadSyncEvents(),
      pendingToast: toast,
      pendingToastError: toast == null ? false : error,
      toastSeq: toast == null ? state.toastSeq : state.toastSeq + 1,
    );
  }
}
