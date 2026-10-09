import 'package:favor_ledger/application/providers.dart';
import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/core/utils/money.dart';
import 'package:favor_ledger/presentation/widgets/app_backdrop.dart';
import 'package:favor_ledger/presentation/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = DateTime.now().year;
    final yearAsync = ref.watch(yearStatsProvider(year));
    final summariesAsync = ref.watch(personSummariesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            PageHeader(
              title: '汇总',
              subtitle: '$year 年人情往来概览',
            ),
            const SizedBox(height: 8),
            yearAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('加载失败：$e'),
              ),
              data: (t) {
                final net = t.totalIn - t.totalOut;
                return SoftPanel(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本年往来', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              label: '送出',
                              value: centsToYuanLabel(t.totalOut),
                              tone: AppColors.give,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Metric(
                              label: '收到',
                              value: centsToYuanLabel(t.totalIn),
                              tone: AppColors.receive,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.jadeSoft.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text(
                              net >= 0 ? '本年净收到' : '本年净送出',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            Text(
                              centsToYuanLabel(net.abs()),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.jadeDeep,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
              child: Text('往来最多的人', style: theme.textTheme.titleMedium),
            ),
            summariesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('加载失败：$e'),
              ),
              data: (items) {
                final ranked = [...items]
                  ..sort((a, b) {
                    final aSum = a.totalInCents + a.totalOutCents;
                    final bSum = b.totalInCents + b.totalOutCents;
                    return bSum.compareTo(aSum);
                  });
                final top = ranked
                    .where((e) => e.totalInCents + e.totalOutCents > 0)
                    .take(10)
                    .toList();
                if (top.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('暂无数据，记几笔后再来看'),
                  );
                }
                return SoftPanel(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < top.length; i++) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        _RankTile(
                          rank: i + 1,
                          name: top[i].person.name,
                          personId: top[i].person.id,
                          outLabel: centsToYuanLabel(top[i].totalOutCents),
                          inLabel: centsToYuanLabel(top[i].totalInCents),
                          volume: centsToYuanLabel(
                            top[i].totalInCents + top[i].totalOutCents,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.rank,
    required this.name,
    required this.personId,
    required this.outLabel,
    required this.inLabel,
    required this.volume,
  });

  final int rank;
  final String name;
  final String personId;
  final String outLabel;
  final String inLabel;
  final String volume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => context.push('/person/$personId'),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: theme.textTheme.labelLarge?.copyWith(
                color: rank <= 3 ? AppColors.jade : AppColors.inkMuted,
              ),
            ),
          ),
          PersonAvatar(name: name, size: 40),
        ],
      ),
      title: Text(name),
      subtitle: Text('送出 $outLabel · 收到 $inLabel'),
      trailing: Text(
        volume,
        style: theme.textTheme.titleSmall?.copyWith(color: AppColors.jadeDeep),
      ),
    );
  }
}
