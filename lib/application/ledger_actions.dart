import 'package:drift/drift.dart';
import 'package:favor_ledger/core/utils/pinyin_util.dart';
import 'package:favor_ledger/data/local/database.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:favor_ledger/domain/direction.dart';
import 'package:uuid/uuid.dart';

class LedgerActions {
  LedgerActions(
    this.db, {
    required this.settings,
    this.onChanged,
  });

  final AppDatabase db;
  final SettingsStore settings;
  final void Function()? onChanged;
  final _uuid = const Uuid();

  void _notifyChanged() => onChanged?.call();

  Future<({DateTime now, int clock, String deviceId})> _meta() async {
    return (
      now: DateTime.now().toUtc(),
      clock: await settings.tickClock(),
      deviceId: await settings.deviceId(),
    );
  }

  Future<Person> createPerson({
    required String name,
    String note = '',
  }) async {
    final meta = await _meta();
    final person = PersonsCompanion.insert(
      id: _uuid.v4(),
      name: name.trim(),
      namePinyin: nameToPinyin(name),
      note: Value(note.trim()),
      createdAt: meta.now,
      updatedAt: meta.now,
      clock: Value(meta.clock),
      originDeviceId: Value(meta.deviceId),
    );
    await db.upsertPerson(person);
    _notifyChanged();
    return (await db.getPerson(person.id.value))!;
  }

  Future<void> updatePerson({
    required String id,
    required String name,
    String note = '',
  }) async {
    final existing = await db.getPerson(id);
    if (existing == null) return;
    final meta = await _meta();
    await db.upsertPerson(
      PersonsCompanion(
        id: Value(id),
        name: Value(name.trim()),
        namePinyin: Value(nameToPinyin(name)),
        note: Value(note.trim()),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(meta.now),
        deletedAt: const Value(null),
        clock: Value(meta.clock),
        originDeviceId: Value(meta.deviceId),
      ),
    );
    _notifyChanged();
  }

  Future<void> deletePerson(String id) async {
    final meta = await _meta();
    await db.softDeletePerson(
      id: id,
      at: meta.now,
      clock: meta.clock,
      originDeviceId: meta.deviceId,
    );
    _notifyChanged();
  }

  Future<void> saveRecord({
    String? id,
    required String personId,
    required FavorDirection direction,
    required int amountCents,
    required DateTime occurredAt,
    String event = '',
    String note = '',
  }) async {
    final meta = await _meta();
    final day = DateTime.utc(occurredAt.year, occurredAt.month, occurredAt.day);
    if (id == null) {
      await db.upsertRecord(
        FavorRecordsCompanion.insert(
          id: _uuid.v4(),
          personId: personId,
          direction: direction.code,
          amountCents: amountCents,
          occurredAt: day,
          event: Value(event.trim()),
          note: Value(note.trim()),
          createdAt: meta.now,
          updatedAt: meta.now,
          clock: Value(meta.clock),
          originDeviceId: Value(meta.deviceId),
        ),
      );
    } else {
      final existing = await db.getRecord(id);
      if (existing == null) return;
      await db.upsertRecord(
        FavorRecordsCompanion(
          id: Value(id),
          personId: Value(personId),
          direction: Value(direction.code),
          amountCents: Value(amountCents),
          occurredAt: Value(day),
          event: Value(event.trim()),
          note: Value(note.trim()),
          createdAt: Value(existing.createdAt),
          updatedAt: Value(meta.now),
          deletedAt: const Value(null),
          clock: Value(meta.clock),
          originDeviceId: Value(meta.deviceId),
        ),
      );
    }
    _notifyChanged();
  }

  Future<void> deleteRecord(String id) async {
    final meta = await _meta();
    await db.softDeleteRecord(
      id: id,
      at: meta.now,
      clock: meta.clock,
      originDeviceId: meta.deviceId,
    );
    _notifyChanged();
  }
}
