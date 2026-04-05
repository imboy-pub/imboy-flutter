import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/encryption_mode.dart';

void main() {
  group('EncryptionMode', () {
    test('toApiString 返回正确字符串', () {
      expect(EncryptionMode.plaintext.toApiString(), 'plaintext');
      expect(EncryptionMode.complianceE2ee.toApiString(), 'compliance_e2ee');
      expect(EncryptionMode.strictE2ee.toApiString(), 'secure_e2ee');
    });

    test('fromApiString 正确解析', () {
      expect(EncryptionModeExt.fromApiString('plaintext'), EncryptionMode.plaintext);
      expect(EncryptionModeExt.fromApiString('compliance_e2ee'), EncryptionMode.complianceE2ee);
      expect(EncryptionModeExt.fromApiString('secure_e2ee'), EncryptionMode.strictE2ee);
    });

    test('fromApiString 未知值返回 plaintext', () {
      expect(EncryptionModeExt.fromApiString(null), EncryptionMode.plaintext);
      expect(EncryptionModeExt.fromApiString('unknown'), EncryptionMode.plaintext);
    });

    test('requiresEncryption 正确判断', () {
      expect(EncryptionMode.plaintext.requiresEncryption, false);
      expect(EncryptionMode.complianceE2ee.requiresEncryption, true);
      expect(EncryptionMode.strictE2ee.requiresEncryption, true);
    });

    test('requiresComplianceKey 仅 complianceE2ee 为 true', () {
      expect(EncryptionMode.plaintext.requiresComplianceKey, false);
      expect(EncryptionMode.complianceE2ee.requiresComplianceKey, true);
      expect(EncryptionMode.strictE2ee.requiresComplianceKey, false);
    });

    test('displayName 非空', () {
      for (final mode in EncryptionMode.values) {
        expect(mode.displayName.isNotEmpty, true);
      }
    });

    test('lockIcon 非空', () {
      for (final mode in EncryptionMode.values) {
        expect(mode.lockIcon.isNotEmpty, true);
      }
    });
  });
}
