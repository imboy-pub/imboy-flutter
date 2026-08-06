// test/api/e2ee_backup_api_test.dart
//
// E2EE 云端密钥备份契约测试（P0-B B3，纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/e2ee_backup_api_test.dart --concurrency=1
//
// 契约要点（对应后端 e2ee_backup_logic）：
//   - 未认证访问被拒
//   - put 版本必须 = 当前最新 + 1，否则 409 version_conflict
//   - put→get 密文 base64 逐字节一致（零信任透传）
//   - info 不含 encrypted_payload / kdf_salt
//   - PEM 明文 payload 被 400 拒收
//   - delete 清空后 info.has_backup=false
//
// 安全护栏：若测试账号已存在真实云端备份（has_backup=true 且非本测试所建），
// 跳过全部写测试，防止 delete 摧毁真实备份。

@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';

import 'api_test_client.dart';

const _putPath = '/api/v1/e2ee/backup/put';
const _getPath = '/api/v1/e2ee/backup/get';
const _infoPath = '/api/v1/e2ee/backup/info';
const _deletePath = '/api/v1/e2ee/backup/delete';

Map<String, dynamic> _putBody({
  required int version,
  String? payload,
  int iterations = 310000,
}) {
  return {
    'backup_version': version,
    'algo': 'pbkdf2-sha256/aes-256-gcm',
    'kdf_salt': base64.encode(utf8.encode('contract-test-salt')),
    'kdf_iterations': iterations,
    'encrypted_payload':
        payload ?? base64.encode(utf8.encode('opaque-contract-cipher')),
    'payload_hash': 'deadbeefcafe0123',
  };
}

void main() {
  if (!ApiTestConfig.isConfigured) {
    test('skipped: TEST_PHONE/TEST_PASSWORD 未配置', () {}, skip: true);
    return;
  }

  late ApiTestClient client;
  var hadPreexistingBackup = false;

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    final info = await client.get(_infoPath);
    hadPreexistingBackup =
        info['code'] == 0 &&
        (info['payload'] as Map<String, dynamic>?)?['has_backup'] == true;
  });

  test('未认证访问 info 被拒', () async {
    final anon = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    final resp = await anon.get(_infoPath);
    expect(resp['code'], isNot(0), reason: '未登录不得访问备份端点');
  });

  group('put/get/info/delete 全链路（写测试）', () {
    test('版本单调 + 密文逐字节透传 + 明文拒收 + 删除', () async {
      if (hadPreexistingBackup) {
        markTestSkipped('测试账号已有真实云端备份，跳过写测试防摧毁');
        return;
      }

      // 1. put v1
      final payload1 = base64.encode(
        utf8.encode('cipher-v1-${DateTime.now().millisecondsSinceEpoch}'),
      );
      final put1 = await client.post(
        _putPath,
        data: _putBody(version: 1, payload: payload1),
      );
      expect(put1['code'], 0, reason: '首版本 put 应成功: $put1');

      // 2. 重放 v1 → 409 版本冲突
      final replay = await client.post(
        _putPath,
        data: _putBody(version: 1, payload: payload1),
      );
      expect(replay['code'], 409, reason: '重放同版本应 409: $replay');

      // 3. 跳版本 v3 → 409
      final skip = await client.post(_putPath, data: _putBody(version: 3));
      expect(skip['code'], 409, reason: '跳版本应 409: $skip');

      // 4. put v2 后 get 应返回 v2 密文，逐字节一致
      final payload2 = base64.encode(utf8.encode('cipher-v2-newer'));
      final put2 = await client.post(
        _putPath,
        data: _putBody(version: 2, payload: payload2),
      );
      expect(put2['code'], 0, reason: 'v2 put 应成功: $put2');

      final got = await client.get(_getPath);
      expect(got['code'], 0);
      final row = got['payload'] as Map<String, dynamic>;
      expect(row['encrypted_payload'], payload2, reason: '密文必须逐字节透传');
      expect(row['backup_version'], 2);

      // 5. info 不含密文与盐值
      final info = await client.get(_infoPath);
      expect(info['code'], 0);
      final infoPayload = info['payload'] as Map<String, dynamic>;
      expect(infoPayload['has_backup'], true);
      expect(infoPayload.containsKey('encrypted_payload'), false);
      expect(infoPayload.containsKey('kdf_salt'), false);

      // 6. PEM 明文拒收
      final pem = await client.post(
        _putPath,
        data: _putBody(
          version: 3,
          payload: base64.encode(
            utf8.encode('-----BEGIN RSA PRIVATE KEY-----\nfake'),
          ),
        ),
      );
      expect(pem['code'], 400, reason: 'PEM 明文应 400 拒收: $pem');

      // 7. 低迭代次数拒收（防降级攻击）
      final lowIter = await client.post(
        _putPath,
        data: _putBody(version: 3, iterations: 1000),
      );
      expect(lowIter['code'], 400, reason: '低迭代次数应 400: $lowIter');

      // 8. 清理：delete 全部 → info 归零
      final del = await client.post(_deletePath);
      expect(del['code'], 0);
      final after = await client.get(_infoPath);
      expect(
        (after['payload'] as Map<String, dynamic>)['has_backup'],
        false,
        reason: '删除后应无备份',
      );
    });
  });
}
