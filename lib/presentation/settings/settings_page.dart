import 'dart:io';

import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/application/sync_hub.dart';
import 'package:favor_ledger/core/constants.dart';
import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:favor_ledger/data/sync/sync_event.dart';
import 'package:favor_ledger/presentation/widgets/app_backdrop.dart';
import 'package:favor_ledger/presentation/widgets/soft_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _busy = false;
  var _cfgEpoch = 0;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsStoreProvider);
    final syncUi = ref.watch(syncHubProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (store) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 36),
              children: [
                const PageHeader(
                  title: '设置',
                  subtitle: '备份、导出与关于',
                ),
                const SizedBox(height: 4),
                FutureBuilder<WebDavSettings>(
                  key: ValueKey(_cfgEpoch),
                  future: store.loadWebDav(),
                  builder: (context, snap) {
                    return _SyncEntryCard(
                      syncUi: syncUi,
                      store: store,
                      cfg: snap.data,
                      onTap: () async {
                        await context.push('/settings/sync');
                        if (mounted) setState(() => _cfgEpoch++);
                      },
                    );
                  },
                ),
                SoftPanel(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('导出', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '导出到其他应用，不经过云端同步。',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      _SettingsLinkTile(
                        icon: Icons.description_outlined,
                        title: '导出 JSON',
                        subtitle: '完整账本结构，便于备份迁移',
                        enabled: !_busy,
                        onTap: () => _run(() async {
                          final json = await ref
                              .read(syncServiceProvider)
                              .exportJsonString();
                          await _shareText(json, '人情记备份.json');
                        }),
                      ),
                      const Divider(height: 22),
                      _SettingsLinkTile(
                        icon: Icons.table_rows_outlined,
                        title: '导出 CSV',
                        subtitle: '明细表格，可用表格软件打开',
                        enabled: !_busy,
                        onTap: () => _run(() async {
                          final csv = await ref
                              .read(syncServiceProvider)
                              .exportCsvString();
                          await _shareText(csv, '人情记明细.csv');
                        }),
                      ),
                    ],
                  ),
                ),
                SoftPanel(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('关于', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.jadeSoft.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: AppColors.jadeDeep,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppConstants.appName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppColors.jadeDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppConstants.appTagline,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.inkMuted,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ref.watch(packageInfoProvider).when(
                                      loading: () => Text(
                                        '版本 —',
                                        style: theme.textTheme.labelMedium,
                                      ),
                                      error: (_, _) => Text(
                                        '版本 —',
                                        style: theme.textTheme.labelMedium,
                                      ),
                                      data: (info) => Text(
                                        '版本 ${info.version}（${info.buildNumber}）',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _openRepository,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                                color: AppColors.jade,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppConstants.repositoryTitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.jadeDeep,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.jade.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                'GitHub',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openRepository() async {
    final uri = Uri.parse(AppConstants.repositoryUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      SoftToastScope.show(context, '无法打开仓库链接', error: true);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      SoftToastScope.show(context, '导出失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: AppConstants.appName),
    );
  }
}

/// 设置首页的同步入口：一眼看到状态，点进二级页再配置。
class _SyncEntryCard extends StatelessWidget {
  const _SyncEntryCard({
    required this.syncUi,
    required this.store,
    required this.cfg,
    required this.onTap,
  });

  final SyncUiState syncUi;
  final SettingsStore store;
  final WebDavSettings? cfg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = syncUi.latest;
    final lastAt = latest?.at ?? store.lastSyncAt;
    final configured = cfg?.isConfigured == true;
    final autoOn = cfg?.autoSync == true;

    final String headline;
    final String detail;
    final Color accent;

    if (syncUi.syncing) {
      headline = '正在同步';
      detail = '正在与云端核对往来…';
      accent = AppColors.jade;
    } else if (!configured) {
      headline = '云端同步';
      detail = '连接网盘后，多设备人情一本账';
      accent = AppColors.amber;
    } else if (latest?.status == SyncEventStatus.failure) {
      headline = '同步异常';
      detail = latest?.message.isNotEmpty == true
          ? latest!.message
          : '最近一次同步未成功，点此查看';
      accent = const Color(0xFFB3261E);
    } else if (lastAt != null) {
      headline = autoOn ? '自动同步已开启' : '云端同步';
      final time = DateFormat('MM-dd HH:mm').format(lastAt.toLocal());
      if (latest?.localUpdated == true) {
        detail = '最近 $time · 已从云端更新';
      } else if (latest?.uploadedToCloud == true) {
        detail = '最近 $time · 已上传';
      } else {
        detail = '最近 $time';
      }
      accent = AppColors.jadeDeep;
    } else {
      headline = autoOn ? '自动同步已开启' : '云端同步';
      detail = autoOn ? '已就绪，等待下一次同步' : '已配置，可手动同步或开启自动';
      accent = AppColors.jadeDeep;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.92),
                  AppColors.jadeSoft.withValues(alpha: 0.55),
                  AppColors.mist.withValues(alpha: 0.95),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      syncUi.syncing
                          ? Icons.sync_rounded
                          : configured
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_outlined,
                      color: accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '云端同步',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.inkMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          headline,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkMuted.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsLinkTile extends StatelessWidget {
  const _SettingsLinkTile({
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.jadeDeep, size: 20),
            ),
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
              Icons.ios_share_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
