/// 合规审计密钥 TOFU 锚定测试（审计 P1-1）
///
/// 覆盖：
/// 1. 首次获取 → 自动固定（TOFU）
/// 2. 公钥不变（仅 PEM 格式差异）→ 指纹一致，正常返回
/// 3. 服务端换钥 → 抛 ComplianceKeyChangedException（fail-closed）
/// 4. 确认轮换（accept: true）→ re-pin，可继续获取
/// 5. 拒绝轮换（accept: false）→ 保持旧 pin，继续 fail-closed
/// 6. 拉取失败 + 无缓存 → 返回 null（PolicyGate 拒发）
/// 7. 指纹计算对 PEM 头尾/换行差异鲁棒
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:imboy/service/compliance_key_service.dart';

const String _pemA =
    '-----BEGIN PUBLIC KEY-----\n'
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1234567890'
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz\n'
    '-----END PUBLIC KEY-----\n';

const String _pemB =
    '-----BEGIN PUBLIC KEY-----\n'
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA9999999999'
    'zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'
    'zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'
    'zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'
    'zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'
    'zyxwvutsrqponmlkjihgfedcbaZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'
    'ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210zyxwvutsrqponmlkjihgfedcba\n'
    '-----END PUBLIC KEY-----\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStore = <String, String?>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              secureStore[call.arguments['key'] as String] =
                  call.arguments['value'] as String?;
              return null;
            case 'read':
              return secureStore[call.arguments['key'] as String];
            case 'delete':
              secureStore.remove(call.arguments['key'] as String);
              return null;
            case 'deleteAll':
              secureStore.clear();
              return null;
            case 'readAll':
              return Map<String, String?>.from(secureStore);
            case 'containsKey':
              return secureStore.containsKey(call.arguments['key'] as String);
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  setUp(() {
    secureStore.clear();
    ComplianceKeyService.instance.clearCache();
    ComplianceKeyService.debugFetcher = null;
  });

  Map<String, dynamic> _key(String keyId, String pem) => {
    'key_id': keyId,
    'public_key': pem,
    'algorithm': 'RSA-OAEP-256',
    'created_at': '2026-08-24T00:00:00Z',
  };

  group('1. TOFU 首次固定', () {
    test('无 pin 时获取即固定并返回', () async {
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemA);
      final info = await ComplianceKeyService.instance.getComplianceKey();
      expect(info, isNotNull);
      expect(info!.keyId, 'ck_1');
      final pin = await ComplianceKeyService.instance.pinned();
      expect(pin, isNotNull);
      expect(pin!['key_id'], 'ck_1');
      expect(pin['fingerprint'], ComplianceKeyService.fingerprintOf(_pemA));
    });
  });

  group('2. PEM 表示差异鲁棒', () {
    test('换行/头尾差异不改变指纹 → 视为同一公钥', () async {
      final compact = _pemA
          .replaceAll('\n', '')
          .replaceAll('-----BEGIN PUBLIC KEY-----', '')
          .replaceAll('-----END PUBLIC KEY-----', '');
      expect(
        ComplianceKeyService.fingerprintOf(_pemA),
        ComplianceKeyService.fingerprintOf(compact),
      );
      expect(
        ComplianceKeyService.fingerprintOf(_pemA),
        isNot(ComplianceKeyService.fingerprintOf(_pemB)),
      );
    });

    test('格式差异不影响 pin 匹配', () async {
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();
      // 服务端换一种 PEM 排版返回同一把公钥
      final reflowed = _pemA.replaceAll('\n', '') + '\n';
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', reflowed);
      final info = await ComplianceKeyService.instance.getComplianceKey();
      expect(info, isNotNull);
      expect(info!.keyId, 'ck_1');
    });
  });

  group('3. 服务端换钥 → fail-closed', () {
    test('key_id 变化抛 ComplianceKeyChangedException', () async {
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => _key('ck_2', _pemA);
      expect(
        () =>
            ComplianceKeyService.instance.getComplianceKey(forceRefresh: true),
        throwsA(isA<ComplianceKeyChangedException>()),
      );
      // 旧 pin 保持不变
      final pin = await ComplianceKeyService.instance.pinned();
      expect(pin!['key_id'], 'ck_1');
    });

    test('同 key_id 但公钥变化也抛异常', () async {
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemB);
      expect(
        () =>
            ComplianceKeyService.instance.getComplianceKey(forceRefresh: true),
        throwsA(isA<ComplianceKeyChangedException>()),
      );
    });

    test('异常携带新旧标识供 UI 展示', () async {
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => _key('ck_2', _pemB);
      try {
        await ComplianceKeyService.instance.getComplianceKey(
          forceRefresh: true,
        );
        fail('should throw');
      } on ComplianceKeyChangedException catch (e) {
        expect(e.pinnedKeyId, 'ck_1');
        expect(e.observedKeyId, 'ck_2');
        expect(e.pinnedFingerprint, ComplianceKeyService.fingerprintOf(_pemA));
        expect(
          e.observedFingerprint,
          ComplianceKeyService.fingerprintOf(_pemB),
        );
      }
    });
  });

  group('4. 确认/拒绝轮换', () {
    test('accept: true → re-pin 后可正常获取', () async {
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => _key('ck_2', _pemB);
      await expectLater(
        () =>
            ComplianceKeyService.instance.getComplianceKey(forceRefresh: true),
        throwsA(isA<ComplianceKeyChangedException>()),
      );
      expect(
        await ComplianceKeyService.instance.confirmRotation(accept: true),
        isTrue,
      );
      final info = await ComplianceKeyService.instance.getComplianceKey();
      expect(info!.keyId, 'ck_2');
      final pin = await ComplianceKeyService.instance.pinned();
      expect(pin!['key_id'], 'ck_2');
    });

    test('accept: false → 保持旧 pin，继续 fail-closed', () async {
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => _key('ck_2', _pemB);
      await expectLater(
        () =>
            ComplianceKeyService.instance.getComplianceKey(forceRefresh: true),
        throwsA(isA<ComplianceKeyChangedException>()),
      );
      expect(
        await ComplianceKeyService.instance.confirmRotation(accept: false),
        isFalse,
      );
      final pin = await ComplianceKeyService.instance.pinned();
      expect(pin!['key_id'], 'ck_1');
      // 仍拒绝
      expect(
        () =>
            ComplianceKeyService.instance.getComplianceKey(forceRefresh: true),
        throwsA(isA<ComplianceKeyChangedException>()),
      );
    });
  });

  group('5. 拉取失败语义', () {
    test('无缓存且拉取失败 → null（PolicyGate 拒发）', () async {
      ComplianceKeyService.debugFetcher = () async => throw Exception('net');
      final info = await ComplianceKeyService.instance.getComplianceKey();
      expect(info, isNull);
    });

    test('有有效缓存且拉取失败 → 复用缓存（过期策略由 PolicyGate 兜底）', () async {
      ComplianceKeyService.debugFetcher = () async => _key('ck_1', _pemA);
      final first = await ComplianceKeyService.instance.getComplianceKey();
      expect(first, isNotNull);

      ComplianceKeyService.debugFetcher = () async => throw Exception('net');
      final second = await ComplianceKeyService.instance.getComplianceKey();
      expect(second, isNotNull);
      expect(second!.keyId, 'ck_1');
    });
  });
}
