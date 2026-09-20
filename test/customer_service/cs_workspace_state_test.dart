/// CSM-01（§12.5.1）— 待接队列分页解析与 CAS 接单分支单测
///
/// 覆盖：
/// - CsQueuePage 解析：多页键集拼接无重复/无遗漏；游标 `next_after_id`
///   为 null → 无更多页；计数**只来自服务端键**（total / total_by_status），
///   服务端未提供时为 null（禁止本地行数推断）；
/// - 列表 payload 双键兼容：A0 真源 `sessions` 优先、W2 冻结 `list` 兜底；
/// - DTO 字段：TSID 一律 String；contact / queued_at / last_message 按后端真实
///   嵌套投影解析；
/// - claim CAS：成功（回显投影解析）与 409 冲突分支（CsApiException 判定）；
/// - 等待时长格式化纯函数（csWaitingSince）。
///
/// 网络出口用「记录请求 + 恒返指定响应」的 HttpClientAdapter（与
/// cs_api_contract_test 同款机制）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/public.dart';
import 'package:imboy/service/storage.dart';

/// 记录请求并按脚本顺序返回响应的出口。
class _ScriptedAdapter implements HttpClientAdapter {
  final List<(int, Map<String, dynamic>)> responses;
  int _cursor = 0;

  final List<(String, String, Object?, Map<String, dynamic>)> requests = [];

  _ScriptedAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      options.method,
      options.uri.path,
      options.data,
      Map<String, dynamic>.from(options.queryParameters),
    ));
    final (status, body) = _cursor < responses.length
        ? responses[_cursor++]
        : responses.last;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

Map<String, dynamic> itemJson(String id, {int version = 1}) => {
  // 后端 seat 队列投影主键为 `id`（对齐 seat_session_view 白名单）。
  'id': id,
  'contact_id': '8266418340025468999',
  'contact': {'masked_name': '访客$id'},
  'queued_at': 1789000000,
  'version': version,
  'status': 'queued',
  'source': 'widget',
  'last_message': {
    'id': '7266418340025468800',
    'sender_type': 'contact',
    'created_at': 1789000001,
  },
};

const String kOrgId = '7266418340025468901';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('CSM-01 queue 键集分页解析', () {
    test('两页拼接：无重复、无遗漏，游标推进正确', () async {
      final page1 = [
        for (var i = 1; i <= 3; i++) itemJson('72664183400254689$i'),
      ];
      final page2 = [
        for (var i = 4; i <= 5; i++) itemJson('72664183400254689$i'),
      ];
      final adapter = _ScriptedAdapter([
        (
          200,
          okEnvelope(
            payload: {'sessions': page1, 'next_after_id': '726641834002546893'},
          ),
        ),
        (
          200,
          okEnvelope(
            payload: {
              'sessions': page2,
              'next_after_id': null, // 末页：null → 无更多
            },
          ),
        ),
      ]);
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = CsApi();

      final first = await api.queuePage(kOrgId, limit: 3);
      expect(first.items.map((e) => e.sessionId).toList(), [
        '726641834002546891',
        '726641834002546892',
        '726641834002546893',
      ]);
      expect(first.nextAfterId, '726641834002546893');
      expect(first.hasMore, isTrue);

      final second = await api.queuePage(
        kOrgId,
        afterId: first.nextAfterId,
        limit: 3,
      );
      expect(second.nextAfterId, '');
      expect(second.hasMore, isFalse);

      // 拼接全集：5 条不重不漏（页1+页2 按游标衔接）
      final merged = [...first.items, ...second.items];
      final ids = merged.map((e) => e.sessionId).toSet();
      expect(ids.length, 5, reason: '不得有重复');
      expect(merged.length, 5, reason: '不得有遗漏');
      // 分页请求形状：第二页必须携带 after_id 游标
      expect(adapter.requests[1].$4['after_id'], '726641834002546893');
    });

    test('计数只来自服务端键：total_by_status 命中；缺失时为 null（不推断）', () async {
      final adapter = _ScriptedAdapter([
        (
          200,
          okEnvelope(
            payload: {
              'sessions': [itemJson('726641834002546891')],
              'next_after_id': null,
              'total': 42,
              'total_by_status': {'queued': 42, 'active': 7},
            },
          ),
        ),
        (
          200,
          okEnvelope(
            payload: {
              'sessions': [itemJson('726641834002546891')],
              'next_after_id': null,
              // 服务端未提供任何计数键
            },
          ),
        ),
      ]);
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = CsApi();

      final withCounts = await api.queuePage(kOrgId);
      expect(withCounts.total, 42);
      expect(withCounts.countOf('queued'), 42);
      expect(withCounts.countOf('active'), 7);
      expect(withCounts.countOf('closed'), isNull);

      // 服务端未提供计数 → null（禁止用 items.length=1 推断）
      final noCounts = await api.queuePage(kOrgId);
      expect(noCounts.total, isNull);
      expect(noCounts.totalByStatus, isNull);
      expect(noCounts.countOf('queued'), isNull);
      expect(noCounts.items, hasLength(1));
    });

    test('payload 列表键：sessions 优先，list 兜底（W2 冻结形状）', () async {
      final adapter = _ScriptedAdapter([
        (
          200,
          okEnvelope(
            payload: {
              'list': [itemJson('726641834002546891')],
            },
          ),
        ),
      ]);
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = CsApi();

      final page = await api.queuePage(kOrgId);
      expect(page.items.single.sessionId, '726641834002546891');
    });

    test('DTO：TSID 一律 String；可选字段宽容解析（缺失为空）', () async {
      final adapter = _ScriptedAdapter([
        (
          200,
          okEnvelope(
            payload: {
              // TSID 以 JSON integer 传输（64-bit 越界 int 值在 JS 外安全，
              // 客户端 entityIdOf 语义转 String）
              'sessions': [
                {
                  'session_id': 7266418340025468940,
                  'contact_id': 7266418340025468941,
                },
                itemJson('7266418340025468950', version: 4),
              ],
            },
          ),
        ),
      ]);
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = CsApi();

      final page = await api.queuePage(kOrgId);
      final bare = page.items[0];
      expect(bare.sessionId, '7266418340025468940');
      expect(bare.contactId, '7266418340025468941');
      expect(bare.version, 0, reason: '服务端未给 version → 0（不得发起 CAS）');
      expect(bare.source, '');
      expect(bare.contactName, '');
      expect(bare.waitingSince, '');
      expect(bare.hasLastMessage, isFalse);

      final full = page.items[1];
      expect(full.version, 4);
      expect(full.status, 'queued');
      expect(full.source, 'widget');
      expect(full.contactName, '访客7266418340025468950');
      expect(full.waitingSince, '1789000000000');
      expect(full.hasLastMessage, isTrue);
    });
  });

  group('CSM-01 claim CAS 分支', () {
    test('成功：POST body {expected_version}，解析回显投影（version/status）', () async {
      final adapter = _ScriptedAdapter([
        (
          200,
          okEnvelope(
            payload: {
              'session_id': 7266418340025468940,
              'status': 'active',
              'version': 8,
              'business_identity_id': 7266418340025468902,
            },
          ),
        ),
      ]);
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = CsApi();

      final result = await api.claim(
        kOrgId,
        '7266418340025468940',
        expectedVersion: 7,
      );

      final req = adapter.requests.single;
      expect(req.$1, 'POST');
      expect(
        req.$2,
        '/api/v1/cs/organizations/$kOrgId/sessions/7266418340025468940/claim',
      );
      final body = Map<String, dynamic>.from(req.$3 as Map);
      expect(body, {'expected_version': 7});

      expect(result.sessionId, '7266418340025468940');
      expect(result.status, 'active');
      expect(result.version, 8);
      expect(result.assigneeIdentityId, '7266418340025468902');
    });

    test('409 冲突：isConflict 判定为真，异常带服务端 msg（刷新语义由 UI 层执行）', () async {
      final adapter = _ScriptedAdapter([
        (409, {'code': 409, 'msg': '{cas_mismatch, ...}'}),
      ]);
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final api = CsApi();

      Object? caught;
      try {
        await api.claim(kOrgId, '7266418340025468940', expectedVersion: 7);
        fail('claim 409 必须 throw（fail-closed，不做伪成功）');
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isA<CsApiException>());
      final e = caught as CsApiException;
      expect(e.isConflict, isTrue);
      // APP-M02-A05：普通 409（CAS 竞争）与 offboarding 409 分类分离——
      // 前者可刷新重试，后者是终态降级；cas_mismatch 不带 offboarding 语义。
      expect(e.isOffboardingRequired, isFalse, reason: '普通 409 ≠ offboarding');
      expect(e.isForbidden, isFalse);
    });

    test(
      '409 offboarding_required：isConflict 与 isOffboardingRequired 同时为真',
      () {
        final e = CsApiException(409, 'offboarding_required');
        expect(e.isConflict, isTrue, reason: '同为 409 族');
        expect(
          e.isOffboardingRequired,
          isTrue,
          reason: 'envelope offboarding 语义',
        );
        // 分类函数：offboarding 优先于普通 conflict（A05 终态不可重试）。
        expect(csClassifySeatFailure(e), CsSeatFailureKind.offboarding);
        expect(
          csClassifySeatFailure(CsApiException(409, '{cas_mismatch, ...}')),
          CsSeatFailureKind.conflict,
        );
        expect(
          csClassifySeatFailure(CsApiException(403, 'forbidden')),
          CsSeatFailureKind.suspended,
        );
      },
    );

    test('version<=0（服务端未回显）时调用方不得发起 CAS claim', () {
      // 契约钉：DTO 无 version → 0；UI 层以 version>0 作为 claim 前置条件。
      final bare = CsQueueItem(
        sessionId: '7266418340025468940',
        contactId: '7266418340025468941',
      );
      expect(bare.version, 0);
      expect(bare.version > 0, isFalse);
    });
  });

  group('CSM-01 等待时长格式化（csWaitingSince）', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1789000000000);

    test('档位：刚刚 / 分钟 / 小时+分 / 天+小时', () {
      String at(int offsetMs) => '$offsetMs';

      expect(
        csWaitingSince(at(now.millisecondsSinceEpoch - 30 * 1000), now).unit,
        'justNow',
      );
      final m5 = csWaitingSince(
        at(now.millisecondsSinceEpoch - 5 * 60 * 1000),
        now,
      );
      expect(m5.unit, 'minutes');
      expect(m5.n, 5);

      final h2m30 = csWaitingSince(
        at(now.millisecondsSinceEpoch - ((2 * 60 + 30) * 60 * 1000)),
        now,
      );
      expect(h2m30.unit, 'hoursMinutes');
      expect(h2m30.n, 2);
      expect(h2m30.m, 30);

      final d2h3 = csWaitingSince(
        at(now.millisecondsSinceEpoch - ((2 * 24 + 3) * 60 * 60 * 1000)),
        now,
      );
      expect(d2h3.unit, 'daysHours');
      expect(d2h3.n, 2);
      expect(d2h3.m, 3);
    });

    test('非法 / 未来时间戳回落 justNow（不抛错、不推断）', () {
      expect(csWaitingSince('', now).unit, 'justNow');
      expect(csWaitingSince('not-a-number', now).unit, 'justNow');
      expect(
        csWaitingSince('${now.millisecondsSinceEpoch + 60000}', now).unit,
        'justNow',
      );
    });
  });
}
