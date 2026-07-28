import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/fallback_key_signature.dart';
import 'package:imboy/store/api/olm_api.dart';

/// E2EE-062 残留 2：**客户端为 fallback key 签名**。
///
/// == 缺口 ==
///
/// 服务端上一刀已能验签（`report_fallback_key/5`），但**客户端不发送签名**——
/// 与第四刀 `request_id` 完全同形：服务端做的工作在生产流量上等于零，
/// 且服务端因此无法把签名改为必填（改了所有设备都发布不了 fallback key）。
///
/// == 守护 ==
///
/// 1. **跨语言 golden vector**：canonical 必须与服务端 `fallback_canonical/4`
///    **逐字节一致**。不一致的后果不是"少一层防护"，而是**验签必然失败 →
///    该设备发布不了 fallback key → 每次 OTK 耗尽变 `no_prekey_available`**，
///    是一次生产可用性事故。对侧断言：imboy
///    `test/logic/e2ee_fallback_signature_tests.erl` 的 `canonical_golden_vector`；
/// 2. 字段顺序固定为 ASCII 字典序、末字段无尾随换行；
/// 3. 签名必须真的进入请求体（生产开关本身）；
/// 4. 【正向可用性】签名为空时**不得**写入该键（旧语义零破坏）。
void main() {
  group('fallbackKeyCanonical', () {
    // ⚠️ 与服务端逐字节相同的字面量。改动任一侧都必须同步改另一侧，
    // 否则线上验签全线失败。
    const golden =
        'device_id=dev-fb-A\n'
        'key_base64=ZmFsbGJhY2sta2V5LWJ5dGVz\n'
        'key_id=fbkey-1\n'
        'user_id=6001';

    test('跨语言 golden vector：必须与服务端逐字节一致', () {
      final actual = fallbackKeyCanonical(
        userId: '6001',
        deviceId: 'dev-fb-A',
        keyId: 'fbkey-1',
        keyBase64: 'ZmFsbGJhY2sta2V5LWJ5dGVz',
      );
      expect(actual, golden);
      expect(
        actual.length,
        82,
        reason:
            '长度也是向量的一部分：长度对不上说明编码规则理解错了，'
            '此时再比内容只会得到无信息量的“不相等”',
      );
    });

    test('末字段无尾随换行', () {
      final actual = fallbackKeyCanonical(
        userId: '1',
        deviceId: 'd',
        keyId: 'k',
        keyBase64: 'b',
      );
      expect(actual.endsWith('\n'), isFalse);
      expect(actual, 'device_id=d\nkey_base64=b\nkey_id=k\nuser_id=1');
    });

    test('字段顺序固定为 ASCII 字典序', () {
      final actual = fallbackKeyCanonical(
        userId: '9',
        deviceId: 'D',
        keyId: 'K',
        keyBase64: 'B',
      );
      final keys = actual.split('\n').map((l) => l.split('=').first).toList();
      expect(keys, ['device_id', 'key_base64', 'key_id', 'user_id']);
      final sorted = [...keys]..sort();
      expect(keys, sorted, reason: '顺序必须与服务端一致，否则签名对不上');
    });
  });

  group('fallback 上报请求体', () {
    test('签名非空时必须进入请求体', () {
      final body = OlmApi.buildFallbackBody(
        deviceId: 'dev-A',
        keyId: 'k1',
        keyBase64: 'b1',
        signature: 'c2ln',
      );
      expect(body['device_id'], 'dev-A');
      expect(body['key_id'], 'k1');
      expect(body['key_base64'], 'b1');
      expect(body['signature'], 'c2ln', reason: '签名不进请求体 = 服务端上一刀的验签在生产上等于零');
    });

    test('正向可用性：签名为空时不得写入该键（旧语义零破坏）', () {
      final body = OlmApi.buildFallbackBody(
        deviceId: 'dev-A',
        keyId: 'k1',
        keyBase64: 'b1',
        signature: '',
      );
      expect(body.containsKey('signature'), isFalse);
      expect(body['device_id'], 'dev-A');
    });
  });
}
