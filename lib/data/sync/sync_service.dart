import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:favor_ledger/core/constants.dart';
import 'package:favor_ledger/data/local/database.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:favor_ledger/data/remote/webdav_service.dart';
import 'package:favor_ledger/core/sync_messages.dart';
import 'package:favor_ledger/data/sync/change_epoch.dart';
import 'package:favor_ledger/data/sync/ledger_snapshot.dart';
import 'package:favor_ledger/data/sync/merge.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SyncOutcome {
  const SyncOutcome({
    required this.message,
    required this.personCount,
    required this.recordCount,
    this.localUpdated = false,
    this.uploadedToCloud = false,
    this.changedPersons = 0,
    this.changedRecords = 0,
  });

  final String message;
  final int personCount;
  final int recordCount;

  /// 本次同步是否因云端数据改写了本地账本。
  final bool localUpdated;

  /// 本次是否把相对云端有差异的本地账本成功推上去。
  final bool uploadedToCloud;
  final int changedPersons;
  final int changedRecords;
}

class SyncService {
  SyncService({
    required this.db,
    required this.settings,
    required this.epoch,
    WebDavService? webDav,
  }) : webDav = webDav ?? WebDavService();

  final AppDatabase db;
  final SettingsStore settings;
  final ChangeEpoch epoch;
  final WebDavService webDav;

  Future<void> _chain = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final done = Completer<T>();
    _chain = _chain.catchError((_) {}).then((_) async {
      try {
        done.complete(await action());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<LedgerSnapshot> exportSnapshot({int generation = 0}) async {
    final deviceId = await settings.deviceId();
    final persons = await db.getAllPersonsIncludingDeleted();
    final records = await db.getAllRecordsIncludingDeleted();
    return LedgerSnapshot(
      schemaVersion: AppConstants.schemaVersion,
      exportedAt: DateTime.now().toUtc(),
      deviceId: deviceId,
      generation: generation,
      persons: persons,
      records: records,
    );
  }

  Future<File> writeLocalBackup(LedgerSnapshot snapshot) async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    final file = File(
      p.join(
        backupDir.path,
        'ledger_${DateTime.now().toUtc().millisecondsSinceEpoch}.json',
      ),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
    final files = backupDir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in files.skip(AppConstants.localBackupKeep)) {
      await old.delete();
    }
    return file;
  }

  Future<SyncOutcome> syncNow() {
    return _exclusive(() => _syncOnce());
  }

  /// 多端场景下「仅上传」也会先拉远程合并，避免覆盖另一台设备的新数据。
  Future<SyncOutcome> uploadOnly() => syncNow();

  Future<SyncOutcome> _syncOnce() async {
    final cfg = await settings.loadWebDav();
    if (!cfg.isConfigured) {
      throw StateError('请先配置 WebDAV');
    }
    final deviceId = await settings.deviceId();
    await writeLocalBackup(await exportSnapshot());

    Object? lastError;
    for (var attempt = 1; attempt <= AppConstants.syncMaxAttempts; attempt++) {
      final locked = await webDav.acquireLock(cfg, deviceId);
      if (!locked) {
        lastError = StateError('其他设备正在同步');
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        continue;
      }
      try {
        final outcome = await _mergePushVerify(cfg, deviceId);
        return outcome;
      } on StaleRemoteException catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      } catch (e) {
        lastError = e;
        rethrow;
      } finally {
        await webDav.releaseLock(cfg, deviceId);
      }
    }
    throw lastError ?? StateError('同步失败，请稍后重试');
  }

  Future<SyncOutcome> _mergePushVerify(
    WebDavSettings cfg,
    String deviceId,
  ) async {
    final remote = await webDav.download(cfg);
    LedgerSnapshot? remoteSnapshot;
    if (remote.exists && remote.body != null && remote.body!.isNotEmpty) {
      remoteSnapshot = LedgerSnapshot.fromJson(
        jsonDecode(remote.body!) as Map<String, dynamic>,
      );
      await settings.observeClock(remoteSnapshot.maxClock);
    }

    var startEpoch = epoch.value;
    var local = await exportSnapshot();
    var changedPersons = 0;
    var changedRecords = 0;
    if (remoteSnapshot != null) {
      final merged = mergeLedgers(
        localPersons: local.persons,
        localRecords: local.records,
        remotePersons: remoteSnapshot.persons,
        remoteRecords: remoteSnapshot.records,
      );
      changedPersons += merged.appliedPersonChanges;
      changedRecords += merged.appliedRecordChanges;
      await _applyMerged(merged);
      await settings.observeClock(
        LedgerSnapshot(
          schemaVersion: AppConstants.schemaVersion,
          exportedAt: DateTime.now().toUtc(),
          deviceId: deviceId,
          generation: 0,
          persons: merged.persons,
          records: merged.records,
        ).maxClock,
      );
    }

    // 合并期间若有本地新记账，再并一次（持锁，不必重新下载）
    if (epoch.value != startEpoch) {
      local = await exportSnapshot();
      if (remoteSnapshot != null) {
        final merged = mergeLedgers(
          localPersons: local.persons,
          localRecords: local.records,
          remotePersons: remoteSnapshot.persons,
          remoteRecords: remoteSnapshot.records,
        );
        changedPersons += merged.appliedPersonChanges;
        changedRecords += merged.appliedRecordChanges;
        await _applyMerged(merged);
      }
    }

    final generation = (remoteSnapshot?.generation ?? 0) + 1;
    final toPush = await exportSnapshot(generation: generation);
    final body = const JsonEncoder.withIndent('  ').convert(toPush.toJson());
    final etag = await webDav.upload(
      cfg,
      body: body,
      expectedEtag: remote.etag,
    );

    final verify = await webDav.download(cfg);
    if (!verify.exists || verify.body == null || verify.body!.isEmpty) {
      throw const StaleRemoteException();
    }
    final landed = LedgerSnapshot.fromJson(
      jsonDecode(verify.body!) as Map<String, dynamic>,
    );
    if (landed.dataFingerprint() != toPush.dataFingerprint()) {
      // 上传窗口被其他端覆盖，带回读结果再走一轮
      throw const StaleRemoteException();
    }

    await settings.setEtag(etag ?? verify.etag);
    await settings.setLastSyncAt(DateTime.now());
    final localUpdated = changedPersons > 0 || changedRecords > 0;
    // 推上去的数据指纹相对下载时有变化，说明云端内容被本轮写入更新了。
    final uploadedToCloud = remoteSnapshot == null
        ? toPush.persons.isNotEmpty || toPush.records.isNotEmpty
        : toPush.dataFingerprint() != remoteSnapshot.dataFingerprint();
    return SyncOutcome(
      message: syncSuccessMessage(
        localUpdated: localUpdated,
        uploadedToCloud: uploadedToCloud,
        changedPersons: changedPersons,
        changedRecords: changedRecords,
      ),
      personCount: toPush.persons.where((e) => e.deletedAt == null).length,
      recordCount: toPush.records.where((e) => e.deletedAt == null).length,
      localUpdated: localUpdated,
      uploadedToCloud: uploadedToCloud,
      changedPersons: changedPersons,
      changedRecords: changedRecords,
    );
  }

  Future<SyncOutcome> restoreFromRemote({bool merge = true}) {
    return _exclusive(() async {
      final cfg = await settings.loadWebDav();
      if (!cfg.isConfigured) {
        throw StateError('请先配置 WebDAV');
      }
      await writeLocalBackup(await exportSnapshot());
      if (merge) {
        return _syncOnce();
      }
      final remote = await webDav.download(cfg);
      if (!remote.exists || remote.body == null || remote.body!.isEmpty) {
        throw StateError('远程没有可恢复的数据');
      }
      final remoteSnapshot = LedgerSnapshot.fromJson(
        jsonDecode(remote.body!) as Map<String, dynamic>,
      );
      await db.replaceAllFromSync(
        personRows: remoteSnapshot.persons.map(_personCompanion).toList(),
        recordRows: remoteSnapshot.records.map(_recordCompanion).toList(),
      );
      await settings.observeClock(remoteSnapshot.maxClock);
      await settings.setEtag(remote.etag);
      await settings.setLastSyncAt(DateTime.now());
      final snap = await exportSnapshot();
      final persons = snap.persons.where((e) => e.deletedAt == null).length;
      final records = snap.records.where((e) => e.deletedAt == null).length;
      return SyncOutcome(
        message: '已从远程覆盖恢复 · $persons 位亲友 · $records 笔往来',
        personCount: persons,
        recordCount: records,
        localUpdated: true,
        uploadedToCloud: false,
        changedPersons: persons,
        changedRecords: records,
      );
    });
  }

  Future<String> exportJsonString() async {
    final snapshot = await exportSnapshot();
    return const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
  }

  Future<String> exportCsvString() async {
    final persons = {
      for (final p in await db.getActivePersons()) p.id: p.name,
    };
    final records = await db.getActiveRecords()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final buf = StringBuffer('日期,姓名,方向,金额(元),事件,备注\n');
    for (final r in records) {
      final name = persons[r.personId] ?? '';
      final dir = r.direction == 'in' ? '收到' : '送出';
      final amount = (r.amountCents / 100).toStringAsFixed(2);
      final date =
          '${r.occurredAt.year.toString().padLeft(4, '0')}-${r.occurredAt.month.toString().padLeft(2, '0')}-${r.occurredAt.day.toString().padLeft(2, '0')}';
      buf.writeln(
        '$date,"${_escape(name)}",$dir,$amount,"${_escape(r.event)}","${_escape(r.note)}"',
      );
    }
    return buf.toString();
  }

  String _escape(String s) => s.replaceAll('"', '""');

  Future<void> _applyMerged(MergeResult merged) {
    return db.upsertMergedPreservingUnknown(
      personRows: merged.persons.map(_personCompanion).toList(),
      recordRows: merged.records.map(_recordCompanion).toList(),
    );
  }

  PersonsCompanion _personCompanion(Person p) => PersonsCompanion(
        id: Value(p.id),
        name: Value(p.name),
        namePinyin: Value(p.namePinyin),
        note: Value(p.note),
        createdAt: Value(p.createdAt),
        updatedAt: Value(p.updatedAt),
        deletedAt: Value(p.deletedAt),
        clock: Value(p.clock),
        originDeviceId: Value(p.originDeviceId),
      );

  FavorRecordsCompanion _recordCompanion(FavorRecord r) => FavorRecordsCompanion(
        id: Value(r.id),
        personId: Value(r.personId),
        direction: Value(r.direction),
        amountCents: Value(r.amountCents),
        occurredAt: Value(r.occurredAt),
        event: Value(r.event),
        note: Value(r.note),
        createdAt: Value(r.createdAt),
        updatedAt: Value(r.updatedAt),
        deletedAt: Value(r.deletedAt),
        clock: Value(r.clock),
        originDeviceId: Value(r.originDeviceId),
      );
}
