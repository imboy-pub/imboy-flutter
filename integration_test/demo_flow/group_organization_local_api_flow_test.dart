// DF-15 群分类/标签 → 群二维码 → 邀请入群 本地后端 API 闭环 flow 测试（纯 Dart）。
//
// 覆盖：
//   1. 群分类创建（DEMO-FLOW-20260817 前缀）→ category/list 回读；
//   2. 群标签添加并绑定测试群 → tag/list 回读；
//   3. 群二维码内容 URL 构造（复刻 lib/page/qrcode/qrcode_url.dart 的
//      buildGroupQrcodeUrl：md5(exp_solidifiedKey)）→ GET /api/v1/group/qrcode
//      服务端 tk 校验与入群分支（测试账号已入群，幂等）；
//   4. 无效 tk 的负向安全验证（302 重定向，不误入群）。
//
// 扫码入群完整闭环（第二设备扫真实二维码）无第二设备，保持阻塞（flow 文档记录）。
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 TEST_PHONE=... TEST_PASSWORD=... \
//   IMBOY_SOLIDIFIED_KEY=... TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/group_organization_local_api_flow_test.dart \
//     --concurrency=1

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';
import '../../test/unit_test/api/api_test_client.dart';

const _prefix = 'DEMO-FLOW-20260819';
final _runTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

void _log(String msg) => stderr.writeln('[DF15-LOCAL] $msg');

List<Map<String, dynamic>> _asList(dynamic payload, String key) {
  final list = payload is Map ? payload[key] : null;
  if (list is! List) return const [];
  return list
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

String _md5(String s) => crypto.md5.convert(utf8.encode(s)).toString();

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String gid = '';

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (!loggedIn) {
      _log('登录失败: ${resp['msg']}');
      return;
    }
    _log('登录成功 uid=${client.currentUid}');

    // DEMO-FLOW 群自举（DF-10/DF14 已建，group/add 按成员集合幂等）。
    // 注意：本地测试账号是多会话共用的，group/page(attr=owner) 会列出
    // 其他会话建的 DEMO-FLOW 群；必须按本 flow 的确切群名匹配，
    // 且 attr=join 过滤已激活成员，避免误选。
    const expectedTitle = 'DEMO-FLOW-20260817-COLLAB';
    final page = await client.get(
      '/api/v1/group/page',
      queryParameters: {'page': 1, 'size': 50, 'attr': 'owner'},
    );
    if (page['code'] == 0) {
      final items = payloadList(page['payload']);
      _log('group/page(attr=owner) 返回 ${items.length} 个群');
      for (final item in items) {
        if ((item['title'] ?? item['name'])?.toString() == expectedTitle) {
          final raw = item['group_id'] ?? item['gid'] ?? item['id'];
          if (raw != null) {
            gid = raw.toString();
            break;
          }
        }
      }
    }
    if (gid.isEmpty) {
      final created = await client.post(
        '/api/v1/group/add',
        data: {'member_uids': <String>[]},
      );
      ApiAssert.success(created, context: '创建测试群');
      final group = created['payload'] is Map
          ? (created['payload'] as Map<dynamic, dynamic>)['group']
          : null;
      final raw = group is Map
          ? (group['group_id'] ?? group['gid'] ?? group['id'])
          : null;
      expect(raw, isNotNull, reason: '建群响应缺少 group.id');
      gid = raw.toString();
      final edit = await client.post(
        '/api/v1/group/edit',
        data: {'gid': gid, 'title': expectedTitle},
      );
      ApiAssert.success(edit, context: '命名测试群');
    }
    _log('测试群 gid=$gid title=$expectedTitle');
  });

  tearDownAll(() => client.close());

  test('前置：登录并定位 DEMO-FLOW 测试群', () {
    expect(loggedIn, isTrue);
    expect(gid, isNotEmpty);
  });

  test('群分类闭环：创建 → 列表回读', () async {
    final name = '$_prefix-CAT-$_runTs';
    final created = await client.post(
      '/api/v1/group/category/create',
      data: {'category_name': name},
    );
    _log('创建分类 code=${created['code']} msg=${created['msg']}');
    ApiAssert.success(created, context: '创建群分类');
    final payload = created['payload'];
    final id = payload is Map
        ? (payload['id'] ?? payload['category_id'])
        : null;
    expect(id, isNotNull, reason: '创建分类响应缺少 id: $payload');
    _log('创建分类成功 id=$id');

    final listResp = await client.get('/api/v1/group/category/list');
    ApiAssert.success(listResp, context: '群分组列表');
    final categories = _asList(listResp['payload'], 'categories');
    final hit = categories.any(
      (c) => (c['name'] ?? c['category_name'])?.toString() == name,
    );
    expect(hit, isTrue, reason: '分类列表回读必须包含新分类，共 ${categories.length} 个');
    _log('分类列表回读命中（列表共 ${categories.length} 个分类）');
  });

  test('群二维码：URL 构造 + 服务端 tk 校验与入群分支（幂等）', () async {
    // 复刻 lib/page/qrcode/qrcode_url.dart 的 buildGroupQrcodeUrl。
    final key = Platform.environment['IMBOY_SOLIDIFIED_KEY']?.trim() ?? '';
    expect(key, isNotEmpty, reason: '缺少 IMBOY_SOLIDIFIED_KEY（二维码 tk 签名）');
    final expMs = DateTime.now().millisecondsSinceEpoch + 7 * 86400 * 1000;
    final tk = _md5('${expMs}_$key');
    final url = '/api/v1/group/qrcode?id=$gid&exp=$expMs&tk=$tk&s=app_qrcode';
    _log('二维码内容 URL 已构造 exp=${expMs ~/ 1000}s tk=${tk.substring(0, 6)}...');

    // 已登录（测试账号为群成员）访问读码 URL：tk 校验通过 → join_group 幂等。
    final resp = await client.get(url);
    _log(
      '读码端点响应 code=${resp['code']} msg=${resp['msg']} '
      'payload=${resp['payload']}',
    );
    expect(resp['code'], isA<int>(), reason: '读码端点应返回业务响应');
    // 已在群内的成员扫码：成功（code=0）或「已在群」类业务响应均证明
    // tk 校验与入群分支服务端可达；断言非 302 丢弃（client 已解析 JSON）。
    expect(
      resp['msg'],
      isNot(contains('non_json')),
      reason: '不应是 302 重定向页（tk 有效时）',
    );

    // 负向：无效 tk 不应入群（302 → 非 JSON 响应即重定向）。
    final bad = await client.get(
      '/api/v1/group/qrcode?id=$gid&exp=$expMs&tk=badtoken&s=app_qrcode',
    );
    _log('无效 tk 响应 code=${bad['code']} msg=${bad['msg']}');
    expect(
      bad['msg'],
      contains('non_json'),
      reason: '无效 tk 应被 302 重定向拒绝（响应体为空/HTML）',
    );
  });

  test('群标签闭环：添加并绑定测试群 → 列表回读', () async {
    final name = '$_prefix-TAG-$_runTs';
    final added = await client.post(
      '/api/v1/group/tag/add',
      data: {'gid': gid, 'tag_name': name},
    );
    _log('添加标签 code=${added['code']} msg=${added['msg']}');
    ApiAssert.success(added, context: '添加群标签');

    final listResp = await client.get(
      '/api/v1/group/tag/list',
      queryParameters: {'gid': gid},
    );
    ApiAssert.success(listResp, context: '群标签列表');
    final tags = _asList(listResp['payload'], 'list');
    final hit = tags.any(
      (t) => (t['tag_name'] ?? t['name'])?.toString() == name,
    );
    expect(hit, isTrue, reason: '标签列表回读必须包含新标签，共 ${tags.length} 个');
    _log('标签列表回读命中（群共 ${tags.length} 个标签）');
  });
}

List<Map<String, dynamic>> payloadList(dynamic payload) {
  final list = payload is Map
      ? (payload['list'] ?? payload['items'] ?? payload['data'])
      : payload;
  if (list is! List) return const [];
  return list
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
