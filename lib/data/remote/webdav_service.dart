import 'dart:convert';
import 'dart:typed_data';

import 'package:favor_ledger/core/constants.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

class RemoteFileResult {
  const RemoteFileResult({
    required this.exists,
    this.body,
    this.etag,
  });

  final bool exists;
  final String? body;
  final String? etag;
}

class StaleRemoteException implements Exception {
  const StaleRemoteException();

  @override
  String toString() => '远程账本已变化';
}

class WebDavService {
  webdav.Client _client(WebDavSettings settings) {
    return webdav.newClient(
      settings.normalizedBaseUrl,
      user: settings.username.trim(),
      password: settings.password,
      debug: false,
    );
  }

  String appDirPath(WebDavSettings settings) =>
      '/${AppConstants.appRemoteFolder}';

  String remotePath(WebDavSettings settings) =>
      '${appDirPath(settings)}/${AppConstants.remoteFileName}';

  String _tempPath(WebDavSettings settings) =>
      '${appDirPath(settings)}/${AppConstants.remoteTempFileName}';

  String _lockPath(WebDavSettings settings) =>
      '${appDirPath(settings)}/${AppConstants.remoteLockFileName}';

  Future<void> ensureDir(WebDavSettings settings) async {
    final client = _client(settings);
    await client.mkdirAll(appDirPath(settings));
  }

  Future<void> checkAvailability(WebDavSettings settings) async {
    if (!settings.isConfigured) {
      throw StateError('请先填写 WebDAV 路径与账号');
    }
    if (settings.password.isEmpty) {
      throw StateError('请填写密码或应用专用密码');
    }
    final client = _client(settings);
    try {
      await client.readDir('/');
    } catch (_) {}
    await client.mkdirAll(appDirPath(settings));
    await client.readDir(appDirPath(settings));
  }

  Future<String?> readEtag(WebDavSettings settings) async {
    try {
      final props = await _client(settings).readProps(remotePath(settings));
      return props.eTag;
    } catch (_) {
      return null;
    }
  }

  Future<RemoteFileResult> download(WebDavSettings settings) async {
    final client = _client(settings);
    final path = remotePath(settings);
    try {
      final bytes = await client.read(path);
      String? etag;
      try {
        final props = await client.readProps(path);
        etag = props.eTag;
      } catch (_) {}
      return RemoteFileResult(
        exists: true,
        body: utf8.decode(bytes),
        etag: etag,
      );
    } catch (_) {
      return const RemoteFileResult(exists: false);
    }
  }

  /// 尽力锁：写入 lock 文件后回读，确认仍是本机。过期锁可抢占。
  Future<bool> acquireLock(WebDavSettings settings, String deviceId) async {
    final client = _client(settings);
    await ensureDir(settings);
    final path = _lockPath(settings);
    try {
      final raw = utf8.decode(await client.read(path));
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final owner = json['deviceId'] as String? ?? '';
      final at = DateTime.tryParse(json['at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final age = DateTime.now().toUtc().difference(at.toUtc());
      if (owner.isNotEmpty &&
          owner != deviceId &&
          age < AppConstants.lockStaleAfter) {
        return false;
      }
    } catch (_) {
      // 无锁或损坏，继续抢占
    }

    final payload = utf8.encode(
      jsonEncode({
        'deviceId': deviceId,
        'at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    await client.write(path, Uint8List.fromList(payload));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      final check = jsonDecode(utf8.decode(await client.read(path)))
          as Map<String, dynamic>;
      return check['deviceId'] == deviceId;
    } catch (_) {
      return false;
    }
  }

  Future<void> releaseLock(WebDavSettings settings, String deviceId) async {
    final client = _client(settings);
    final path = _lockPath(settings);
    try {
      final raw = utf8.decode(await client.read(path));
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['deviceId'] != deviceId) return;
    } catch (_) {
      return;
    }
    try {
      await client.remove(path);
    } catch (_) {}
  }

  Future<String?> upload(
    WebDavSettings settings, {
    required String body,
    String? expectedEtag,
  }) async {
    final client = _client(settings);
    await ensureDir(settings);

    if (expectedEtag != null && expectedEtag.isNotEmpty) {
      final current = await readEtag(settings);
      if (current != null && current != expectedEtag) {
        throw const StaleRemoteException();
      }
    }

    final data = Uint8List.fromList(utf8.encode(body));
    final temp = _tempPath(settings);
    final dest = remotePath(settings);
    await client.write(temp, data);
    await client.write(dest, data);
    try {
      await client.remove(temp);
    } catch (_) {}
    return readEtag(settings);
  }
}
