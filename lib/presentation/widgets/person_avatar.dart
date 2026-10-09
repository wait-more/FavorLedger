import 'package:favor_ledger/core/theme.dart';
import 'package:flutter/material.dart';

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.size = 44,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '人' : name.trim().characters.first;
    final hue = (name.hashCode.abs() % 40) / 40;
    final base = Color.lerp(AppColors.jadeSoft, const Color(0xFFE8F3EE), hue)!;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, AppColors.jadeSoft.withValues(alpha: 0.85)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.jadeDeep,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
      ),
    );
  }
}
