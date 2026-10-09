/// 本地写入代数。同步落地时若代数变化，说明期间有新记账，需重新合并。
class ChangeEpoch {
  var _value = 0;

  int get value => _value;

  void bump() => _value++;
}
