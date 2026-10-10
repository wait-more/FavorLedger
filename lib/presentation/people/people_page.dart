import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/application/refresh_ledger.dart';
import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/core/utils/pinyin_util.dart';
import 'package:favor_ledger/domain/direction.dart';
import 'package:favor_ledger/domain/person_summary.dart';
import 'package:favor_ledger/presentation/widgets/amount_text.dart';
import 'package:favor_ledger/presentation/widgets/app_backdrop.dart';
import 'package:favor_ledger/presentation/widgets/confirm_dialog.dart';
import 'package:favor_ledger/presentation/widgets/empty_state.dart';
import 'package:favor_ledger/presentation/widgets/person_avatar.dart';
import 'package:favor_ledger/presentation/widgets/pull_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key});

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() => refreshLedger(ref);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(personSummariesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: '人情记',
              subtitle: '以礼往来，心中有数',
              brand: true,
              actions: [
                IconButton(
                  tooltip: '添加亲友',
                  onPressed: () => context.push('/person-form'),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: '搜索亲友姓名',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: PullRefresh(
                onRefresh: _onRefresh,
                child: async.when(
                  loading: () => ListView(
                    physics: kPullScrollPhysics,
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ],
                  ),
                  error: (e, _) => ListView(
                    physics: kPullScrollPhysics,
                    children: [
                      SizedBox(
                        height: 160,
                        child: Center(child: Text('加载失败：$e')),
                      ),
                    ],
                  ),
                  data: (items) {
                    final filtered = items.where((s) {
                      if (_query.isEmpty) return true;
                      return s.person.name.contains(_query) ||
                          s.person.namePinyin.contains(_query.toLowerCase());
                    }).toList();
                    if (filtered.isEmpty) {
                      return ListView(
                        physics: kPullScrollPhysics,
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.55,
                            child: EmptyState(
                              icon: Icons.menu_book_rounded,
                              title: items.isEmpty ? '从第一位亲友开始' : '没有匹配的人',
                              subtitle: items.isEmpty
                                  ? '记下往来，礼尚往来不再靠记忆'
                                  : null,
                              actionLabel: items.isEmpty ? '添加亲友' : null,
                              onAction: items.isEmpty
                                  ? () => context.push('/person-form')
                                  : null,
                            ),
                          ),
                        ],
                      );
                    }
                    return _PeopleList(items: filtered);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.items});

  final List<PersonSummary> items;

  @override
  Widget build(BuildContext context) {
    String? lastLetter;
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final letter = nameIndexLetter(item.person.namePinyin);
      if (letter != lastLetter) {
        lastLetter = letter;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
            child: Text(
              letter,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.jade,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
        );
      }
      children.add(
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 280 + (i % 8) * 30),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - t)),
                child: child,
              ),
            );
          },
          child: _PersonTile(summary: item),
        ),
      );
    }
    return ListView(
      physics: kPullScrollPhysics,
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }
}

class _PersonTile extends ConsumerWidget {
  const _PersonTile({required this.summary});

  final PersonSummary summary;

  Future<bool> _confirmDelete(BuildContext context) {
    return showConfirmDialog(
      context,
      title: '删除亲友',
      content: '确定删除「${summary.person.name}」及其全部往来记录？',
    );
  }

  Future<void> _delete(WidgetRef ref) {
    return ref.read(ledgerActionsProvider).deletePerson(summary.person.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latest = summary.latestRecord;
    final note = summary.person.note.trim();
    String subtitle = '暂无往来';
    if (latest != null) {
      final dir = FavorDirection.fromCode(latest.direction).label;
      final date = DateFormat('yyyy.MM.dd').format(latest.occurredAt.toLocal());
      final event = latest.event.isEmpty ? '往来' : latest.event;
      subtitle = '$date · $event · $dir';
    }

    final error = theme.colorScheme.error;
    final radius = BorderRadius.circular(16);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: ValueKey(summary.person.id),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => _delete(ref),
        background: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: error,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 24),
                child: Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
        child: Material(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () => context.push('/person/${summary.person.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  PersonAvatar(name: summary.person.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: theme.textTheme.titleMedium,
                            children: [
                              TextSpan(text: summary.person.name),
                              if (note.isNotEmpty)
                                TextSpan(
                                  text: '  $note',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!summary.hasActivity)
                        Text(
                          '—',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        )
                      else
                        AmountText(
                          // 收到−送出：入超 +，出超 −
                          cents: summary.netCents,
                          signed: true,
                          compact: true,
                        ),
                      Text(
                        summary.balanceLabel,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
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
