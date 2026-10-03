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

  Map<String, dynamic> buildKey(String keyId, String pem) => {
    'key_id': keyId,
    'public_key': pem,
    'algorithm': 'RSA-OAEP-256',
    'created_at': '2026-08-24T00:00:00Z',
  };

  group('1. TOFU 首次固定', () {
    test('无 pin 时获取即固定并返回', () async {
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
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
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();
      // 服务端换一种 PEM 排版返回同一把公钥
      final reflowed = '${_pemA.replaceAll('\n', '')}\n';
      ComplianceKeyService.debugFetcher = () async =>
          buildKey('ck_1', reflowed);
      final info = await ComplianceKeyService.instance.getComplianceKey();
      expect(info, isNotNull);
      expect(info!.keyId, 'ck_1');
    });
  });

  group('3. 服务端换钥 → fail-closed', () {
    test('key_id 变化抛 ComplianceKeyChangedException', () async {
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => buildKey('ck_2', _pemA);
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
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemB);
      expect(
        () =>
            ComplianceKeyService.instance.getComplianceKey(forceRefresh: true),
        throwsA(isA<ComplianceKeyChangedException>()),
      );
    });

    test('异常携带新旧标识供 UI 展示', () async {
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => buildKey('ck_2', _pemB);
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
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => buildKey('ck_2', _pemB);
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
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async => buildKey('ck_2', _pemB);
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
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      final first = await ComplianceKeyService.instance.getComplianceKey();
      expect(first, isNotNull);

      ComplianceKeyService.debugFetcher = () async => throw Exception('net');
      final second = await ComplianceKeyService.instance.getComplianceKey();
      expect(second, isNotNull);
      expect(second!.keyId, 'ck_1');
    });
  });

  // ====================================================================
  // C06（run-20261003-094804）：TOFU 首钥注入局限——characterization。
  //
  // ⚠️ 如实记录（不得宣称已防）：TOFU 只能防「已固定后的服务端偷换」；
  // **首次**接触的恶意服务端可注入自己的公钥，客户端无锚可比对，静默
  // 固定攻击者密钥 → compliance 模式全部密文攻击者可解（双 wrap 设计内
  // 的第二份接收方）。与 X3DH 首触同理；根治需 Key Transparency
  // （台账 IMB-2026-007）。以下测试钉住该边界**行为**，防止未来有人把
  // 「fail-closed 换钥检测」误读为「首触已防护」。
  // ====================================================================
  group('6. C06 — 首钥注入局限（如实记录，设计内未防）', () {
    test('首次拉取即注入攻击者公钥 → 无异常、直接固定（局限钉现状）', () async {
      // 恶意服务端在客户端**首次**拉取时返回攻击者公钥（无 prior pin）
      ComplianceKeyService.debugFetcher = () async =>
          buildKey('ck_evil', _pemB);
      final info = await ComplianceKeyService.instance.getComplianceKey();
      // 不抛异常、正常返回 —— 这是设计内局限，不是防御成功：
      expect(info, isNotNull);
      expect(info!.keyId, 'ck_evil');
      // 攻击者公钥被 TOFU 固定为锚
      final pin = await ComplianceKeyService.instance.pinned();
      expect(pin!['key_id'], 'ck_evil');
      expect(pin['fingerprint'], ComplianceKeyService.fingerprintOf(_pemB));
    });

    test('注入锚定后管理员真正换回诚实密钥 → 客户端 fail-closed 拒发', () async {
      // 首钥已被污染锚定后，诚实密钥反而会被当成「疑似偷换」拦截——
      // fail-closed 方向正确（拒发不降级），但确认轮换的 UI 语义无法
      // 区分「攻击者换钥」与「管理员换钥」，用户确认是唯一出口。
      ComplianceKeyService.debugFetcher = () async =>
          buildKey('ck_evil', _pemB);
      await ComplianceKeyService.instance.getComplianceKey();

      ComplianceKeyService.debugFetcher = () async =>
          buildKey('ck_good', _pemA);
      expect(
        () =>
            ComplianceKeyService.instance.getComplianceKey(forceRefresh: true),
        throwsA(isA<ComplianceKeyChangedException>()),
      );
    });

    test('confirmRotation 无 pending 时恒 false（不能无中生有 re-pin）', () async {
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();
      // 没有 observed 变更时，确认轮换是 no-op 且返回 false
      expect(
        await ComplianceKeyService.instance.confirmRotation(accept: true),
        isFalse,
      );
      // pin 不变
      final pin = await ComplianceKeyService.instance.pinned();
      expect(pin!['key_id'], 'ck_1');
    });

    test('SecureStorage pin 数据损坏（坏 JSON）→ 视为无 pin → 重开首钥窗口', () async {
      // 局限如实记录：pin 存储损坏后退化为「首次接触」，重新暴露首钥
      // 注入窗口（fail-open 方向；与 SecureStorage 被清空等价）。
      ComplianceKeyService.debugFetcher = () async => buildKey('ck_1', _pemA);
      await ComplianceKeyService.instance.getComplianceKey();
      // 模拟 pin 记录损坏
      secureStore['compliance_key_pin_v1'] = 'not-json{';
      ComplianceKeyService.instance.clearCache();

      ComplianceKeyService.debugFetcher = () async =>
          buildKey('ck_evil', _pemB);
      final info = await ComplianceKeyService.instance.getComplianceKey();
      // 坏 pin 被当作无 pin → 攻击者公钥重新 TOFU 固定
      expect(info!.keyId, 'ck_evil');
      final pin = await ComplianceKeyService.instance.pinned();
      expect(pin!['key_id'], 'ck_evil');
    });
  });
}
