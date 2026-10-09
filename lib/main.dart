import 'package:favor_ledger/app.dart';
import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/data/prefs/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.create();
  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWith((ref) async => settings),
      ],
      child: const FavorLedgerApp(),
    ),
  );
}
