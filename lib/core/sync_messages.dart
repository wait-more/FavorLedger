String friendlySyncError(Object e) {
  final raw = e.toString();
  final cleaned = raw.replaceFirst(RegExp(r'^(Bad state|Exception):\s*'), '');
  if (cleaned.contains('请先配置') ||
      cleaned.contains('请先填写') ||
      cleaned.contains('请填写密码') ||
      cleaned.contains('远程没有') ||
      cleaned.contains('其他设备正在同步') ||
      cleaned.contains('同步失败')) {
    return cleaned;
  }
  if (raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Connection') ||
      raw.contains('Timeout')) {
    return '网络不通，请检查地址或网络';
  }
  if (raw.contains('401') ||
      raw.contains('Unauthorized') ||
      raw.contains('403')) {
    return '账号或密码不正确';
  }
  return '同步失败，请稍后重试';
}

String syncSuccessMessage({
  required bool localUpdated,
  required bool uploadedToCloud,
  required int changedPersons,
  required int changedRecords,
}) {
  if (localUpdated) {
    final parts = <String>[];
    if (changedPersons > 0) parts.add('$changedPersons 位亲友');
    if (changedRecords > 0) parts.add('$changedRecords 笔往来');
    if (parts.isEmpty) return '已从云端更新本地';
    return '已从云端更新本地 · ${parts.join(' · ')}';
  }
  if (uploadedToCloud) {
    return '本地变更已同步到云端';
  }
  return '同步完成';
}
