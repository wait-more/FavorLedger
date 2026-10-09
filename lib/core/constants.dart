class AppConstants {
  static const appName = '人情记';
  static const appTagline = '以礼往来，心中有数';
  static const repositoryUrl = 'https://github.com/wait-more/FavorLedger';
  static const repositoryTitle = '在 GitHub 查看源码';
  /// 程序在用户 WebDAV 根路径下自动创建的应用目录（用户无需填写）。
  static const appRemoteFolder = 'FavorLedger';
  static const remoteFileName = 'ledger.v1.json';
  static const remoteTempFileName = 'ledger.v1.json.tmp';
  static const remoteLockFileName = 'ledger.lock';
  static const schemaVersion = 2;
  static const localBackupKeep = 5;
  static const syncMaxAttempts = 6;
  static const lockStaleAfter = Duration(seconds: 45);

  /// 本地修改后自动同步的防抖时间。
  static const autoSyncDebounce = Duration(seconds: 2);

  /// 前台定时拉取云端的间隔（仅自动同步开启时真正请求）。
  static const autoSyncPollInterval = Duration(minutes: 3);

  static const eventChips = <String>[
    '结婚',
    '生子',
    '满月',
    '乔迁',
    '升学',
    '白事',
    '探望',
    '其他',
  ];
}
