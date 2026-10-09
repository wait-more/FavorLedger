import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/core/constants.dart';
import 'package:favor_ledger/core/router.dart';
import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/data/sync/sync_event.dart';
import 'package:favor_ledger/presentation/widgets/soft_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavorLedgerApp extends ConsumerStatefulWidget {
  const FavorLedgerApp({super.key});

  @override
  ConsumerState<FavorLedgerApp> createState() => _FavorLedgerAppState();
}

class _FavorLedgerAppState extends ConsumerState<FavorLedgerApp>
    with WidgetsBindingObserver {
  late final _router = createRouter();
  var _launchSyncTried = false;
  var _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      ref.read(autoSyncProvider).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsStoreProvider, (prev, next) {
      next.whenData((store) async {
        if (_launchSyncTried) return;
        _launchSyncTried = true;
        final cfg = await store.loadWebDav();
        if (!cfg.autoSync || !cfg.isConfigured) return;
        try {
          await ref.read(syncHubProvider.notifier).syncNow(
                trigger: SyncTrigger.launch,
              );
        } catch (_) {
          // 失败由 SyncHub / SoftToast 提示
        }
      });
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: buildAppTheme(),
      routerConfig: _router,
      builder: (context, child) {
        return SoftToastScope(
          child: child ?? const SizedBox.shrink(),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en'),
      ],
      locale: const Locale('zh', 'CN'),
      debugShowCheckedModeBanner: false,
    );
  }
}
