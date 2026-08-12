/// Parses a user-entered yuan amount into integer fen without floating-point
/// rounding. Monetary input is limited to two decimal places because the
/// wallet API operates in fen.
int? parseYuanToFen(String raw) {
  final value = raw.trim();
  final match = RegExp(r'^\d+(?:\.(\d{0,2}))?$').firstMatch(value);
  if (match == null) return null;

  final whole = int.tryParse(value.split('.').first);
  if (whole == null) return null;

  final fraction = (match.group(1) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(fraction);
}

double fenToYuan(int fen) => fen / 100.0;
