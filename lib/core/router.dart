import 'package:favor_ledger/presentation/flow/flow_page.dart';
import 'package:favor_ledger/presentation/people/people_page.dart';
import 'package:favor_ledger/presentation/person_detail/person_detail_page.dart';
import 'package:favor_ledger/presentation/person_form/person_form_page.dart';
import 'package:favor_ledger/presentation/record_form/record_form_page.dart';
import 'package:favor_ledger/presentation/settings/settings_page.dart';
import 'package:favor_ledger/presentation/settings/sync_settings_page.dart';
import 'package:favor_ledger/presentation/shell/home_shell.dart';
import 'package:favor_ledger/presentation/stats/stats_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/people',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/people',
                builder: (context, state) => const PeoplePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/flow',
                builder: (context, state) => const FlowPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings/sync',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SyncSettingsPage(),
      ),
      GoRoute(
        path: '/person/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PersonDetailPage(personId: id);
        },
      ),
      GoRoute(
        path: '/person-form',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return PersonFormPage(personId: id);
        },
      ),
      GoRoute(
        path: '/record-form',
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          final personId = state.uri.queryParameters['personId'];
          final recordId = state.uri.queryParameters['recordId'];
          return RecordFormPage(personId: personId, recordId: recordId);
        },
      ),
    ],
  );
}
