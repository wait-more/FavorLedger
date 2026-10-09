import 'package:favor_ledger/core/theme.dart';
import 'package:flutter/material.dart';

/// 首页 / 流水等列表统一的下拉物理效果：短列表也能拉，并带回弹位移。
const kPullScrollPhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

class PullRefresh extends StatelessWidget {
  const PullRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.jade,
      backgroundColor: Colors.white,
      displacement: 56,
      strokeWidth: 2.4,
      // SoftPanel 等包装层可能导致 depth > 0
      notificationPredicate: (notification) => notification.depth <= 2,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
