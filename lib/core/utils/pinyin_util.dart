import 'package:lpinyin/lpinyin.dart';

String nameToPinyin(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';
  final pinyin = PinyinHelper.getPinyinE(
    trimmed,
    separator: '',
    defPinyin: '#',
    format: PinyinFormat.WITHOUT_TONE,
  );
  return pinyin.toLowerCase();
}

String nameIndexLetter(String namePinyin) {
  if (namePinyin.isEmpty) return '#';
  final c = namePinyin[0].toUpperCase();
  if (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0) return c;
  return '#';
}
