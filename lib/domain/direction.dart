enum FavorDirection {
  inBound('in', '收到'),
  outBound('out', '送出');

  const FavorDirection(this.code, this.label);

  final String code;
  final String label;

  static FavorDirection fromCode(String code) {
    return FavorDirection.values.firstWhere(
      (e) => e.code == code,
      orElse: () => FavorDirection.outBound,
    );
  }
}
