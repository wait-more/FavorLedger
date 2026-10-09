import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/core/utils/money.dart';
import 'package:favor_ledger/domain/direction.dart';
import 'package:flutter/material.dart';

class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.cents,
    this.direction,
    this.emphasize = false,
    this.compact = false,
    this.signed = false,
  });

  /// 金额（分）。`signed == true` 时可正可负（收到 − 送出）。
  final int cents;
  final FavorDirection? direction;
  final bool emphasize;
  final bool compact;

  /// 为 true 时显示 +¥ / -¥。
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color = AppColors.ink;
    if (direction == FavorDirection.inBound || (signed && cents > 0)) {
      color = AppColors.receive;
    } else if (direction == FavorDirection.outBound || (signed && cents < 0)) {
      color = AppColors.give;
    }

    final label = signed ? centsToSignedYuanLabel(cents) : centsToYuanLabel(cents);

    return Text(
      label,
      style: (emphasize ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
          ?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: compact ? -0.2 : 0,
      ),
    );
  }
}
