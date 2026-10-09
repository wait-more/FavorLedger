import 'dart:convert';

import 'package:favor_ledger/data/sync/sync_event.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class WebDavSettings {
  const WebDavSettings({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.autoSync,
  });

  /// 用户配置的 WebDAV 根路径（含协议与路径前缀），程序会在其下自动创建 FavorLedger。
  final String baseUrl;
  final String username;
  final String password;

  /// 自动同步：启动时同步一次 + 修改后防抖同步。默认关闭。
  final bool autoSync;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && username.trim().isNotEmpty;

  String get normalizedBaseUrl {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  WebDavSettings copyWith({
    String? baseUrl,
    String? username,
    String? password,
    bool? autoSync,
  }) {
    return WebDavSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      autoSync: autoSync ?? this.autoSync,
    );
  }
}

class SettingsStore {
  SettingsStore(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _kDeviceId = 'device_id';
  static const _kBaseUrl = 'webdav_base_url';
  static const _kUsername = 'webdav_username';
  static const _kAutoSync = 'webdav_auto_sync';
  static const _kLegacySyncOnLaunch = 'webdav_sync_on_launch';
  static const _kLegacySyncOnChange = 'webdav_sync_on_change';
  static const _kEtag = 'webdav_etag';
  static const _kPassword = 'webdav_password';
  static const _kLastSyncAt = 'last_sync_at';
  static const _kLamport = 'sync_lamport_clock';
  static const _kSyncEvents = 'sync_events_v1';
  static const _maxSyncEvents = 30;

  static Future<SettingsStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return SettingsStore(prefs, secure);
  }

  Future<String> deviceId() async {
    var id = _prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  Future<WebDavSettings> loadWebDav() async {
    final password = await _secure.read(key: _kPassword) ?? '';
    return WebDavSettings(
      baseUrl: _prefs.getString(_kBaseUrl) ?? '',
      username: _prefs.getString(_kUsername) ?? '',
      password: password,
      autoSync: _readAutoSync(),
    );
  }

  bool _readAutoSync() => _prefs.getBool(_kAutoSync) ?? false;

  Future<void> saveWebDav(WebDavSettings settings) async {
    await _prefs.setString(_kBaseUrl, settings.normalizedBaseUrl);
    await _prefs.setString(_kUsername, settings.username.trim());
    await _prefs.setBool(_kAutoSync, settings.autoSync);
    await _prefs.remove(_kLegacySyncOnLaunch);
    await _prefs.remove(_kLegacySyncOnChange);
    await _secure.write(key: _kPassword, value: settings.password);
  }

  String? get etag => _prefs.getString(_kEtag);

  Future<void> setEtag(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_kEtag);
    } else {
      await _prefs.setString(_kEtag, value);
    }
  }

  DateTime? get lastSyncAt {
    final raw = _prefs.getString(_kLastSyncAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastSyncAt(DateTime? value) async {
    if (value == null) {
      await _prefs.remove(_kLastSyncAt);
    } else {
      await _prefs.setString(_kLastSyncAt, value.toIso8601String());
    }
  }

  int get lamport => _prefs.getInt(_kLamport) ?? 0;

  /// 本地发生一次写操作时推进逻辑时钟。
  Future<int> tickClock() async {
    final next = lamport + 1;
    await _prefs.setInt(_kLamport, next);
    return next;
  }

  /// 吸收远程见到的最大逻辑时钟，避免本端接下来的写入被判旧。
  Future<void> observeClock(int remoteClock) async {
    if (remoteClock > lamport) {
      await _prefs.setInt(_kLamport, remoteClock);
    }
  }

  List<SyncEvent> loadSyncEvents() {
    final raw = _prefs.getString(_kSyncEvents);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => SyncEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> appendSyncEvent(SyncEvent event) async {
    final next = [event, ...loadSyncEvents()].take(_maxSyncEvents).toList();
    await _prefs.setString(
      _kSyncEvents,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
