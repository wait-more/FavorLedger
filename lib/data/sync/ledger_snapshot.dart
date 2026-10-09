import 'dart:convert';

import 'package:favor_ledger/core/constants.dart';
import 'package:favor_ledger/data/local/database.dart';

class LedgerSnapshot {
  LedgerSnapshot({
    required this.schemaVersion,
    required this.exportedAt,
    required this.deviceId,
    required this.generation,
    required this.persons,
    required this.records,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final String deviceId;
  final int generation;
  final List<Person> persons;
  final List<FavorRecord> records;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'deviceId': deviceId,
        'generation': generation,
        'persons': persons.map(_personToJson).toList(),
        'records': records.map(_recordToJson).toList(),
      };

  static LedgerSnapshot fromJson(Map<String, dynamic> json) {
    final persons = (json['persons'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_personFromJson)
        .toList();
    final records = (json['records'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_recordFromJson)
        .toList();
    return LedgerSnapshot(
      schemaVersion: json['schemaVersion'] as int? ?? AppConstants.schemaVersion,
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      deviceId: json['deviceId'] as String? ?? '',
      generation: json['generation'] as int? ?? 0,
      persons: persons,
      records: records,
    );
  }

  /// 不含 generation / deviceId / exportedAt，用于上传后回读校验。
  String dataFingerprint() {
    final personLines = persons.map(_personToJson).toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final recordLines = records.map(_recordToJson).toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return jsonEncode({'persons': personLines, 'records': recordLines});
  }

  int get maxClock {
    var max = 0;
    for (final p in persons) {
      if (p.clock > max) max = p.clock;
    }
    for (final r in records) {
      if (r.clock > max) max = r.clock;
    }
    return max;
  }

  static Map<String, dynamic> _personToJson(Person p) => {
        'id': p.id,
        'name': p.name,
        'namePinyin': p.namePinyin,
        'note': p.note,
        'createdAt': p.createdAt.toUtc().toIso8601String(),
        'updatedAt': p.updatedAt.toUtc().toIso8601String(),
        'deletedAt': p.deletedAt?.toUtc().toIso8601String(),
        'clock': p.clock,
        'originDeviceId': p.originDeviceId,
      };

  static Person _personFromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        namePinyin: json['namePinyin'] as String? ?? '',
        note: json['note'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
        clock: json['clock'] as int? ?? 0,
        originDeviceId: json['originDeviceId'] as String? ?? '',
      );

  static Map<String, dynamic> _recordToJson(FavorRecord r) => {
        'id': r.id,
        'personId': r.personId,
        'direction': r.direction,
        'amountCents': r.amountCents,
        'occurredAt': r.occurredAt.toUtc().toIso8601String(),
        'event': r.event,
        'note': r.note,
        'createdAt': r.createdAt.toUtc().toIso8601String(),
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
        'deletedAt': r.deletedAt?.toUtc().toIso8601String(),
        'clock': r.clock,
        'originDeviceId': r.originDeviceId,
      };

  static FavorRecord _recordFromJson(Map<String, dynamic> json) => FavorRecord(
        id: json['id'] as String,
        personId: json['personId'] as String,
        direction: json['direction'] as String? ?? 'out',
        amountCents: json['amountCents'] as int? ?? 0,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        event: json['event'] as String? ?? '',
        note: json['note'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
        clock: json['clock'] as int? ?? 0,
        originDeviceId: json['originDeviceId'] as String? ?? '',
      );
}
