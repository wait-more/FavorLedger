import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/application/sync_hub.dart';
import 'package:favor_ledger/core/sync_messages.dart';
import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:favor_ledger/data/remote/webdav_service.dart';
import 'package:favor_ledger/data/sync/sync_event.dart';
import 'package:favor_ledger/presentation/widgets/app_backdrop.dart';
import 'package:favor_ledger/presentation/widgets/soft_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// WebDAV 连接、自动同步与手动同步操作。
class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _webDav = WebDavService();
  var _autoSync = false;
  var _loaded = false;
  var _busy = false;
  var _checkingAutoSync = false;
  var _formExpanded = true;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _ensureLoaded(SettingsStore store) async {
    if (_loaded) return;
    final cfg = await store.loadWebDav();
    _url.text = cfg.baseUrl;
    _user.text = cfg.username;
    _password.text = cfg.password;
    _autoSync = cfg.autoSync;
    _formExpanded = !cfg.isConfigured;
    _loaded = true;
  }

  WebDavSettings _currentSettings() => WebDavSettings(
        baseUrl: _url.text,
        username: _user.text,
        password: _password.text,
        autoSync: _autoSync,
      );

  String get _configSummary {
    final url = _url.text.trim();
    if (url.isEmpty) return '尚未填写网盘地址';
    try {
      final uri = Uri.parse(url);
      final host = uri.host.isEmpty ? url : uri.host;
      final user = _user.text.trim();
      return user.isEmpty ? host : '$user · $host';
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsStoreProvider);
    final syncUi = ref.watch(syncHubProvider);
    final theme = Theme.of(context);

    return AppBackdrop(
      child: GestureDetector(
        onTap: _unfocus,
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('云端同步'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
            data: (store) {
              return FutureBuilder(
                future: _ensureLoaded(store),
                builder: (context, _) {
                  return ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
                    children: [
                      SoftPanel(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _SyncStatusBlock(syncUi: syncUi, store: store),
                      ),
                      SoftPanel(
                        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('连接', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '账本备份到你的网盘 WebDAV，多设备可合并往来。',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            Material(
                              color: AppColors.mist.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  _unfocus();
                                  setState(
                                    () => _formExpanded = !_formExpanded,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.jadeSoft
                                              .withValues(alpha: 0.7),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.dns_outlined,
                                          size: 18,
                                          color: AppColors.jadeDeep,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formExpanded
                                                  ? '收起连接信息'
                                                  : '连接信息',
                                              style: theme.textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _configSummary,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        _formExpanded
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                        color: AppColors.inkMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            AnimatedCrossFade(
                              firstChild:
                                  const SizedBox(width: double.infinity),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _url,
                                      decoration: const InputDecoration(
                                        labelText: 'WebDAV 路径',
                                        hintText:
                                            'https://dav.example.com/dav',
                                        helperText:
                                            '填写网盘 WebDAV 地址即可，应用会自动使用 FavorLedger 目录',
                                      ),
                                      keyboardType: TextInputType.url,
                                      textInputAction: TextInputAction.next,
                                      onTapOutside: (_) => _unfocus(),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _user,
                                      decoration: const InputDecoration(
                                        labelText: '账号',
                                      ),
                                      textInputAction: TextInputAction.next,
                                      onTapOutside: (_) => _unfocus(),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _password,
                                      decoration: const InputDecoration(
                                        labelText: '密码 / 应用专用密码',
                                      ),
                                      obscureText: true,
                                      textInputAction: TextInputAction.done,
                                      onTapOutside: (_) => _unfocus(),
                                      onSubmitted: (_) => _unfocus(),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _run(() async {
                                                      _unfocus();
                                                      await _webDav
                                                          .checkAvailability(
                                                        _currentSettings(),
                                                      );
                                                      _toast('连接正常');
                                                    }),
                                            child: const Text('测试连接'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _run(() async {
                                                      _unfocus();
                                                      await store.saveWebDav(
                                                        _currentSettings(),
                                                      );
                                                      if (mounted) {
                                                        setState(
                                                          () => _formExpanded =
                                                              false,
                                                        );
                                                      }
                                                      _toast('已保存');
                                                    }),
                                            child: const Text('保存'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              crossFadeState: _formExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 220),
                            ),
                          ],
                        ),
                      ),
                      SoftPanel(
                        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('自动同步', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '开启后：启动、回前台、改账防抖与定时拉取都会同步。',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _autoSync ? '已开启' : '已关闭',
                                style: theme.textTheme.titleSmall,
                              ),
                              secondary: _checkingAutoSync
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : Icon(
                                      _autoSync
                                          ? Icons.sync_rounded
                                          : Icons.sync_disabled_rounded,
                                      color: _autoSync
                                          ? AppColors.jade
                                          : AppColors.inkMuted,
                                    ),
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppColors.jade,
                              value: _autoSync,
                              onChanged: (_busy || _checkingAutoSync)
                                  ? null
                                  : (v) {
                                      _unfocus();
                                      _onAutoSyncChanged(store, v);
                                    },
                            ),
                          ],
                        ),
                      ),
                      SoftPanel(
                        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('手动操作', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 12),
                            _ActionTile(
                              icon: Icons.sync_rounded,
                              title: '立即同步',
                              subtitle: '拉取云端合并后写回',
                              enabled: !_busy && !syncUi.syncing,
                              onTap: () => _runSync(() async {
                                _unfocus();
                                await store.saveWebDav(_currentSettings());
                                await ref
                                    .read(syncHubProvider.notifier)
                                    .syncNow(trigger: SyncTrigger.manual);
                              }),
                            ),
                            const Divider(height: 20),
                            _ActionTile(
                              icon: Icons.cloud_upload_outlined,
                              title: '仅上传备份',
                              subtitle: '仍会先合并远程，避免覆盖他端',
                              enabled: !_busy && !syncUi.syncing,
                              onTap: () => _runSync(() async {
                                _unfocus();
                                await store.saveWebDav(_currentSettings());
                                await ref
                                    .read(syncHubProvider.notifier)
                                    .uploadOnly(trigger: SyncTrigger.manual);
                              }),
                            ),
                            const Divider(height: 20),
                            _ActionTile(
                              icon: Icons.cloud_download_outlined,
                              title: '从远程恢复',
                              subtitle: '与云端合并恢复往来',
                              enabled: !_busy && !syncUi.syncing,
                              onTap: () => _runSync(() async {
                                _unfocus();
                                await store.saveWebDav(_currentSettings());
                                await ref
                                    .read(syncHubProvider.notifier)
                                    .restoreFromRemote(
                                      trigger: SyncTrigger.manual,
                                      merge: true,
                                    );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onAutoSyncChanged(SettingsStore store, bool enable) async {
    if (!enable) {
      setState(() => _autoSync = false);
      try {
        await store.saveWebDav(_currentSettings());
      } catch (_) {
        if (mounted) setState(() => _autoSync = true);
        _toast('保存失败', error: true);
      }
      return;
    }

    setState(() => _checkingAutoSync = true);
    try {
      final draft = _currentSettings().copyWith(autoSync: false);
      await _webDav.checkAvailability(draft);
      if (!mounted) return;
      setState(() => _autoSync = true);
      await store.saveWebDav(_currentSettings());
      // 开启后立刻同步一次，不必等启动/改账/定时
      try {
        await ref.read(syncHubProvider.notifier).syncNow(
              trigger: SyncTrigger.auto,
            );
      } catch (_) {
        // SyncHub 已 toast；开关保持开启
      }
    } catch (e) {
      if (mounted) setState(() => _autoSync = false);
      _toast(friendlySyncError(e), error: true);
    } finally {
      if (mounted) setState(() => _checkingAutoSync = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast(friendlySyncError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runSync(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      // SyncHub 已 toast
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    SoftToastScope.show(context, message, error: error);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Row(
          children: [
            Icon(icon, color: AppColors.jadeDeep, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusBlock extends StatelessWidget {
  const _SyncStatusBlock({required this.syncUi, required this.store});

  final SyncUiState syncUi;
  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = syncUi.latest;
    final lastAt = latest?.at ?? store.lastSyncAt;

    final statusLabel = syncUi.syncing
        ? '同步中…'
        : latest == null
            ? '尚未同步'
            : latest.status == SyncEventStatus.failure
                ? '同步失败'
                : latest.localUpdated
                    ? '已从云端更新'
                    : latest.uploadedToCloud
                        ? '已同步到云端'
                        : '已同步';

    final statusColor = syncUi.syncing
        ? AppColors.jade
        : latest?.status == SyncEventStatus.failure
            ? const Color(0xFFB3261E)
            : AppColors.jadeDeep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('同步状态', style: theme.textTheme.titleMedium),
        const SizedBox(height: 14),
        _StatusRow(
          label: '状态',
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (syncUi.syncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StatusRow(
          label: '最近同步时间',
          child: Text(
            lastAt == null
                ? '—'
                : DateFormat('yyyy-MM-dd HH:mm').format(lastAt.toLocal()),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (latest != null && latest.message.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StatusRow(
            label: '说明',
            child: Text(
              latest.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: latest.status == SyncEventStatus.failure
                    ? const Color(0xFFB3261E)
                    : AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
