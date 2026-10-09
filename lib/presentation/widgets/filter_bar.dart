import 'package:favor_ledger/core/theme.dart';
import 'package:favor_ledger/domain/direction.dart';
import 'package:flutter/material.dart';

class DirectionFilterBar extends StatelessWidget {
  const DirectionFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FavorDirection? value;
  final ValueChanged<FavorDirection?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Chip(
            label: '全部',
            selected: value == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '送出',
            selected: value == FavorDirection.outBound,
            onTap: () => onChanged(FavorDirection.outBound),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '收到',
            selected: value == FavorDirection.inBound,
            onTap: () => onChanged(FavorDirection.inBound),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.jade : Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.jade : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppColors.inkMuted,
                ),
          ),
        ),
      ),
    );
  }
}
