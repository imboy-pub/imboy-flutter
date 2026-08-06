import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/qrcode/qrcode_provider.dart';

/// QrCodeNotifier 状态流转纯逻辑单测（无网络、无 UI）。
///
/// QrCodeModel 自身的 copyWith 纯逻辑已由
/// test/page/scanner/scanner_qrcode_states_test.dart 覆盖，此处不重复；
/// 本文件专注 Notifier 的 build/update/reset 状态流转。
void main() {
  group('QrCodeNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('QN-1 build 返回默认空状态', () {
      final state = container.read(qrCodeProvider);

      expect(state.qrcodeData, '');
      expect(state.expiredAt, 0);
    });

    test('QN-2 updateQrcodeData 只更新 qrcodeData 并保留 expiredAt', () {
      final notifier = container.read(qrCodeProvider.notifier);
      notifier.updateExpiredAt(123);

      notifier.updateQrcodeData('https://example.com/qr');

      final state = container.read(qrCodeProvider);
      expect(state.qrcodeData, 'https://example.com/qr');
      expect(state.expiredAt, 123);
    });

    test('QN-3 updateExpiredAt 只更新 expiredAt 并保留 qrcodeData', () {
      final notifier = container.read(qrCodeProvider.notifier);
      notifier.updateQrcodeData('token-data');

      notifier.updateExpiredAt(456);

      final state = container.read(qrCodeProvider);
      expect(state.expiredAt, 456);
      expect(state.qrcodeData, 'token-data');
    });

    test('QN-4 reset 恢复默认状态', () {
      final notifier = container.read(qrCodeProvider.notifier);
      notifier.updateQrcodeData('data');
      notifier.updateExpiredAt(789);

      notifier.reset();

      final state = container.read(qrCodeProvider);
      expect(state.qrcodeData, '');
      expect(state.expiredAt, 0);
    });

    test('QN-5 状态更新是不可变替换（旧引用不受影响）', () {
      final notifier = container.read(qrCodeProvider.notifier);
      final before = container.read(qrCodeProvider);

      notifier.updateQrcodeData('new-data');

      final after = container.read(qrCodeProvider);
      expect(identical(before, after), isFalse);
      expect(before.qrcodeData, '');
      expect(after.qrcodeData, 'new-data');
    });
  });
}
