// DF-20 生成二维码 → 扫码识别 → 进入目标业务：本地 API 只读闭环（纯 dart test）。
//
// 运行（本地后端 http://127.0.0.1:9800，账号来自 scripts/test.env）：
//   read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$2"; }
//   API_BASE_URL="$(read_env API_BASE_URL scripts/test.env)" \
//   TEST_PHONE="$(read_env TEST_PHONE scripts/test.env)" \
//   TEST_PASSWORD="$(read_env TEST_PASSWORD scripts/test.env)" \
//   IMBOY_ENV_PRO=.env.local \
//   dart test integration_test/demo_flow/qrcode_invite_flow_test.dart \
//     --concurrency=1
//
// 覆盖（对齐 qrcode_invite_flow.md TODO）：
//   1. 用户码生成回读：GET /api/v1/user/qrcode?id=<uid> → payload.type=user；
//   2. 无效码边界：不存在的用户 id → payload.result=user_not_exist；
//   3. 有效群码回读：A 已加入的群（join 幂等，不产生成员数变化）→
//      payload.type=group 且 group_member 含当前用户；
//      群码用例需要 A 至少在一个群：TEST_ALLOW_API_WRITES=true 时先建一个
//      DEMO-FLOW-20260817 前缀测试群（仅 A 自己，本地写入）；未开启写门禁
//      或 A 无群时跳过；
//   4. 过期群码：exp 过去时间 + 正确 tk → 业务错误「验证码已过期」；
//   5. 频道码契约缺口：客户端 buildChannelQrcodeUrl 会构造
//      /api/v1/channel/qrcode，但后端 imboy_router.erl 无此路由（探查记录）。
//
// 写入边界：group/qrcode 服务端实现会调 join_group（scan_qr_code）；
// 本测试只对 A 已加入的群发起有效群码请求，join 幂等返回（DS 层已是成员
// 返回 {ok,0}），成员数不变。无好友/入群/订阅等新增业务写入。
// 双端扫码（相机权限、第二设备识别）仍为真机验收，不在本文件范围。

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

void main() {
  late ApiTestClient clientA;
  bool ready = false;
  String skipReason = '';
  String uidA = '';
  String myGid = '';
  String signingKey = '';

  setUpAll(() async {
    clientA = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) {
      skipReason = '需要 TEST_PHONE/TEST_PASSWORD';
      return;
    }
    if (!ApiTestConfig.hasSigningKey) {
      skipReason = '群码 tk 计算需要 IMBOY_SOLIDIFIED_KEY 或 IMBOY_ENV_PRO';
      return;
    }
    final respA = await clientA.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    if (respA['code'] != 0) {
      skipReason = '登录失败（code=${respA['code']}）';
      return;
    }
    uidA = clientA.currentUid ?? '';
    if (uidA.isEmpty) {
      skipReason = '登录成功但未取到 uid';
      return;
    }

    // 取 A 已加入的第一个群（attr=join），用于幂等群码回读。
    final page = await clientA.get(
      '/api/v1/group/page',
      queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
    );
    if (page['code'] == 0) {
      final payload = page['payload'];
      final list = payload is List
          ? payload
          : payload is Map
          ? (payload['list'] ?? payload['data'] ?? const <dynamic>[])
          : const <dynamic>[];
      for (final row in list is List ? list : const <dynamic>[]) {
        if (row is Map) {
          final gid = '${row['group_id'] ?? row['gid'] ?? row['id'] ?? ''}';
          if (gid.isNotEmpty) {
            myGid = gid;
            break;
          }
        }
      }
    }
    // A 无已加入群时，在写门禁放行下建一个仅含 A 的本地测试群
    // （DEMO-FLOW-20260817 标记，可回收，不解散）。
    if (myGid.isEmpty && ApiTestConfig.allowBusinessWrites) {
      try {
        final add = await clientA.post(
          '/api/v1/group/add',
          data: {'member_uids': <String>[]},
        );
        if (add['code'] == 0) {
          final group =
              ((add['payload'] as Map?)?['group'] ?? const <String, dynamic>{})
                  as Map;
          myGid = '${group['id'] ?? group['gid'] ?? ''}';
          if (myGid.isNotEmpty) {
            // three_second_once 限流：add → edit 间隔 4s；重命名打标记便于回收。
            await Future<void>.delayed(const Duration(seconds: 4));
            await clientA.post(
              '/api/v1/group/edit',
              data: {'gid': myGid, 'title': 'DEMO-FLOW-20260817-QR-GROUP'},
            );
          }
        }
      } on StateError {
        // 未开写门禁或非本地地址：保持跳过路径。
      }
    }
    signingKey = Platform.environment['IMBOY_SOLIDIFIED_KEY']?.trim() ?? '';
    if (signingKey.isEmpty) {
      // 与 api_test_client._loadSigningKey 同源逻辑：IMBOY_ENV_PRO 指向的
      // 配置文件中读取 SOLIDIFIED_KEY（不打印值）。
      final path = Platform.environment['IMBOY_ENV_PRO']?.trim() ?? '';
      final file = File(path);
      if (file.existsSync()) {
        for (final line in file.readAsLinesSync()) {
          if (!line.startsWith('SOLIDIFIED_KEY=')) continue;
          var v = line.substring('SOLIDIFIED_KEY='.length).trim();
          if (v.length >= 2 &&
              ((v.startsWith("'") && v.endsWith("'")) ||
                  (v.startsWith('"') && v.endsWith('"')))) {
            v = v.substring(1, v.length - 1);
          }
          signingKey = v;
          break;
        }
      }
    }
    ready = true;
  });

  tearDownAll(() async {
    clientA.close();
  });

  void requireReady() {
    if (!ready) markTestSkipped(skipReason);
  }

  String tkFor(String expiredAt) =>
      crypto.md5.convert(utf8.encode('${expiredAt}_$signingKey')).toString();

  test('DF-20-1 用户码生成回读：type=user 且 id 一致', () async {
    requireReady();
    final resp = await clientA.get(
      '/api/v1/user/qrcode',
      queryParameters: {'id': uidA, 's': 'app_qrcode'},
    );
    ApiAssert.success(resp, context: 'user/qrcode');
    final payload = resp['payload'] as Map?;
    expect(payload, isNotNull, reason: 'payload 不应为空: $resp');
    expect(payload!['type'], 'user', reason: '用户码 type 应为 user: $payload');
    expect('${payload['id']}', uidA, reason: '用户码 id 应与请求一致: $payload');
    expect(
      payload.containsKey('isfriend'),
      isTrue,
      reason: '用户码应携带 isfriend 好友关系标记: $payload',
    );
  });

  test('DF-20-2 无效用户码边界：不存在用户 → user_not_exist', () async {
    requireReady();
    final resp = await clientA.get(
      '/api/v1/user/qrcode',
      queryParameters: {'id': '999999999999', 's': 'app_qrcode'},
    );
    ApiAssert.success(resp, context: 'user/qrcode not-exist');
    final payload = resp['payload'] as Map?;
    expect(
      payload?['result'],
      'user_not_exist',
      reason: '不存在的用户应返回 user_not_exist: $resp',
    );
  });

  test('DF-20-3 有效群码回读：type=group 且成员幂等（A 已在群）', () async {
    requireReady();
    if (myGid.isEmpty) {
      markTestSkipped('测试账号无已加入群，无法做幂等群码回读');
      return;
    }
    // 客户端契约（group_qrcode_page）：expiredAt 为毫秒时间戳。
    final exp = '${DateTime.now().millisecondsSinceEpoch + 600000}';
    final resp = await clientA.get(
      '/api/v1/group/qrcode',
      queryParameters: {
        'id': myGid,
        'exp': exp,
        'tk': tkFor(exp),
        's': 'app_qrcode',
      },
    );
    ApiAssert.success(resp, context: 'group/qrcode valid');
    final payload = resp['payload'] as Map?;
    expect(payload, isNotNull, reason: 'payload 不应为空: $resp');
    expect(payload!['type'], 'group', reason: '群码 type 应为 group: $payload');
    final gm = payload['group_member'];
    expect(gm, isNotNull, reason: '群码应返回扫码者群成员身份: $payload');
    final memberUid =
        '${(gm as Map)['user_id'] ?? gm['uid'] ?? gm['id'] ?? ''}';
    expect(memberUid, uidA, reason: '群成员身份应为当前登录用户（幂等 join）: $gm');
  });

  test('DF-20-4 过期群码：业务错误，不误入群', () async {
    requireReady();
    if (myGid.isEmpty) {
      markTestSkipped('测试账号无已加入群');
      return;
    }
    final exp = '${DateTime.now().millisecondsSinceEpoch - 3600000}';
    final resp = await clientA.get(
      '/api/v1/group/qrcode',
      queryParameters: {
        'id': myGid,
        'exp': exp,
        'tk': tkFor(exp),
        's': 'app_qrcode',
      },
    );
    ApiAssert.failure(resp, context: 'group/qrcode expired');
    expect('${resp['msg']}', contains('过期'), reason: '过期群码应返回「验证码已过期」: $resp');
  });

  test('DF-20-5 频道码契约缺口：后端无 /api/v1/channel/qrcode 路由', () async {
    requireReady();
    final exp = '${DateTime.now().millisecondsSinceEpoch + 600000}';
    final resp = await clientA.get(
      '/api/v1/channel/qrcode',
      queryParameters: {
        'id': '1',
        'exp': exp,
        'tk': tkFor(exp),
        's': 'app_qrcode',
      },
    );
    // 客户端 lib/page/qrcode/qrcode_url.dart 的 buildChannelQrcodeUrl 会构造
    // 该 URL，但后端 imboy_router.erl 未注册 channel/qrcode；预期非成功
    // 响应（404 或路由级错误 envelope）。本用例只固化该缺口，不判定通过。
    ApiAssert.failure(resp, context: 'channel/qrcode 契约缺口');
    expect(resp['code'], isNot(0), reason: '频道码端点不应返回成功: $resp');
  });
}
