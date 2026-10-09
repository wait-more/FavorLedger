import 'package:favor_ledger/data/local/database.dart';

/// 汇总差额语义：收到 − 送出。
/// 正数 = 人情在彼（入多于出）；负数 = 人情在我（出多于入）；零 = 两清。
enum BalanceSide {
  favorWithThem,
  favorWithUs,
  even,
}

class PersonSummary {
  const PersonSummary({
    required this.person,
    required this.totalInCents,
    required this.totalOutCents,
    this.latestRecord,
  });

  final Person person;
  final int totalInCents;
  final int totalOutCents;
  final FavorRecord? latestRecord;

  /// 收到合计 − 送出合计。
  int get netCents => totalInCents - totalOutCents;

  bool get hasActivity => totalInCents + totalOutCents > 0;

  BalanceSide get balanceSide {
    if (netCents > 0) return BalanceSide.favorWithThem;
    if (netCents < 0) return BalanceSide.favorWithUs;
    return BalanceSide.even;
  }

  /// 列表展示用：含蓄、正式，不直说「谁欠谁」。
  String get balanceLabel {
    if (!hasActivity) return '暂无往来';
    switch (balanceSide) {
      case BalanceSide.favorWithThem:
        return '人情在彼';
      case BalanceSide.favorWithUs:
        return '人情在我';
      case BalanceSide.even:
        return '两清';
    }
  }
}
