import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/wallet/wallet_amount.dart';

void main() {
  group('wallet amount conversion', () {
    test('converts decimal yuan to exact fen without binary rounding', () {
      expect(parseYuanToFen('0.29'), 29);
      expect(parseYuanToFen('1.9'), 190);
      expect(parseYuanToFen('10'), 1000);
      expect(parseYuanToFen('10000.00'), 1000000);
    });

    test('accepts at most two decimal places', () {
      expect(parseYuanToFen('0.01'), 1);
      expect(parseYuanToFen('1.'), 100);
      expect(parseYuanToFen('0.001'), isNull);
      expect(parseYuanToFen('1.2.3'), isNull);
    });

    test('trims input and rejects non-numeric values', () {
      expect(parseYuanToFen(' 2.50 '), 250);
      expect(parseYuanToFen(''), isNull);
      expect(parseYuanToFen('-1'), isNull);
    });

    test('converts fen for display', () {
      expect(fenToYuan(29), closeTo(0.29, 0.000001));
    });
  });
}
