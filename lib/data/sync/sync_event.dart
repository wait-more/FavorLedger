enum SyncTrigger {
  manual,
  auto,
  launch,
  resume,
  pull,
  poll;

  String get label => switch (this) {
        SyncTrigger.manual => '手动',
        SyncTrigger.auto => '自动',
        SyncTrigger.launch => '启动',
        SyncTrigger.resume => '回前台',
        SyncTrigger.pull => '下拉',
        SyncTrigger.poll => '定时',
      };
}

enum SyncEventStatus {
  success,
  failure;

  String get label => switch (this) {
        SyncEventStatus.success => '成功',
        SyncEventStatus.failure => '失败',
      };
}

class SyncEvent {
  const SyncEvent({
    required this.at,
    required this.trigger,
    required this.status,
    required this.message,
    this.localUpdated = false,
    this.uploadedToCloud = false,
    this.changedPersons = 0,
    this.changedRecords = 0,
  });

  final DateTime at;
  final SyncTrigger trigger;
  final SyncEventStatus status;
  final String message;
  final bool localUpdated;
  final bool uploadedToCloud;
  final int changedPersons;
  final int changedRecords;

  Map<String, dynamic> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'trigger': trigger.name,
        'status': status.name,
        'message': message,
        'localUpdated': localUpdated,
        'uploadedToCloud': uploadedToCloud,
        'changedPersons': changedPersons,
        'changedRecords': changedRecords,
      };

  factory SyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEvent(
      at: DateTime.tryParse(json['at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      trigger: SyncTrigger.values.firstWhere(
        (e) => e.name == json['trigger'],
        orElse: () => SyncTrigger.manual,
      ),
      status: SyncEventStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncEventStatus.success,
      ),
      message: json['message'] as String? ?? '',
      localUpdated: json['localUpdated'] as bool? ?? false,
      uploadedToCloud: json['uploadedToCloud'] as bool? ?? false,
      changedPersons: json['changedPersons'] as int? ?? 0,
      changedRecords: json['changedRecords'] as int? ?? 0,
    );
  }
}
