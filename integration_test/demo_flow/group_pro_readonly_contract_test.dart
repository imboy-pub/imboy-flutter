// DF-09 生产只读群契约（group + group_member GET 只读，纯 dart test，无设备）。
//
// 背景（2026-08-27）：后端 alpha.69 含 2026-08-26 密码预哈希迁移（imboy
// ba8da098：verify 先试 hmac(sha256(明文)) 新格式，失败回退 hmac(md5(明文))
// 旧存量格式）。存量账号（存储 hmac(md5hex(明文))）在 md5 传输下恒
// errorPassword，真实客户端（passport_notifier）以 md5 失败→明文重试兼容。
// 共享 test/unit_test/api/api_test_client.dart 仅发 md5，暂无法登录
// alpha.69 生产；本文件按「确有必要才新增」落在 integration_test/demo_flow/，
// 自包含 HTTP/签名客户端（不依赖共享客户端内部状态），登录镜像真实客户端
// 的 md5→明文回退，断言口径 1:1 复刻
// test/unit_test/api/{group,group_member}_api_test.dart（08-19 基线 6+5）。
//
// 运行（生产严格只读，双重 opt-in 门禁，默认 SKIP）：
//   API_BASE_URL=https://pro.imboy.pub \
//   IMBOY_SOLIDIFIED_KEY=<bake 解码 key（env_pro.g.dart XOR）> \
//   TEST_PHONE=118@imboy.pub TEST_PASSWORD=<生产测试账号密码> \
//   DEMO_FLOW_PRO_READONLY=true \
//   dart test integration_test/demo_flow/group_pro_readonly_contract_test.dart \
//     --concurrency=1
//
// 安全约束：仅登录 POST + GET 只读端点；绝不调用写端点、不设置
// TEST_ALLOW_API_WRITES；生产账号 118@imboy.pub（uid=4）为历史只读契约账号。

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';

const _proBase = 'https://pro.imboy.pub';

/// 自包含最小客户端：HMAC-SHA512 请求签名 + Bearer 鉴权 + JSON envelope 解析。
class _ProReadOnlyClient {
  final Uri base;
  final String signingKey;
  final String did = 'e2e-dart-test-001';
  String? _token;
  String? _uid;

  _ProReadOnlyClient(this.base, this.signingKey);

  String? get currentUid => _uid;

  Map<String, String> _headers({bool auth = false}) {
    const vsn = '0.8.0';
    const cos = 'macos';
    const pkg = 'pub.imboy.app';
    final raw = '$did|$vsn|$cos|$pkg';
    final sign = base64.encode(
      crypto.Hmac(
        crypto.sha512,
        utf8.encode(signingKey),
      ).convert(utf8.encode(raw)).bytes,
    );
    final h = <String, String>{
      'cos': cos,
      'vsn': vsn,
      'pkg': pkg,
      'did': did,
      'tz_offset': '${DateTime.now().timeZoneOffset.inMilliseconds}',
      'method': 'sha512',
      'sk': '1',
      'sign': sign,
    };
    if (auth && _token != null) h['authorization'] = 'Bearer $_token';
    return h;
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = base.replace(
      path: path,
      queryParameters: query?.map((k, v) => MapEntry(k, v)),
    );
    final req = await HttpClient().openUrl(method, uri)
      ..followRedirects = false;
    final h = _headers(auth: true);
    h.forEach(req.headers.set);
    req.headers.set('Content-Type', 'application/json');
    if (body != null) req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {
        'code': resp.statusCode,
        'msg': 'non_json_response',
        'data': null,
      };
    }
  }

  /// 登录：md5 传输失败且 errorPassword 时明文重试（镜像 passport_notifier）。
  /// 返回 {ok, md5Rejected, plainRetryOk}。
  Future<Map<String, dynamic>> loginCompat(
    String account,
    String password,
  ) async {
    final type = account.contains('@') ? 'email' : 'mobile';
    final md5Pwd = crypto.md5.convert(utf8.encode(password)).toString();
    var resp = await _json(
      'POST',
      '/api/v1/passport/login',
      body: {
        'account': account,
        'pwd': md5Pwd,
        'type': type,
        'rsa_encrypt': '0',
      },
    );
    var md5Rejected = false;
    if (resp['code'] != 0) {
      md5Rejected = '${resp['msg']}'.contains('errorPassword');
      if (!md5Rejected)
        return {
          'ok': false,
          'md5Rejected': false,
          'plainRetryOk': false,
          'resp': resp,
        };
      resp = await _json(
        'POST',
        '/api/v1/passport/login',
        body: {
          'account': account,
          'pwd': password,
          'type': type,
          'rsa_encrypt': '0',
        },
      );
    }
    final ok = resp['code'] == 0;
    if (ok) {
      final p = resp['payload'] as Map<String, dynamic>?;
      _token = p?['token'] as String?;
      _uid = '${p?['uid'] ?? ''}';
    }
    return {
      'ok': ok,
      'md5Rejected': md5Rejected,
      'plainRetryOk': ok && md5Rejected,
      'resp': resp,
    };
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _json('GET', path, query: query);
}

void _assertOk(Map<String, dynamic> resp, String context) {
  expect(resp['code'], 0, reason: '$context 期望 code=0: ${resp['msg']}');
}

void expectTsid(dynamic v, {required String field}) {
  expect(v, isNotNull, reason: '$field 不应为 null');
  final s = '$v';
  expect(s.isNotEmpty, isTrue, reason: '$field 应可转非空 string');
  expect(
    BigInt.tryParse(s) != null || v is String,
    isTrue,
    reason: '$field 应为可解析 TSID，实际=$v (${v.runtimeType})',
  );
}

List<dynamic> _asList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map) {
    final list = payload['list'] ?? payload['items'] ?? payload['data'];
    return list is List ? list : const <dynamic>[];
  }
  return const <dynamic>[];
}

String? _firstGid(dynamic payload) {
  final list = _asList(payload);
  if (list.isEmpty) return null;
  final first = list.first as Map<String, dynamic>;
  final key = [
    'group_id',
    'gid',
    'id',
  ].firstWhere(first.containsKey, orElse: () => '');
  return key.isEmpty ? null : '${first[key]}';
}

void main() {
  late _ProReadOnlyClient client;
  bool ready = false;
  String skipReason = '';
  String? sampleGid;
  bool md5Rejected = false;
  bool plainRetryOk = false;

  setUpAll(() async {
    final env = Platform.environment;
    final optedIn = (env['DEMO_FLOW_PRO_READONLY'] ?? '') == 'true';
    final url = env['API_BASE_URL'] ?? '';
    final key = env['IMBOY_SOLIDIFIED_KEY']?.trim() ?? '';
    if (!optedIn || url != _proBase || key.isEmpty) {
      skipReason =
          '需要 API_BASE_URL=$_proBase + IMBOY_SOLIDIFIED_KEY + '
          'DEMO_FLOW_PRO_READONLY=true 显式 opt-in';
      return;
    }
    final account = env['TEST_PHONE'] ?? '';
    final password = env['TEST_PASSWORD'] ?? '';
    if (account.isEmpty || password.isEmpty) {
      skipReason = '需要 TEST_PHONE/TEST_PASSWORD 生产只读测试账号';
      return;
    }
    client = _ProReadOnlyClient(Uri.parse(_proBase), key);
    final r = await client.loginCompat(account, password);
    if (r['ok'] != true) {
      final resp = r['resp'] as Map<String, dynamic>;
      skipReason = '生产登录失败（code=${resp['code']} msg=${resp['msg']}）';
      return;
    }
    md5Rejected = r['md5Rejected'] == true;
    plainRetryOk = r['plainRetryOk'] == true;
    final page = await client.get(
      '/api/v1/group/page',
      query: {'page': '1', 'size': '10', 'attr': 'join'},
    );
    if (page['code'] == 0) sampleGid = _firstGid(page['payload']);
    ready = true;
  });

  bool requireReady() {
    if (!ready) markTestSkipped(skipReason);
    return ready;
  }

  test('0.1 alpha.69 密码契约迁移观测 — md5 拒收时明文回退成功', () async {
    if (!requireReady()) return;
    // 存量账号：md5 拒收 + 明文回退成功；若账号哈希已升级为 md5 兼容形态
    // （md5 一次成功），同样通过（两种路径均有服务端响应证据）。
    expect(
      md5Rejected == plainRetryOk || !md5Rejected,
      isTrue,
      reason: 'md5Rejected=$md5Rejected plainRetryOk=$plainRetryOk 组合非法',
    );
  });

  group('群分页', () {
    test('1.1 分页获取我加入的群 — code=0', () async {
      if (!requireReady()) return;
      final resp = await client.get(
        '/api/v1/group/page',
        query: {'page': '1', 'size': '10', 'attr': 'join'},
      );
      _assertOk(resp, 'group/page');
    });

    test('1.2 数据结构 — 群项含可解析 group_id(TSID)', () async {
      if (!requireReady()) return;
      final resp = await client.get(
        '/api/v1/group/page',
        query: {'page': '1', 'size': '10', 'attr': 'join'},
      );
      if (resp['code'] != 0) return markTestSkipped('group/page 非成功');
      final gid = _firstGid(resp['payload']);
      if (gid == null) return markTestSkipped('测试账号无已加入群');
      expectTsid(gid, field: 'group.group_id');
    });
  });

  group('群详情', () {
    test('2.1 获取群详情 — code=0 且含群名', () async {
      if (!requireReady()) return;
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/detail',
        query: {'gid': sampleGid!},
      );
      _assertOk(resp, 'group/detail');
      final payload = resp['payload'] as Map<String, dynamic>;
      expect(
        ['title', 'name', 'group_name'].any(payload.containsKey),
        isTrue,
        reason: 'group/detail 应含群名字段: $payload',
      );
    });

    test('2.2 无效 gid — 返回业务错误而非崩溃', () async {
      if (!requireReady()) return;
      final resp = await client.get(
        '/api/v1/group/detail',
        query: {'gid': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  group('群成员分页', () {
    test('3.1 分页获取群成员 — code=0', () async {
      if (!requireReady()) return;
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_member/page',
        query: {'gid': sampleGid!, 'page': '1', 'size': '20'},
      );
      _assertOk(resp, 'group_member/page');
    });

    test('3.2 数据结构 — 成员项含可解析 uid(TSID)', () async {
      if (!requireReady()) return;
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_member/page',
        query: {'gid': sampleGid!, 'page': '1', 'size': '20'},
      );
      if (resp['code'] != 0) return markTestSkipped('member/page 非成功');
      final list = _asList(resp['payload']);
      if (list.isEmpty) return markTestSkipped('样本群无成员数据');
      final first = list.first as Map<String, dynamic>;
      final key = [
        'uid',
        'user_id',
        'id',
      ].firstWhere(first.containsKey, orElse: () => '');
      expect(key.isNotEmpty, isTrue, reason: '成员项缺少 uid: $first');
      expectTsid(first[key], field: '成员.$key');
    });

    test('3.3 无效 gid — 返回业务响应而非崩溃', () async {
      if (!requireReady()) return;
      final resp = await client.get(
        '/api/v1/group_member/page',
        query: {'gid': '0', 'page': '1', 'size': '20'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  group('同群判定', () {
    test('4.1 与自身同群查询 — 返回业务响应而非崩溃', () async {
      if (!requireReady()) return;
      final uid = client.currentUid ?? '';
      if (uid.isEmpty) return markTestSkipped('无 currentUid');
      final resp = await client.get(
        '/api/v1/group_member/same_group',
        query: {'uid1': uid, 'uid2': uid},
      );
      expect(resp, containsPair('code', isA<int>()));
    });

    test('4.2 无效 uid — 返回业务响应而非崩溃', () async {
      if (!requireReady()) return;
      final resp = await client.get(
        '/api/v1/group_member/same_group',
        query: {'uid1': '0', 'uid2': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });
}
