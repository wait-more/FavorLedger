import 'package:intl/intl.dart';

final _yuanFormat = NumberFormat('#,##0.##', 'zh_CN');

int yuanToCents(String input) {
  final normalized = input.trim().replaceAll(',', '');
  if (normalized.isEmpty) {
    throw FormatException('金额不能为空');
  }
  final value = double.tryParse(normalized);
  if (value == null || value < 0) {
    throw FormatException('金额格式不正确');
  }
  return (value * 100).round();
}

String centsToYuan(int cents) {
  return _yuanFormat.format(cents / 100);
}

String centsToYuanLabel(int cents) => '¥${centsToYuan(cents)}';

/// 带正负号：入超为 +¥，出超为 -¥（signedCents = 收到 − 送出）。
String centsToSignedYuanLabel(int signedCents) {
  if (signedCents > 0) return '+¥${centsToYuan(signedCents)}';
  if (signedCents < 0) return '-¥${centsToYuan(-signedCents)}';
  return '¥0';
}
