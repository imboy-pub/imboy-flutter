import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/scanner/scanner_provider.dart';
import 'package:imboy/page/qrcode/qrcode_provider.dart';

void main() {
  group('ScannerState', () {
    test('ST-1 默认值', () {
      const s = ScannerState();
      expect(s.barcodeStr, isNull);
      expect(s.barcode, isNull);
      expect(s.capture, isNull);
      expect(s.isStarted, true);
      expect(s.attainableResult, true);
      expect(s.isProcessing, false);
    });

    test('ST-2 copyWith 覆盖布尔与字符串', () {
      const s = ScannerState();
      final n = s.copyWith(
        barcodeStr: 'data',
        isStarted: false,
        attainableResult: false,
        isProcessing: true,
      );
      expect(n.barcodeStr, 'data');
      expect(n.isStarted, false);
      expect(n.attainableResult, false);
      expect(n.isProcessing, true);
    });

    test('ST-3 copyWith 不传保留原值', () {
      const s = ScannerState(barcodeStr: 'x', isProcessing: true);
      final n = s.copyWith(isStarted: false);
      expect(n.barcodeStr, 'x');
      expect(n.isProcessing, true);
      expect(n.isStarted, false);
    });
  });

  group('QrCodeModel', () {
    test('QC-1 默认值', () {
      const m = QrCodeModel();
      expect(m.qrcodeData, '');
      expect(m.expiredAt, 0);
    });

    test('QC-2 copyWith 覆盖', () {
      const m = QrCodeModel();
      final n = m.copyWith(qrcodeData: 'token', expiredAt: 123);
      expect(n.qrcodeData, 'token');
      expect(n.expiredAt, 123);
    });

    test('QC-3 copyWith 不传保留原值', () {
      const m = QrCodeModel(qrcodeData: 'token', expiredAt: 123);
      final n = m.copyWith(expiredAt: 456);
      expect(n.qrcodeData, 'token');
      expect(n.expiredAt, 456);
    });
  });
}
