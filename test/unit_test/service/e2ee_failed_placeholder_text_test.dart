import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/e2ee_service.dart';

/// 路径1（reason 分流）：解密失败占位文案按 `_e2ee_reason` 三分。
///
/// 「注定解不开」类（no_device_envelope / fan_out_missing_devices）：
/// 密文构造时就不含本设备信封，恢复密钥无济于事——文案必须是边界说明
/// 而非故障占位，UI 点击也不得引导去恢复（chat_page 同判据）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    LocaleSettings.setLocaleRaw('zh-CN');
  });

  group('E2EEService.isUnrecoverableDecryptFailure', () {
    test('no_device_envelope / fan_out_missing_devices 判为注定解不开', () {
      expect(
        E2EEService.isUnrecoverableDecryptFailure('no_device_envelope'),
        isTrue,
      );
      expect(
        E2EEService.isUnrecoverableDecryptFailure('fan_out_missing_devices'),
        isTrue,
      );
    });

    test('可恢复/瞬态/未知 reason 不判为注定解不开', () {
      expect(
        E2EEService.isUnrecoverableDecryptFailure('crypto_store_unavailable'),
        isFalse,
      );
      expect(
        E2EEService.isUnrecoverableDecryptFailure('decrypt_error'),
        isFalse,
      );
      expect(
        E2EEService.isUnrecoverableDecryptFailure('key_mismatch'),
        isFalse,
      );
      expect(
        E2EEService.isUnrecoverableDecryptFailure('olm_decrypt_error'),
        isFalse,
      );
      expect(E2EEService.isUnrecoverableDecryptFailure(null), isFalse);
    });
  });

  group('E2EEService.e2eeFailedPlaceholderText', () {
    test('注定解不开类返回边界说明文案，而非 [加密消息] 故障占位', () {
      final text = E2EEService.e2eeFailedPlaceholderText('no_device_envelope');
      expect(text, t.chat.e2eeMsgBeforeDevice);
      expect(text, isNot(t.chat.encryptedMessagePlaceholder));
    });

    test('crypto_store_unavailable 保持引导重试文案', () {
      expect(
        E2EEService.e2eeFailedPlaceholderText('crypto_store_unavailable'),
        t.chat.e2eeDecryptStoreUnavailable,
      );
    });

    test('其余 reason 保持通用加密占位（ADR 15 §5 不暴露失败细节）', () {
      expect(
        E2EEService.e2eeFailedPlaceholderText('decrypt_error'),
        t.chat.encryptedMessagePlaceholder,
      );
      expect(
        E2EEService.e2eeFailedPlaceholderText(null),
        t.chat.encryptedMessagePlaceholder,
      );
    });
  });
}
