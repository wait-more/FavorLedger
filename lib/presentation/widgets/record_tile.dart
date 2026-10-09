import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/data/local/database.dart';
import 'package:favor_ledger/domain/direction.dart';
import 'package:favor_ledger/presentation/widgets/amount_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.record,
    this.personName,
    this.onTap,
    this.onLongPress,
    this.confirmSwipeDelete,
    this.onSwipeDeleted,
  });

  final FavorRecord record;
  final String? personName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 右滑删除前确认；返回 true 才会滑出并触发 [onSwipeDeleted]。
  final Future<bool> Function()? confirmSwipeDelete;
  final VoidCallback? onSwipeDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dir = FavorDirection.fromCode(record.direction);
    final date = DateFormat('yyyy.MM.dd').format(record.occurredAt.toLocal());
    final event = record.event.isEmpty ? '未填事件' : record.event;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: dir == FavorDirection.inBound
                      ? AppColors.receive.withValues(alpha: 0.75)
                      : AppColors.give.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personName == null ? event : personName!,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        date,
                        dir.label,
                        if (personName != null) event,
                        if (record.note.isNotEmpty) record.note,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AmountText(
                // 收到为 +，送出为 −
                cents: dir == FavorDirection.inBound
                    ? record.amountCents
                    : -record.amountCents,
                signed: true,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmSwipeDelete == null || onSwipeDeleted == null) {
      return tile;
    }

    final error = theme.colorScheme.error;
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) => confirmSwipeDelete!(),
      onDismissed: (_) => onSwipeDeleted!(),
      background: ColoredBox(
        color: error,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 24),
            child: Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
        ),
      ),
      child: tile,
    );
  }
}
