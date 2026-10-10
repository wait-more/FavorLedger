import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/application/refresh_ledger.dart';
import 'package:favor_ledger/domain/direction.dart';
import 'package:favor_ledger/presentation/widgets/app_backdrop.dart';
import 'package:favor_ledger/presentation/widgets/confirm_dialog.dart';
import 'package:favor_ledger/presentation/widgets/empty_state.dart';
import 'package:favor_ledger/presentation/widgets/filter_bar.dart';
import 'package:favor_ledger/presentation/widgets/person_picker_field.dart';
import 'package:favor_ledger/presentation/widgets/pull_refresh.dart';
import 'package:favor_ledger/presentation/widgets/record_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FlowPage extends ConsumerStatefulWidget {
  const FlowPage({super.key});

  @override
  ConsumerState<FlowPage> createState() => _FlowPageState();
}

class _FlowPageState extends ConsumerState<FlowPage> {
  FavorDirection? _direction;
  String? _personId;
  String _query = '';

  Future<void> _onRefresh() => refreshLedger(ref);

  @override
  Widget build(BuildContext context) {
    final flowAsync = ref.watch(flowProvider);
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: '流水',
              subtitle: '按时间回顾每一笔往来',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索事件 / 备注 / 姓名',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            DirectionFilterBar(
              value: _direction,
              onChanged: (v) => setState(() => _direction = v),
            ),
            const SizedBox(height: 10),
            peopleAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (people) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PersonPickerField(
                    people: people,
                    value: _personId,
                    labelText: '按亲友筛选',
                    hintText: '选择亲友',
                    allowClear: true,
                    clearLabel: '全部亲友',
                    isDense: true,
                    onChanged: (v) => setState(() => _personId = v),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: PullRefresh(
                onRefresh: _onRefresh,
                child: flowAsync.when(
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
                    final filtered = items.where((item) {
                      if (_direction != null &&
                          item.record.direction != _direction!.code) {
                        return false;
                      }
                      if (_personId != null &&
                          item.record.personId != _personId) {
                        return false;
                      }
                      if (_query.isEmpty) return true;
                      final q = _query.toLowerCase();
                      return item.personName.toLowerCase().contains(q) ||
                          item.record.event.toLowerCase().contains(q) ||
                          item.record.note.toLowerCase().contains(q);
                    }).toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        physics: kPullScrollPhysics,
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.45,
                            child: EmptyState(
                              icon: Icons.view_timeline_rounded,
                              title: items.isEmpty ? '流水还是空白' : '没有匹配的记录',
                              subtitle:
                                  items.isEmpty ? '点右下角「记一笔」写下第一笔' : null,
                            ),
                          ),
                        ],
                      );
                    }

                    return SoftPanel(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: EdgeInsets.zero,
                      child: ListView.separated(
                        physics: kPullScrollPhysics,
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(indent: 20, endIndent: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return RecordTile(
                            record: item.record,
                            personName: item.personName,
                            onTap: () => context.push(
                              '/record-form?personId=${item.record.personId}&recordId=${item.record.id}',
                            ),
                            confirmSwipeDelete: _askDeleteRecord,
                            onSwipeDeleted: () => ref
                                .read(ledgerActionsProvider)
                                .deleteRecord(item.record.id),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _askDeleteRecord() {
    return showConfirmDialog(
      context,
      title: '删除记录',
      content: '确定删除这笔往来？',
    );
  }
}
