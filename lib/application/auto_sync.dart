import 'dart:async';

import 'package:favor_ledger/application/sync_hub.dart';
import 'package:favor_ledger/core/constants.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:favor_ledger/data/sync/sync_event.dart';
import 'package:flutter/foundation.dart';

/// 修改后防抖、回前台、前台定时拉取；与启动同步共用 SyncHub。
class AutoSyncController {
  AutoSyncController({
    required this.settings,
    required this.syncHub,
    this.debounce = AppConstants.autoSyncDebounce,
    this.pollInterval = AppConstants.autoSyncPollInterval,
  }) {
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(_run(SyncTrigger.poll));
    });
  }

  final SettingsStore settings;
  final SyncHub syncHub;
  final Duration debounce;
  final Duration pollInterval;

  Timer? _timer;
  Timer? _pollTimer;
  var _running = false;
  var _pending = false;
  SyncTrigger? _pendingTrigger;

  void scheduleAfterChange() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      unawaited(_run(SyncTrigger.auto));
    });
  }

  Future<void> flushNow() async {
    _timer?.cancel();
    await _run(SyncTrigger.auto);
  }

  /// App 从后台回到前台时拉取一次。
  Future<void> onAppResumed() => _run(SyncTrigger.resume);

  Future<void> _run(SyncTrigger trigger) async {
    if (_running) {
      _pending = true;
      _pendingTrigger = trigger;
      return;
    }
    _running = true;
    try {
      final cfg = await settings.loadWebDav();
      if (!cfg.isConfigured || !cfg.autoSync) return;
      await syncHub.syncNow(trigger: trigger);
    } catch (e, st) {
      debugPrint('自动同步失败($trigger): $e\n$st');
    } finally {
      _running = false;
      if (_pending) {
        _pending = false;
        final next = _pendingTrigger ?? SyncTrigger.auto;
        _pendingTrigger = null;
        unawaited(_run(next));
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
  }
}
