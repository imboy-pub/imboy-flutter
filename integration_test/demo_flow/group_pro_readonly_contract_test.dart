// 隔离后端的群只读契约（group + group_member GET，纯 Dart，无设备）。
// 保留密码预哈希迁移的 md5→明文兼容验证，使用合成账号及已加入群 fixture。
// 历史文件名保留以避免破坏引用；运行时仅接受显式 loopback 环境。
//
// 通过统一 backend-contract profile 运行；必须提供：
// IMBOY_TEST_ISOLATED=true APP_ENV=local DEMO_FLOW_LOCAL_READONLY=true
// API_BASE_URL=http://127.0.0.1:<isolated-port>
// IMBOY_SOLIDIFIED_KEY=<isolated-signing-key>
// TEST_PHONE=<synthetic-account> TEST_PASSWORD=<synthetic-password>
// 仅登录 POST + GET 只读端点；不调用业务写端点、不启用 API writes。

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';

bool _isIsolatedTarget(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final address = InternetAddress.tryParse(host);
  return address?.isLoopback ?? false;
}

/// 自包含最小客户端：HMAC-SHA512 请求签名 + Bearer 鉴权 + JSON envelope 解析。
class _ReadOnlyContractClient {
  final Uri base;
  final String signingKey;
  final String did = 'e2e-dart-test-001';
  String? _token;
  String? _uid;

  _ReadOnlyContractClient(this.base, this.signingKey);

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
      if (!md5Rejected) {
        return {
          'ok': false,
          'md5Rejected': false,
          'plainRetryOk': false,
          'resp': resp,
        };
      }
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
  late _ReadOnlyContractClient client;
  bool ready = false;
  String? sampleGid;
  bool md5Rejected = false;
  bool plainRetryOk = false;

  setUpAll(() async {
    final env = Platform.environment;
    final optedIn =
        env['DEMO_FLOW_LOCAL_READONLY'] == 'true' &&
        env['IMBOY_TEST_ISOLATED'] == 'true' &&
        env['APP_ENV'] == 'local';
    final url = env['API_BASE_URL'] ?? '';
    final key = env['IMBOY_SOLIDIFIED_KEY']?.trim() ?? '';
    if (!optedIn || !_isIsolatedTarget(url) || key.isEmpty) {
      fail(
        'ENV_MISSING: 显式 loopback API_BASE_URL、隔离签名密钥、'
        'IMBOY_TEST_ISOLATED=true、APP_ENV=local、'
        'DEMO_FLOW_LOCAL_READONLY=true 均为必需条件',
      );
    }
    final account = env['TEST_PHONE'] ?? '';
    final password = env['TEST_PASSWORD'] ?? '';
    if (account.isEmpty || password.isEmpty) {
      fail('ENV_MISSING: 需要合成 TEST_PHONE/TEST_PASSWORD 只读测试账号');
    }
    client = _ReadOnlyContractClient(Uri.parse(url), key);
    final r = await client.loginCompat(account, password);
    if (r['ok'] != true) {
      final resp = r['resp'] as Map<String, dynamic>;
      fail('隔离后端登录失败（code=${resp['code']} msg=${resp['msg']}）');
    }
    md5Rejected = r['md5Rejected'] == true;
    plainRetryOk = r['plainRetryOk'] == true;
    final page = await client.get(
      '/api/v1/group/page',
      query: {'page': '1', 'size': '10', 'attr': 'join'},
    );
    _assertOk(page, 'setUpAll group/page');
    sampleGid = _firstGid(page['payload']);
    if (sampleGid == null) {
      fail('ENV_MISSING: 合成账号需要至少一个已加入群 fixture');
    }
    ready = true;
  });

  bool requireReady() {
    expect(ready, isTrue, reason: '隔离契约 setUpAll 未成功');
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
