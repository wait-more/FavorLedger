import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/core/utils/money.dart';
import 'package:favor_ledger/domain/direction.dart';
import 'package:favor_ledger/presentation/widgets/app_backdrop.dart';
import 'package:favor_ledger/presentation/widgets/confirm_dialog.dart';
import 'package:favor_ledger/presentation/widgets/empty_state.dart';
import 'package:favor_ledger/presentation/widgets/filter_bar.dart';
import 'package:favor_ledger/presentation/widgets/person_avatar.dart';
import 'package:favor_ledger/presentation/widgets/record_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PersonDetailPage extends ConsumerStatefulWidget {
  const PersonDetailPage({super.key, required this.personId});

  final String personId;

  @override
  ConsumerState<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends ConsumerState<PersonDetailPage> {
  FavorDirection? _filter;

  @override
  Widget build(BuildContext context) {
    final personAsync = ref.watch(personProvider(widget.personId));
    final recordsAsync = ref.watch(personRecordsProvider(widget.personId));
    final totalsAsync = ref.watch(personTotalsProvider(widget.personId));

    return AppBackdrop(
      child: personAsync.when(
        loading: () => const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: Text('加载失败：$e')),
        ),
        data: (person) {
          if (person == null || person.deletedAt != null) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(title: const Text('人不存在')),
              body: const Center(child: Text('该亲友不存在或已删除')),
            );
          }
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('亲友详情'),
              actions: [
                IconButton(
                  tooltip: '编辑',
                  onPressed: () => context.push('/person-form?id=${person.id}'),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => _confirmDelete(person.id, person.name),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/record-form?personId=${person.id}'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('记一笔'),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PersonAvatar(name: person.name, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (person.note.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                person.note.trim(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.inkMuted,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                totalsAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (t) => _TotalsHeader(
                    totalIn: t.totalIn,
                    totalOut: t.totalOut,
                  ),
                ),
                const SizedBox(height: 8),
                DirectionFilterBar(
                  value: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: recordsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('加载失败：$e')),
                    data: (records) {
                      final filtered = _filter == null
                          ? records
                          : records
                              .where((r) => r.direction == _filter!.code)
                              .toList();
                      if (filtered.isEmpty) {
                        return EmptyState(
                          icon: Icons.edit_note_rounded,
                          title: '还没有往来记录',
                          subtitle: '记一笔与 ${person.name} 的人情往来',
                          actionLabel: '记一笔',
                          onAction: () => context
                              .push('/record-form?personId=${person.id}'),
                        );
                      }
                      return SoftPanel(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(indent: 20),
                          itemBuilder: (context, index) {
                            final record = filtered[index];
                            return RecordTile(
                              record: record,
                              onTap: () => context.push(
                                '/record-form?personId=${person.id}&recordId=${record.id}',
                              ),
                              onLongPress: () =>
                                  _deleteRecord(record.id),
                              confirmSwipeDelete: _askDeleteRecord,
                              onSwipeDeleted: () => ref
                                  .read(ledgerActionsProvider)
                                  .deleteRecord(record.id),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除亲友',
      content: '确定删除「$name」及其全部往来记录？',
    );
    if (!ok || !mounted) return;
    await ref.read(ledgerActionsProvider).deletePerson(id);
    if (mounted) context.pop();
  }

  Future<bool> _askDeleteRecord() {
    return showConfirmDialog(
      context,
      title: '删除记录',
      content: '确定删除这笔往来？',
    );
  }

  Future<void> _deleteRecord(String id) async {
    final ok = await _askDeleteRecord();
    if (!ok || !mounted) return;
    await ref.read(ledgerActionsProvider).deleteRecord(id);
  }
}

class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader({required this.totalIn, required this.totalOut});

  final int totalIn;
  final int totalOut;

  @override
  Widget build(BuildContext context) {
    final net = totalIn - totalOut;
    return SoftPanel(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Stat(label: '送出', value: centsToSignedYuanLabel(-totalOut)),
          Container(width: 1, height: 36, color: AppColors.line),
          _Stat(label: '收到', value: centsToSignedYuanLabel(totalIn)),
          Container(width: 1, height: 36, color: AppColors.line),
          _Stat(
            label: net > 0
                ? '人情在彼'
                : net < 0
                    ? '人情在我'
                    : '两清',
            value: centsToSignedYuanLabel(net),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? AppColors.jade : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
